extends Node2D
class_name TargetReticle

## World-space reticle that follows a selected ship or the mouse cursor.

@export var target_radius: float = 25.0

var target: Ship
var follow_mouse: bool = false
var player_ship: Ship


func _process(_delta: float) -> void:
	if follow_mouse and is_instance_valid(player_ship):
		global_position = player_ship.get_global_mouse_position()
		visible = _is_enemy_under_mouse()
	elif is_instance_valid(target) and not target.is_destroyed:
		global_position = target.global_position
		visible = true
	else:
		visible = false


func _is_enemy_under_mouse() -> bool:
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Ship = node as Ship
		if enemy == null or enemy.is_destroyed:
			continue
		if global_position.distance_to(enemy.global_position) <= target_radius:
			return true
	return false
