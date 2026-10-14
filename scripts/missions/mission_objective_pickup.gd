extends Area2D
class_name MissionObjectivePickup

## Objective item that must be collected in flight and returned to the destination.

@export var pickup_radius: float = 30.0
var objective_id: StringName = &""
var display_name: String = "Mission Item"
var _collected: bool = false
var _visual: Polygon2D


func configure(objective: MissionObjectiveDefinition) -> void:
	if objective == null:
		return
	objective_id = objective.objective_id
	display_name = objective.title
	_update_visual()


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	_update_visual()


func _process(_delta: float) -> void:
	if _collected or objective_id == &"":
		return
	for node: Node in get_tree().get_nodes_in_group("player_ship"):
		var ship: Ship = node as Ship
		if ship == null or ship.is_destroyed or not ship.is_inside_tree():
			continue
		if global_position.distance_to(ship.global_position) > pickup_radius:
			continue
		if MissionRunState.carry_mission_objective(objective_id):
			_collected = true
			queue_free()
			return


func _update_visual() -> void:
	if _visual == null:
		return
	_visual.color = Color(0.3, 0.95, 0.95, 1.0)
	_visual.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(8, -5), Vector2(8, 5),
		Vector2(0, 10), Vector2(-8, 5), Vector2(-8, -5)
	])
