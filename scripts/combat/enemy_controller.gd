extends Node
class_name EnemyController

## Simple pursuit AI. It chooses movement intent; Ship handles the actual physics.

@export var ship: Ship
@export_range(0.0, 2000.0, 1.0) var preferred_distance: float = 180.0
@export_range(1.0, 89.0, 1.0) var pursuit_angle_tolerance: float = 65.0

var target: Ship
## Enemies assigned to a mission can wait until the player clears a hazard zone.
@export var pursuit_activation_x: float = 0.0


func _ready() -> void:
	if ship == null:
		ship = get_parent() as Ship
	if ship != null and ship.enemy_loadout != null:
		preferred_distance = ship.enemy_loadout.preferred_distance
		pursuit_angle_tolerance = ship.enemy_loadout.pursuit_angle_tolerance

	var player_controller: PlayerController = get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player_controller != null:
		target = player_controller.ship


func _physics_process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return
	if not is_instance_valid(target) or target.is_destroyed:
		ship.set_movement_input(Vector2.ZERO)
		return
	if target.global_position.x < pursuit_activation_x:
		ship.set_movement_input(Vector2.ZERO)
		return

	var to_target: Vector2 = target.global_position - ship.global_position
	var distance_to_target: float = to_target.length()
	if to_target.is_zero_approx():
		ship.set_movement_input(Vector2.ZERO)
		return

	var angle_difference: float = wrapf(to_target.angle() - ship.global_rotation, -PI, PI)
	var turn_input: float = clampf(
		angle_difference / deg_to_rad(maxf(ship.turn_rate, 1.0)),
		-1.0,
		1.0
	)

	var movement_direction: Vector2 = Vector2.ZERO
	if distance_to_target > preferred_distance and absf(angle_difference) < deg_to_rad(pursuit_angle_tolerance):
		movement_direction = Vector2.RIGHT.rotated(ship.global_rotation)

	ship.set_movement_input(movement_direction, turn_input)
