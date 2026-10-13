extends Node

## Runtime handoff between the HQ contract board and the mission flight scene.

var active_mission: MissionDefinition
var selected_branch_node_id: StringName = &""


func begin_mission(mission: MissionDefinition, branch_node_id: StringName) -> void:
	active_mission = mission
	selected_branch_node_id = branch_node_id


func clear_mission() -> void:
	active_mission = null
	selected_branch_node_id = &""
