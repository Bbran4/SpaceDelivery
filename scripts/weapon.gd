extends Node2D
class_name ShipWeapon

## Runtime weapon attached by Ship.install_module(). Selects the nearest hostile
## ship in range and fires projectiles at the configured cadence.

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene

var ship: Ship
var _cooldown: float = 0.0
var _target_group: StringName = &""


func _ready() -> void:
	ship = get_parent() as Ship
	if ship == null:
		push_warning("ShipWeapon must be a child of a Ship.")
		set_physics_process(false)
		return

	if ship.is_in_group("player_ship"):
		_target_group = &"enemy"
	else:
		_target_group = &"player_ship"


func _physics_process(delta: float) -> void:
	if ship == null or ship.is_destroyed or weapon_data == null or projectile_scene == null:
		return

	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return

	var target: Ship = _find_target()
	if ship.is_in_group("player_ship"):
		var controller: PlayerController = get_tree().get_first_node_in_group("player_controller") as PlayerController
		if controller != null and controller.movement_mode == PlayerController.MovementMode.KEYBOARD:
			# Keyboard mode is cursor-aimed: always fire toward the cursor, even
			# when no hostile ship is currently inside this weapon's range.
			_fire_at(target, controller.get_aim_position())
			_cooldown = 1.0 / maxf(weapon_data.fire_rate, 0.1)
			return

	if target == null:
		return

	_fire_at(target, target.global_position)
	_cooldown = 1.0 / maxf(weapon_data.fire_rate, 0.1)


func _find_target() -> Ship:
	if ship.is_in_group("player_ship"):
		var controller: PlayerController = get_tree().get_first_node_in_group("player_controller") as PlayerController
		if controller == null:
			return null
		var selected_target: Ship = controller.current_target
		if selected_target != null and not selected_target.is_destroyed:
			if ship.global_position.distance_to(selected_target.global_position) <= weapon_data.range:
				return selected_target
		# If the selected target was destroyed or is outside this weapon's range,
		# this weapon independently acquires another hostile target.
		return _find_nearest_target_in_range()

	return _find_nearest_target_in_range()


func _find_nearest_target_in_range() -> Ship:
	var nearest_target: Ship
	var nearest_distance: float = weapon_data.range

	for node: Node in get_tree().get_nodes_in_group(_target_group):
		var candidate: Ship = node as Ship
		if candidate == null or candidate.is_destroyed:
			continue
		var distance: float = ship.global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_target = candidate

	return nearest_target


func _fire_at(target: Ship, aim_position: Vector2) -> void:
	var projectile: ShipProjectile = projectile_scene.instantiate() as ShipProjectile
	if projectile == null:
		return

	projectile.damage = weapon_data.projectile_damage
	projectile.speed = weapon_data.projectile_speed
	projectile.lifetime = weapon_data.projectile_lifetime
	projectile.impact_radius = weapon_data.impact_radius
	projectile.visual_style = weapon_data.projectile_style
	projectile.visual_color = weapon_data.projectile_color
	projectile.visual_scale = weapon_data.projectile_scale
	projectile.target_group = _target_group
	projectile.global_position = global_position
	projectile.global_rotation = global_position.direction_to(aim_position).angle()
	get_tree().current_scene.add_child(projectile)
	if ship.has_signal("weapon_fired"):
		ship.weapon_fired.emit(self, target)
