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
	var target: Ship = _find_target()
	if target == null or _cooldown > 0.0:
		return

	_fire_at(target)
	_cooldown = 1.0 / maxf(weapon_data.fire_rate, 0.1)


func _find_target() -> Ship:
	if ship.is_in_group("player_ship"):
		var controller: PlayerController = get_tree().get_first_node_in_group("player_controller") as PlayerController
		if controller == null:
			return null
		var selected_target: Ship = controller.current_target
		if selected_target == null or selected_target.is_destroyed:
			return null
		if ship.global_position.distance_to(selected_target.global_position) > weapon_data.range:
			return null
		return selected_target

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


func _fire_at(target: Ship) -> void:
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
	projectile.global_rotation = global_position.direction_to(target.global_position).angle()
	get_tree().current_scene.add_child(projectile)
	if ship.has_signal("weapon_fired"):
		ship.weapon_fired.emit(self, target)
