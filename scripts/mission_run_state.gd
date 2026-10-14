extends Node

## Runtime handoff and persistent campaign wallet for mission flights.

var active_mission: MissionDefinition
var selected_branch_node_id: StringName = &""
var total_credits: int = 0
var mission_resolved: bool = false
var last_mission_result: Dictionary = {}


func begin_mission(mission: MissionDefinition, branch_node_id: StringName) -> void:
	active_mission = mission
	selected_branch_node_id = branch_node_id
	mission_resolved = false
	last_mission_result.clear()


## Resolves a mission once, recording the wallet balance and any successful payout.
func finish_mission(
	success: bool,
	credits_before_payout: int,
	base_reward: int,
	route_bonus: int,
	result_message: String
) -> Dictionary:
	if mission_resolved:
		return last_mission_result

	mission_resolved = true
	var payout: int = maxi(0, base_reward) + maxi(0, route_bonus) if success else 0
	total_credits = maxi(0, credits_before_payout) + payout
	last_mission_result = {
		"success": success,
		"mission_title": active_mission.title if active_mission != null else "Unknown Contract",
		"destination_name": active_mission.destination_name if active_mission != null else "Unknown Destination",
		"message": result_message,
		"base_reward": maxi(0, base_reward) if success else 0,
		"route_bonus": maxi(0, route_bonus) if success else 0,
		"payout": payout,
		"total_credits": total_credits,
	}
	return last_mission_result


func clear_mission() -> void:
	active_mission = null
	selected_branch_node_id = &""
	mission_resolved = false
