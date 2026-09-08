use super::*;
use serde_json::{Value, json};
use std::io::Read;
use std::os::unix::net::UnixStream;

fn socket_pair() -> (swayipc::Connection, UnixStream) {
    let (client, server) = UnixStream::pair().unwrap();
    for socket in [&client, &server] {
        socket
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        socket
            .set_write_timeout(Some(Duration::from_secs(5)))
            .unwrap();
    }
    (client.into(), server)
}

fn receive(socket: &mut UnixStream, expected_type: u32) -> Vec<u8> {
    let mut header = [0; 14];
    socket.read_exact(&mut header).unwrap();
    assert_eq!(&header[..6], b"i3-ipc");
    assert_eq!(
        u32::from_ne_bytes(header[10..14].try_into().unwrap()),
        expected_type
    );
    let mut payload = vec![0; u32::from_ne_bytes(header[6..10].try_into().unwrap()) as usize];
    socket.read_exact(&mut payload).unwrap();
    payload
}

fn send(socket: &mut UnixStream, message_type: u32, payload: &Value) {
    let payload = serde_json::to_vec(payload).unwrap();
    socket.write_all(b"i3-ipc").unwrap();
    socket
        .write_all(&(payload.len() as u32).to_ne_bytes())
        .unwrap();
    socket.write_all(&message_type.to_ne_bytes()).unwrap();
    socket.write_all(&payload).unwrap();
}

fn node(kind: &str, name: &str, focused: bool, children: Vec<Value>) -> Value {
    let rect = json!({"x": 0, "y": 0, "width": 100, "height": 100});
    json!({
        "id": 1, "name": name, "type": kind, "border": "none",
        "current_border_width": 0, "layout": "splith", "orientation": "none",
        "rect": rect, "window_rect": rect, "deco_rect": rect, "geometry": rect,
        "urgent": false, "focused": focused, "focus": [], "nodes": children,
        "floating_nodes": [], "sticky": false
    })
}

#[test]
fn refreshes_empty_startup_tree_on_window_and_workspace_events() {
    let state = WrState(Arc::new(Mutex::new(State {
        idle_since: None,
        windows: vec![],
        focused_desktop: SmolStr::new(""),
    })));
    let (queries, mut query_server) = socket_pair();
    let (events, mut event_server) = socket_pair();
    let worker_state = state.clone();
    let worker = thread::spawn(move || watch_sway(worker_state, queries, events));

    let subscriptions: Value = serde_json::from_slice(&receive(&mut event_server, 2)).unwrap();
    assert_eq!(subscriptions, json!(["window", "workspace"]));
    // The subscription must complete before the first tree query.
    query_server.set_nonblocking(true).unwrap();
    assert_eq!(
        query_server.read(&mut [0]).unwrap_err().kind(),
        std::io::ErrorKind::WouldBlock
    );
    query_server.set_nonblocking(false).unwrap();
    send(&mut event_server, 2, &json!({"success": true}));

    receive(&mut query_server, 4);
    send(&mut query_server, 4, &node("workspace", "1", true, vec![]));

    let opened = node("con", "First title", true, vec![]);
    send(
        &mut event_server,
        0x80000003,
        &json!({"change": "new", "container": opened}),
    );
    receive(&mut query_server, 4);
    assert!(state.0.lock().unwrap().windows.is_empty());
    send(
        &mut query_server,
        4,
        &node("workspace", "1", false, vec![opened]),
    );

    let renamed = node("con", "Updated title", true, vec![]);
    send(
        &mut event_server,
        0x80000003,
        &json!({"change": "title", "container": renamed}),
    );
    receive(&mut query_server, 4);
    // Receiving the next query proves the previous snapshot has been published.
    assert_eq!(state.0.lock().unwrap().windows[0].title, "First title");
    send(
        &mut query_server,
        4,
        &node("workspace", "1", false, vec![renamed]),
    );

    let empty_workspace = node("workspace", "2", true, vec![]);
    send(
        &mut event_server,
        0x80000000,
        &json!({"change": "focus", "current": empty_workspace}),
    );
    receive(&mut query_server, 4);
    {
        let state = state.0.lock().unwrap();
        assert_eq!(state.windows[0].title, "Updated title");
        assert!(state.windows[0].active);
        assert_eq!(state.focused_desktop, "1");
    }
    send(&mut query_server, 4, &empty_workspace);

    // A disconnected event socket must return an error, not keep logging stale data.
    drop(event_server);
    assert!(worker.join().unwrap().is_err());
    let state = state.0.lock().unwrap();
    assert!(state.windows.is_empty());
    assert_eq!(state.focused_desktop, "2");
}
