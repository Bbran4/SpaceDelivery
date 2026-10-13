extends Area2D
class_name ShipProjectile

## Lightweight projectile. Targeting is decided by the firing weapon.

@export var damage: float = 10.0
@export var speed: float = 600.0
@export var lifetime: float = 2.0

var target_group: StringName = &""
var _age: float = 0.0


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
			target.take_damage(damage)
			queue_free()
			return
