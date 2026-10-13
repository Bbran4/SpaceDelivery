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
@export_range(1.0, 10.0, 0.1) var mouse_turn_rate_multiplier: float = 3.0
## Approximate time for mouse steering to correct velocity toward the target.
@export_range(0.1, 2.0, 0.05) var mouse_velocity_response_time: float = 0.4

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
	var turn_input: float = 0.0

	if not to_mouse.is_zero_approx():
		var angle_difference: float = wrapf(to_mouse.angle() - ship.rotation, -PI, PI)
		var effective_turn_rate: float = ship.turn_rate * mouse_turn_rate_multiplier
		var full_turn_angle: float = deg_to_rad(maxf(effective_turn_rate, 1.0))
		turn_input = clampf(angle_difference / full_turn_angle, -1.0, 1.0)

		var direction_to_mouse: Vector2 = to_mouse / distance_to_mouse
		var distance_outside_stop_zone: float = maxf(distance_to_mouse - mouse_stop_distance, 0.0)
		var desired_speed: float = ship.movement_speed

		if ship.acceleration > 0.0:
			# Use the braking-distance equation so desired speed falls as the
			# ship approaches the cursor, rather than braking at the last moment.
			desired_speed = minf(
				ship.movement_speed,
				sqrt(2.0 * ship.acceleration * distance_outside_stop_zone)
			)
		elif distance_outside_stop_zone <= 0.0:
			desired_speed = 0.0

		var desired_velocity: Vector2 = direction_to_mouse * desired_speed
		var velocity_error: Vector2 = desired_velocity - ship.velocity
		var response_acceleration: float = maxf(
			ship.acceleration * mouse_velocity_response_time,
			1.0
		)
		movement_direction = (velocity_error / response_acceleration).limit_length(1.0)

	ship.set_movement_input(movement_direction, turn_input)


func toggle_movement_mode() -> void:
	if movement_mode == MovementMode.KEYBOARD:
		movement_mode = MovementMode.MOUSE
	else:
		movement_mode = MovementMode.KEYBOARD

	movement_mode_changed.emit(movement_mode)
