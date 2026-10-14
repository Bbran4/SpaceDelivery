extends Node
class_name PlayerController

## Reads movement and targeting input. Ship handles movement and durability.

signal movement_mode_changed(mode: MovementMode)
signal target_changed(target: Ship)

enum MovementMode {
	KEYBOARD,
	MOUSE
}

@export var ship: Ship
@export var target_reticle_scene: PackedScene
@export var target_hud_scene: PackedScene

@export_group("Input")
@export var turn_left_action: StringName = &"left"
@export var turn_right_action: StringName = &"right"
@export var thrust_forward_action: StringName = &"up"
@export var thrust_reverse_action: StringName = &"down"

@export_group("Mouse Movement")
@export_range(0.0, 800.0, 1.0) var mouse_stop_distance: float = 140.0
@export_range(1.0, 10.0, 0.1) var mouse_turn_rate_multiplier: float = 4.0
@export_range(0.1, 2.0, 0.05) var mouse_velocity_response_time: float = 0.4
@export_range(1.0, 100.0, 1.0) var mouse_target_radius: float = 22.0
@export_range(10.0, 100.0, 1.0) var keyboard_reticle_radius: float = 32.0

var movement_mode: MovementMode = MovementMode.KEYBOARD
## Active weapon target. In keyboard mode this is cleared when the cursor leaves an enemy.
var current_target: Ship
## HUD target persists until it is destroyed or another enemy is selected.
var hud_target: Ship
var _reticle: TargetReticle
var _cycled_target: Ship
var _tab_was_pressed: bool = false


func _ready() -> void:
	add_to_group("player_controller")
	if ship == null:
		ship = get_parent() as Ship

	if target_reticle_scene != null and get_tree().current_scene != null:
		_reticle = target_reticle_scene.instantiate() as TargetReticle
		if _reticle != null:
			_reticle.player_ship = ship
			_reticle.target_radius = mouse_target_radius
			get_tree().current_scene.add_child.call_deferred(_reticle)

	if target_hud_scene != null and get_tree().current_scene != null:
		var target_hud: Node = target_hud_scene.instantiate()
		get_tree().current_scene.add_child.call_deferred(target_hud)


func _process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return

	_update_targeting()
	if movement_mode == MovementMode.MOUSE and Input.is_key_pressed(KEY_TAB):
		if not _tab_was_pressed:
			_cycle_target()
		_tab_was_pressed = true
	else:
		_tab_was_pressed = false


func _physics_process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return

	match movement_mode:
		MovementMode.KEYBOARD:
			_process_keyboard_movement()
		MovementMode.MOUSE:
			_process_mouse_movement()


func _update_targeting() -> void:
	var new_target: Ship = null
	if movement_mode == MovementMode.MOUSE:
		if is_instance_valid(_cycled_target) and not _cycled_target.is_destroyed and _cycled_target.is_inside_tree():
			if ship.global_position.distance_to(_cycled_target.global_position) <= _get_player_weapon_range():
				new_target = _cycled_target
			else:
				_cycled_target = null
		if new_target == null:
			new_target = _find_nearest_enemy_in_range()
	else:
		new_target = _find_enemy_under_mouse()

	if not is_instance_valid(new_target) or new_target.is_destroyed or not new_target.is_inside_tree():
		new_target = null

	if new_target != null:
		current_target = new_target
		if hud_target != new_target:
			hud_target = new_target
			target_changed.emit(hud_target)
	elif movement_mode == MovementMode.MOUSE:
		current_target = null
		hud_target = null
		target_changed.emit(null)
	else:
		# Keep the HUD selection, but stop firing when the mouse leaves an enemy.
		current_target = null

	if hud_target != null and (
		not is_instance_valid(hud_target)
		or hud_target.is_destroyed
		or not hud_target.is_inside_tree()
	):
		hud_target = null
		target_changed.emit(null)

	if is_instance_valid(_reticle):
		_reticle.follow_mouse = movement_mode == MovementMode.KEYBOARD
		_reticle.target = current_target if movement_mode == MovementMode.MOUSE and is_instance_valid(current_target) else null
		_reticle.ring_radius = keyboard_reticle_radius if movement_mode == MovementMode.KEYBOARD else 18.0


