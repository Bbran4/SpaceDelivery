extends Resource
class_name MissionRouteNode

## A single node in a mission's authored route graph.

enum NodeKind {
	START,
	ENCOUNTER,
	CHOICE,
	DESTINATION,
}

@export var node_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var node_kind: NodeKind = NodeKind.ENCOUNTER
@export var next_node_ids: PackedStringArray = PackedStringArray()
@export_range(0, 5, 1) var risk: int = 0
@export_range(0, 100000, 1) var bonus_credits: int = 0
