extends Node2D
class_name EncounterSpawner

## Lightweight test-only spawner. Cycles through configured enemy scenes so a
## single encounter can contain several archetypes without duplicating Ship code.

@export var enemy_scenes: Array[PackedScene] = []
@export_range(1, 50, 1) var spawn_count: int = 6
@export_range(0.0, 1000.0, 10.0) var spawn_radius: float = 180.0
@export var spawn_on_ready: bool = true


func _ready() -> void:
	if spawn_on_ready:
		spawn_encounter.call_deferred()


## Returns the enemies actually spawned so mission flow can track their defeat.
func spawn_encounter(encounter_profile: int = MissionRouteNode.EncounterProfile.STANDARD) -> Array[Ship]:
	var spawned_enemies: Array[Ship] = []
	if enemy_scenes.is_empty():
		push_warning("EncounterSpawner has no enemy scenes assigned.")
		return spawned_enemies

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		return spawned_enemies

	for index: int in range(spawn_count):
		var scene_index: int = index % enemy_scenes.size()
		match encounter_profile:
			MissionRouteNode.EncounterProfile.QUIET:
				# Prefer scouts and fighters on the lower-risk route.
				scene_index = index % mini(2, enemy_scenes.size())
			MissionRouteNode.EncounterProfile.SALVAGE:
				# Salvage lanes attract tougher patrols. Skip scouts when possible.
				scene_index = mini(1, enemy_scenes.size() - 1) + (index % maxi(1, enemy_scenes.size() - 1))
				scene_index %= enemy_scenes.size()
		var enemy_scene: PackedScene = enemy_scenes[scene_index]
		if enemy_scene == null:
			continue
		var enemy: Ship = enemy_scene.instantiate() as Ship
		if enemy == null:
			push_warning("Encounter scene root must inherit from Ship.")
			continue
		scene_root.add_child(enemy)
		var angle: float = TAU * float(index) / float(spawn_count)
		enemy.global_position = global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
		spawned_enemies.append(enemy)
	return spawned_enemies
