extends Camera2D
class_name ShipCameraShake

## Small, short camera shake triggered when an enemy ship is destroyed.

@export_range(0.0, 30.0, 0.5) var shake_strength: float = 5.0
@export_range(0.01, 1.0, 0.01) var shake_duration: float = 0.18

var _shake_time_remaining: float = 0.0


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		_connect_enemy(node)
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	if _shake_time_remaining <= 0.0:
		offset = Vector2.ZERO
		return

	_shake_time_remaining = maxf(_shake_time_remaining - delta, 0.0)
	var strength: float = shake_strength * (_shake_time_remaining / shake_duration)
	offset = Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)


func shake() -> void:
	_shake_time_remaining = shake_duration


func _on_node_added(node: Node) -> void:
	if node.is_in_group("enemy"):
		_connect_enemy(node)


func _connect_enemy(node: Node) -> void:
	var enemy: Ship = node as Ship
	if enemy == null:
		return
	if not enemy.destroyed.is_connected(shake):
		enemy.destroyed.connect(shake)
