extends Node2D
class_name TargetReticle

## Circular aiming reticle with a white progress ring that completes in one second.

@export var target_radius: float = 22.0
@export var ring_radius: float = 18.0
@export var line_width: float = 2.0
@export var progress_cycle_seconds: float = 1.0

var target: Ship
var follow_mouse: bool = false
var player_ship: Ship
var _progress: float = 0.0


func _process(delta: float) -> void:
	var has_target: bool = false
	if follow_mouse and is_instance_valid(player_ship):
		global_position = player_ship.get_global_mouse_position()
		has_target = _is_enemy_under_mouse()
	elif is_instance_valid(target) and not target.is_destroyed and target.is_inside_tree():
		global_position = target.global_position
		has_target = true

	visible = has_target
	if follow_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if has_target else Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if has_target:
		_progress = fposmod(_progress + delta / maxf(progress_cycle_seconds, 0.01), 1.0)
	else:
		_progress = 0.0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var white: Color = Color(1.0, 1.0, 1.0, 0.95)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, white, line_width, true)
	if _progress > 0.0:
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			-PI / 2.0,
			-PI / 2.0 + TAU * _progress,
			64,
			white,
			line_width + 1.0,
			true
		)


func _is_enemy_under_mouse() -> bool:
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Ship = node as Ship
		if enemy == null or enemy.is_destroyed or not enemy.is_inside_tree():
			continue
		if global_position.distance_to(enemy.global_position) <= target_radius:
			return true
	return false


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
