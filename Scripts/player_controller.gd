extends Node
class_name PlayerController

## Reads player input and forwards movement intent to the shared Ship base.
## The controller decides; Ship applies movement and handles its own physics.

signal movement_mode_changed(mode: MovementMode)

enum MovementMode {
	KEYBOARD,
	MOUSE
}

@export var ship: Ship

@export_group("Input")
@export var turn_left_action: StringName = &"left"
@export var turn_right_action: StringName = &"right"
@export var thrust_forward_action: StringName = &"up"
@export var thrust_reverse_action: StringName = &"down"

@export_group("Mouse Movement")
@export_range(0.0, 500.0, 1.0) var mouse_stop_distance: float = 70.0

var movement_mode: MovementMode = MovementMode.KEYBOARD


func _ready() -> void:
	add_to_group("player_controller")
	if ship == null:
		ship = get_parent() as Ship


func _physics_process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return

	match movement_mode:
		MovementMode.KEYBOARD:
			_process_keyboard_movement()
		MovementMode.MOUSE:
			_process_mouse_movement()


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
	var turn_input: float = ship.steer_toward_point(mouse_position)

	if distance_to_mouse > 0.0:
		var direction_to_mouse: Vector2 = to_mouse / distance_to_mouse
		var forward_speed_toward_mouse: float = ship.velocity.dot(direction_to_mouse)
		var stopping_distance: float = 0.0

		if ship.acceleration > 0.0 and forward_speed_toward_mouse > 0.0:
			stopping_distance = (forward_speed_toward_mouse * forward_speed_toward_mouse) / (2.0 * ship.acceleration)

		var should_brake: bool = distance_to_mouse <= mouse_stop_distance + stopping_distance and forward_speed_toward_mouse > 0.0
		if should_brake:
			if not ship.velocity.is_zero_approx():
				movement_direction = -ship.velocity.normalized()
		elif distance_to_mouse > mouse_stop_distance:
			movement_direction = direction_to_mouse

	ship.set_movement_input(movement_direction, turn_input)


func toggle_movement_mode() -> void:
	if movement_mode == MovementMode.KEYBOARD:
		movement_mode = MovementMode.MOUSE
	else:
		movement_mode = MovementMode.KEYBOARD

	movement_mode_changed.emit(movement_mode)