func _find_nearest_enemy_in_range() -> Ship:
	var nearest: Ship
	var nearest_distance: float = _get_player_weapon_range()
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Ship = node as Ship
		if enemy == null or enemy.is_destroyed or not enemy.is_inside_tree():
			continue
		var distance: float = ship.global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _find_enemy_under_mouse() -> Ship:
	var mouse_position: Vector2 = ship.get_global_mouse_position()
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Ship = node as Ship
		if enemy == null or enemy.is_destroyed or not enemy.is_inside_tree():
			continue
		if mouse_position.distance_to(enemy.global_position) <= mouse_target_radius:
			return enemy
	return null


## World-space point used by player weapons for aiming. In keyboard mode the
## crosshair is the mouse reticle; HUD selection remains a separate hover target.
func get_aim_position() -> Vector2:
	if ship == null:
		return Vector2.ZERO
	return ship.get_global_mouse_position()


func _get_player_weapon_range() -> float:
	var maximum_range: float = 300.0
	for weapon_node: Node in ship.weapon_instances:
		var weapon: ShipWeapon = weapon_node as ShipWeapon
		if weapon != null and weapon.weapon_data != null:
			maximum_range = maxf(maximum_range, weapon.weapon_data.range)
	return maximum_range


func _cycle_target() -> void:
	var enemies: Array[Ship] = []
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Ship = node as Ship
		if enemy != null and not enemy.is_destroyed and enemy.is_inside_tree() and ship.global_position.distance_to(enemy.global_position) <= _get_player_weapon_range():
			enemies.append(enemy)

	if enemies.is_empty():
		_cycled_target = null
		return

	enemies.sort_custom(func(a: Ship, b: Ship) -> bool:
		return ship.global_position.distance_to(a.global_position) < ship.global_position.distance_to(b.global_position)
	)
	var current_index: int = enemies.find(current_target)
	_cycled_target = enemies[(current_index + 1) % enemies.size()]


func _process_keyboard_movement() -> void:
	var turn_input: float = Input.get_axis(turn_left_action, turn_right_action)
	var thrust_input: float = Input.get_axis(thrust_reverse_action, thrust_forward_action)
	var movement_direction: Vector2 = Vector2.ZERO

	if not is_zero_approx(thrust_input):
		movement_direction = Vector2.RIGHT.rotated(ship.rotation) * thrust_input

	ship.set_movement_input(movement_direction, turn_input)


func _process_mouse_movement() -> void:
	var mouse_position: Vector2 = ship.get_global_mouse_position()
	var to_mouse: Vector2 = mouse_position - ship.global_position
	var distance_to_mouse: float = to_mouse.length()
	var movement_direction: Vector2 = Vector2.ZERO
	var turn_input: float = 0.0

	if not to_mouse.is_zero_approx():
		var angle_difference: float = wrapf(to_mouse.angle() - ship.global_rotation, -PI, PI)
		var full_turn_angle: float = deg_to_rad(maxf(ship.turn_rate, 1.0))
		turn_input = clampf(angle_difference / full_turn_angle, -1.0, 1.0)

		var direction_to_mouse: Vector2 = to_mouse / distance_to_mouse
		var distance_outside_stop_zone: float = maxf(distance_to_mouse - mouse_stop_distance, 0.0)
		var desired_speed: float = 0.0
		if ship.acceleration > 0.0:
			desired_speed = minf(
				ship.movement_speed,
				sqrt(2.0 * ship.acceleration * distance_outside_stop_zone)
			)

		var desired_velocity: Vector2 = direction_to_mouse * desired_speed
		var velocity_error: Vector2 = desired_velocity - ship.velocity
		var response_acceleration: float = maxf(
			ship.acceleration * mouse_velocity_response_time,
			1.0
		)
		movement_direction = (velocity_error / response_acceleration).limit_length(1.0)

	ship.set_movement_input(movement_direction, turn_input, mouse_turn_rate_multiplier)


func toggle_movement_mode() -> void:
	if movement_mode == MovementMode.KEYBOARD:
		movement_mode = MovementMode.MOUSE
	else:
		movement_mode = MovementMode.KEYBOARD
	_cycled_target = null
	_update_targeting()
	movement_mode_changed.emit(movement_mode)
