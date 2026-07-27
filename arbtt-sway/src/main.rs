// based on https://github.com/josephdunn/idlers/blob/main/src/main.rs

use std::process::{Command, Stdio};
use std::time::{Instant, Duration};
use std::sync::{Mutex, Arc};
use std::io::Write;
use std::thread;
use anyhow::Result;
use chrono::{DateTime, Utc};
use swayipc::{EventType, Node, NodeType, Workspace};
use wayland_client::{Connection, Dispatch, QueueHandle, delegate_noop, event_created_child, globals::{GlobalListContents, registry_queue_init}, protocol::{wl_registry, wl_seat}};
use wayland_protocols::ext::idle_notify::v1::client::{ext_idle_notification_v1::{self, ExtIdleNotificationV1}, ext_idle_notifier_v1::ExtIdleNotifierV1};
use smol_str::SmolStr;

struct State {
    idle_since: Option<Instant>,
    windows: Vec<ArbttWindow>,
    focused_desktop: SmolStr
}

#[derive(Clone)]
struct WrState(Arc<Mutex<State>>);

impl Dispatch<ExtIdleNotificationV1, ()> for WrState {
    fn event(
        state: &mut Self,
        _proxy: &ExtIdleNotificationV1,
        event: ext_idle_notification_v1::Event,
        data: &(),
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        match event {
            ext_idle_notification_v1::Event::Idled => {
                state.0.lock().unwrap().idle_since = Some(Instant::now());
            }
            ext_idle_notification_v1::Event::Resumed => {
                state.0.lock().unwrap().idle_since = None;
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for WrState {
    fn event(
        _state: &mut Self,
        _registry: &wl_registry::WlRegistry,
        _event: wl_registry::Event,
        _data: &GlobalListContents,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
    }
}

#[derive(serde::Serialize, Debug)]
struct ArbttWindow {
    active: bool,
    hidden: bool,
    title: SmolStr,
    program: SmolStr,
    desktop: SmolStr
}

#[derive(serde::Serialize, Debug)]
struct ArbttEntry<'a> {
    date: DateTime<Utc>,
    rate: u64,
    inactive: u64,
    windows: &'a [ArbttWindow],
    desktop: SmolStr
}

delegate_noop!(WrState: ignore wl_seat::WlSeat);
delegate_noop!(WrState: ignore ExtIdleNotifierV1);

fn process_tree<'a>(node: &'a Node, windows: &mut Vec<ArbttWindow>, focused: &mut SmolStr, mut workspace: Option<SmolStr>) {
    if node.node_type == NodeType::Workspace {
        workspace = workspace.or(node.name.as_ref().map(SmolStr::from));
    }
    if node.node_type == NodeType::Con || node.node_type == NodeType::FloatingCon {
        if node.name.is_some() || node.app_id.is_some() {
            //println!("{:?}", node);
            windows.push(ArbttWindow { active: node.focused, hidden: false, title: node.name.as_ref().map(SmolStr::from).unwrap_or_default(), program: node.app_id.as_ref().map(SmolStr::from).unwrap_or_default(), desktop: workspace.clone().unwrap_or_default() })
        }
    }
    if node.focused {
        if let Some(ws) = workspace.as_ref() {
            *focused = ws.clone();
        }
    }

    for child in &node.nodes {
        process_tree(child, windows, focused, workspace.clone());
    }
    for child in &node.floating_nodes {
        process_tree(child, windows, focused, workspace.clone());
    }
}

fn sway_thread(wr_state: WrState) -> Result<()> {
    let mut connection = swayipc::Connection::new()?;

    let tree = connection.get_tree()?;
    let mut windows = vec![];

    let mut read_windows = || {
        windows.clear();
        let mut focused = SmolStr::new("");
        process_tree(&tree, &mut windows, &mut focused, None);
        let mut state = wr_state.0.lock().unwrap();
        std::mem::swap(&mut state.windows, &mut windows);
        state.focused_desktop = focused;
    };

    read_windows();

    let st = connection.subscribe([EventType::Window])?;
    for _s in st {
        read_windows();
    }
    Ok(())
}

const INTERVAL: Duration = Duration::from_secs(60);

fn arbtt_thread(wr_state: WrState) -> Result<()> {
    let mut cmd = Command::new("arbtt-import");
    cmd.arg("-a").arg("-t").arg("JSON");
    //let mut cmd = Command::new("tee");
    let cmd = cmd.stdin(Stdio::piped()).spawn()?;
    let mut stdin = &cmd.stdin.unwrap();
    loop {
        std::thread::sleep(INTERVAL); // this will drift but close enough
        let state = wr_state.0.lock().unwrap();
        serde_json::to_writer(stdin, &ArbttEntry {
            date: Utc::now(),
            rate: INTERVAL.as_millis() as u64,
            inactive: state.idle_since.map(|s| Instant::now().duration_since(s).as_millis() as u64).unwrap_or(0),
            windows: state.windows.as_slice(),
            desktop: state.focused_desktop.clone()
        })?;
        std::mem::drop(state);
        write!(stdin, "\n")?;
    }
}

fn main() -> Result<()> {
    let idle_timeout_ms: u32 = 0;

    let conn = Connection::connect_to_env()?;
    let (globals, mut event_queue) = registry_queue_init::<WrState>(&conn)?;
    let qh = event_queue.handle();
    let seat: wl_seat::WlSeat = globals.bind::<wl_seat::WlSeat, _, _>(&qh, 1..=9, ())?;
    let idle_notifier: ExtIdleNotifierV1 = globals.bind::<ExtIdleNotifierV1, _, _>(&qh, 1..=2, ())?;
    let _notifier = idle_notifier.get_input_idle_notification(idle_timeout_ms, &seat, &qh, ());

    let state = State {
        idle_since: None,
        windows: vec![],
        focused_desktop: SmolStr::new("")
    };
    let mut wr_state = WrState(Arc::new(Mutex::new(state)));

    let wr_state_ = wr_state.clone();
    let wr_state__ = wr_state.clone();
    thread::spawn(|| {
        sway_thread(wr_state_).unwrap()
    });
    thread::spawn(|| {
       arbtt_thread(wr_state__).unwrap()
    });

    loop {
        conn.flush()?;
        event_queue.blocking_dispatch(&mut wr_state)?;
    }

    Ok(())
}
