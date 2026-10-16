extends Control
class_name MissionMinimap

## Top: whole-route strip (zones, gates, checkpoints, progress).
## Bottom: local radar showing enemies and gates around the ship.

const RADAR_RANGE: float = 1800.0
const RADAR_RADIUS: float = 78.0
const ZONE_COLORS: Dictionary = {
	RunProfile.ZoneKind.RING: Color(1.0, 0.56, 0.23, 0.55),
	RunProfile.ZoneKind.DRIFT: Color(0.45, 0.6, 0.7, 0.55),
	RunProfile.ZoneKind.CUSTOMS: Color(0.3, 0.5, 1.0, 0.55),
	RunProfile.ZoneKind.WRECKS: Color(0.65, 0.4, 0.85, 0.55),
	RunProfile.ZoneKind.BLOCKADE: Color(1.0, 0.3, 0.3, 0.55),
}

var player_ship: Node2D
var director: RunDirector


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(254.0, 236.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.015, 0.035, 0.065, 0.88), true)
	draw_rect(bounds, Color(0.28, 0.72, 0.92, 0.9), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 16.0), "NAVIGATION", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.65, 0.88, 1.0))
	if director == null or not is_instance_valid(player_ship) or director.layout.is_empty():
		return
	_draw_route_strip(Rect2(Vector2(12.0, 26.0), Vector2(size.x - 24.0, 22.0)))
	_draw_radar(Vector2(size.x * 0.5, 148.0))


func _draw_route_strip(strip: Rect2) -> void:
	var length: float = float(director.layout["length"])
	var zones: Array = director.layout["zones"]
	for zone: Dictionary in zones:
		var from_x: float = _strip_x(maxf(0.0, float(zone["start_x"])), length, strip)
		var to_x: float = _strip_x(float(zone["end_x"]), length, strip)
		var color: Color = ZONE_COLORS.get(int(zone["kind"]), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(Vector2(from_x, strip.position.y), Vector2(maxf(to_x - from_x, 1.0), strip.size.y)), color, true)
		if float(zone["gate_x"]) > 0.0:
			var gate_index: int = int(zone["index"]) - 1
			var gate_color: Color = Color(0.4, 1.0, 0.6) if gate_index < director.gates_cleared else Color(1.0, 0.35, 0.3)
			var gx: float = _strip_x(float(zone["gate_x"]), length, strip)
			draw_line(Vector2(gx, strip.position.y - 3.0), Vector2(gx, strip.end.y + 3.0), gate_color, 3.0)
	var checkpoints: Array = director.layout["checkpoints"]
	for checkpoint: Dictionary in checkpoints:
		var cx: float = _strip_x(float(checkpoint["x"]), length, strip)
		draw_circle(Vector2(cx, strip.end.y + 6.0), 2.0, Color(0.5, 0.7, 1.0) if int(checkpoint["state"]) == 0 else Color(0.4, 0.45, 0.5))
	draw_rect(strip, Color(0.28, 0.72, 0.92, 0.6), false, 1.0)
	var player_x: float = _strip_x(player_ship.global_position.x, length, strip)
	draw_colored_polygon(PackedVector2Array([
		Vector2(player_x, strip.position.y - 2.0), Vector2(player_x - 4.0, strip.position.y - 9.0), Vector2(player_x + 4.0, strip.position.y - 9.0)
	]), Color(1.0, 0.95, 0.45))
	draw_circle(Vector2(strip.end.x, strip.get_center().y), 4.0, Color(0.35, 1.0, 0.65))


func _strip_x(world_x: float, length: float, strip: Rect2) -> float:
	return strip.position.x + strip.size.x * clampf(world_x / length, 0.0, 1.0)


func _draw_radar(center: Vector2) -> void:
	draw_circle(center, RADAR_RADIUS, Color(0.02, 0.07, 0.1, 0.9))
	draw_arc(center, RADAR_RADIUS, 0.0, TAU, 48, Color(0.28, 0.72, 0.92, 0.7), 1.5)
	draw_arc(center, RADAR_RADIUS * 0.5, 0.0, TAU, 32, Color(0.28, 0.72, 0.92, 0.25), 1.0)
	var origin: Vector2 = player_ship.global_position
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var hostile: Ship = node as Ship
		if hostile == null or hostile.is_destroyed:
			continue
		var offset: Vector2 = (hostile.global_position - origin) / RADAR_RANGE * RADAR_RADIUS
		var off_radar: bool = offset.length() > RADAR_RADIUS - 3.0
		if off_radar:
			offset = offset.normalized() * (RADAR_RADIUS - 3.0)
		var point: Vector2 = center + offset
		if hostile is RouteGate:
			draw_colored_polygon(PackedVector2Array([
				point + Vector2(0.0, -6.0), point + Vector2(6.0, 0.0), point + Vector2(0.0, 6.0), point + Vector2(-6.0, 0.0)
			]), Color(1.0, 0.4, 0.3))
			continue
		var dot_size: float = 3.2 if hostile.max_hull > 60.0 else 2.2
		draw_circle(point, dot_size, Color(1.0, 0.3, 0.25, 0.45 if off_radar else 1.0))
	var facing: Vector2 = Vector2.RIGHT.rotated(player_ship.global_rotation) * 9.0
	draw_circle(center, 3.5, Color(1.0, 0.95, 0.45))
	draw_line(center, center + facing, Color(1.0, 0.95, 0.45), 2.0)
