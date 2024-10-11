import cadquery as cq

LENGTH = 250
BEZEL_THICKNESS = 14
MONITOR_THICKNESS = 9
MOUNT_THICKNESS = 1.0

pts = [
    (-MOUNT_THICKNESS, -MOUNT_THICKNESS),
    (-MOUNT_THICKNESS, MONITOR_THICKNESS + MOUNT_THICKNESS),
    (BEZEL_THICKNESS, MONITOR_THICKNESS + MOUNT_THICKNESS),
    (BEZEL_THICKNESS, MONITOR_THICKNESS),
    (0, MONITOR_THICKNESS),
    (0, 0),
    (BEZEL_THICKNESS, 0),
    (BEZEL_THICKNESS, -MOUNT_THICKNESS),
]

result = cq.Workplane("XY").polyline(pts).close().extrude(LENGTH).edges("|Z").chamfer(0.3)

cq.exporters.export(result, "/tmp/result.stl")
