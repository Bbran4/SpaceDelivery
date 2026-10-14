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
	result_message: String,
	cargo_condition: String = "INTACT",
	cargo_penalty_percent: int = 0,
	credits_collected: int = 0
) -> Dictionary:
	if mission_resolved:
		return last_mission_result

	mission_resolved = true
	var safe_base_reward: int = maxi(0, base_reward)
	var safe_route_bonus: int = maxi(0, route_bonus)
	var gross_payout: int = safe_base_reward + safe_route_bonus if success else 0
	var penalty_percent: int = clampi(cargo_penalty_percent, 0, 100) if success else 0
	var cargo_penalty: int = roundi(float(gross_payout) * float(penalty_percent) / 100.0)
	var payout: int = maxi(0, gross_payout - cargo_penalty)
	total_credits = maxi(0, credits_before_payout) + payout
	last_mission_result = {
		"success": success,
		"mission_title": active_mission.title if active_mission != null else "Unknown Contract",
		"destination_name": active_mission.destination_name if active_mission != null else "Unknown Destination",
		"message": result_message,
		"base_reward": maxi(0, base_reward) if success else 0,
		"route_bonus": maxi(0, route_bonus) if success else 0,
		"payout": payout,
		"cargo_condition": cargo_condition,
		"cargo_penalty_percent": penalty_percent,
		"cargo_penalty": cargo_penalty,
		"credits_collected": maxi(0, credits_collected),
		"gross_payout": gross_payout,
		"total_credits": total_credits,
	}
	return last_mission_result


func clear_mission() -> void:
	active_mission = null
	selected_branch_node_id = &""
	mission_resolved = false
