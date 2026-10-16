extends Control
class_name MissionMinimap

var player_ship: Node2D
var destination_position: Vector2 = Vector2(2200.0, 0.0)
var world_min: Vector2 = Vector2(0.0, -520.0)
var world_size: Vector2 = Vector2(2400.0, 1040.0)
var asteroid_belt_x: float = 660.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(250.0, 178.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.015, 0.035, 0.065, 0.88), true)
	draw_rect(bounds, Color(0.28, 0.72, 0.92, 0.9), false, 2.0)
	var inner := Rect2(Vector2(12.0, 22.0), size - Vector2(24.0, 34.0))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 16.0), "NAVIGATION", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.65, 0.88, 1.0))
	var planet := _map_position(Vector2(190.0, 0.0), inner)
	var belt := _map_position(Vector2(asteroid_belt_x, 0.0), inner)
	var destination := _map_position(destination_position, inner)
	draw_line(Vector2(inner.position.x, belt.y), Vector2(inner.end.x, belt.y), Color(0.16, 0.26, 0.36, 0.3), 1.0)
	draw_line(Vector2(belt.x, inner.position.y), Vector2(belt.x, inner.end.y), Color(1.0, 0.56, 0.23, 0.7), 2.0)
	draw_circle(planet, 5.0, Color(0.23, 0.63, 0.98))
	draw_circle(planet + Vector2(5.0, -5.0), 2.0, Color(0.74, 0.88, 1.0))
	draw_circle(destination, 4.0, Color(0.35, 1.0, 0.65))
	draw_arc(destination, 8.0, 0.0, TAU, 24, Color(0.35, 1.0, 0.65, 0.75), 1.2)
	if is_instance_valid(player_ship):
		var player_point := _map_position(player_ship.global_position, inner)
		draw_line(player_point, destination, Color(0.35, 1.0, 0.65, 0.3), 1.0)
		draw_circle(player_point, 4.0, Color(1.0, 0.95, 0.45))
		var direction: Vector2 = (destination - player_point).normalized()
		var tip := player_point + direction * 12.0
		draw_line(player_point, tip, Color(1.0, 0.95, 0.45), 2.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - direction.rotated(0.55) * 6.0, tip - direction.rotated(-0.55) * 6.0]), Color(1.0, 0.95, 0.45))


func _map_position(world_position: Vector2, rect: Rect2) -> Vector2:
	var normalized := Vector2(
		clampf((world_position.x - world_min.x) / world_size.x, 0.0, 1.0),
		clampf((world_position.y - world_min.y) / world_size.y, 0.0, 1.0)
	)
	return rect.position + normalized * rect.size
