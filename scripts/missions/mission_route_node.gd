extends Resource
class_name MissionRouteNode

## A single node in a mission's route graph.

enum NodeKind {
	START,
	ENCOUNTER,
	SERVICE,
	DESTINATION,
}

enum EncounterProfile {
	STANDARD,
	QUIET,
	SALVAGE,
}

## Gameplay objective resolved by the flight scene.
enum ObjectiveType {
	COMBAT,
	SERVICE,
	SALVAGE_RECOVERY,
	RESCUE,
	ESCORT,
	INSPECTION,
	DELIVERY,
}

@export var node_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var node_kind: NodeKind = NodeKind.ENCOUNTER
@export var next_node_ids: PackedStringArray = PackedStringArray()
@export_range(0, 5, 1) var risk: int = 0
@export_range(0, 100000, 1) var bonus_credits: int = 0
@export var encounter_profile: EncounterProfile = EncounterProfile.STANDARD
@export var objective_type: ObjectiveType = ObjectiveType.COMBAT
@export_range(0, 20, 1) var depth: int = 0
@export_range(0, 20, 1) var lane: int = 0
