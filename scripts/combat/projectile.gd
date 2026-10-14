extends Area2D
class_name ShipProjectile

## Runtime projectile. Damage, visuals, and impact behavior are supplied by WeaponData.

@export var damage: float = 10.0
@export var speed: float = 600.0
@export var lifetime: float = 2.0
@export var impact_radius: float = 0.0
@export var visual_style: WeaponData.ProjectileStyle = WeaponData.ProjectileStyle.LASER
@export var visual_color: Color = Color(1.0, 0.86, 0.25, 1.0)
@export_range(0.25, 4.0, 0.05) var visual_scale: float = 1.0

var target_group: StringName = &""
var _age: float = 0.0
var _visual: Polygon2D


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	_update_visual()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var travel: Vector2 = Vector2.RIGHT.rotated(global_rotation) * speed * delta
	global_position += travel

	for node: Node in get_tree().get_nodes_in_group(target_group):
		var target: Ship = node as Ship
		if target == null or target.is_destroyed:
			continue
		if global_position.distance_to(target.global_position) <= 18.0:
			_apply_impact(target)
			queue_free()
			return


func _update_visual() -> void:
	if _visual == null:
		return
	_visual.color = visual_color
	_visual.scale = Vector2.ONE * visual_scale
	match visual_style:
		WeaponData.ProjectileStyle.LASER:
			_visual.polygon = PackedVector2Array([Vector2(8, 0), Vector2(-5, -3), Vector2(-5, 3)])
		WeaponData.ProjectileStyle.PLASMA:
			_visual.polygon = PackedVector2Array([Vector2(7, 0), Vector2(3, -5), Vector2(-4, -5), Vector2(-7, 0), Vector2(-4, 5), Vector2(3, 5)])
		WeaponData.ProjectileStyle.LANCE:
			_visual.polygon = PackedVector2Array([Vector2(13, 0), Vector2(-7, -2), Vector2(-4, 0), Vector2(-7, 2)])


func _apply_impact(primary_target: Ship) -> void:
	primary_target.take_damage(damage)
	if impact_radius <= 0.0:
		return
	for node: Node in get_tree().get_nodes_in_group(target_group):
		var nearby_target: Ship = node as Ship
		if nearby_target == null or nearby_target == primary_target or nearby_target.is_destroyed:
			continue
		if global_position.distance_to(nearby_target.global_position) <= impact_radius:
			nearby_target.take_damage(damage * 0.5)
