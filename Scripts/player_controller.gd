extends Node
class_name PlayerController

## Reads player input and forwards movement intent to the shared Ship base.
## The controller decides; Ship applies movement and handles its own physics.

@export var ship: Ship

@export_group("Input")
@export var turn_left_action: StringName = &"ui_left"
@export var turn_right_action: StringName = &"ui_right"
@export var thrust_forward_action: StringName = &"ui_up"
@export var thrust_reverse_action: StringName = &"ui_down"


func _ready() -> void:
	if ship == null:
		ship = get_parent() as Ship


func _physics_process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return

	var turn_input: float = Input.get_axis(turn_left_action, turn_right_action)
	var thrust_input: float = Input.get_axis(thrust_reverse_action, thrust_forward_action)
	var movement_direction: Vector2 = Vector2.ZERO

	if not is_zero_approx(thrust_input):
		movement_direction = Vector2.RIGHT.rotated(ship.rotation) * thrust_input

	ship.set_movement_input(movement_direction, turn_input)
