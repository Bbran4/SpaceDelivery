extends Node

## Runtime handoff and persistent campaign wallet for mission flights.

var active_mission: MissionDefinition
var selected_branch_node_id: StringName = &""
var total_credits: int = 0
var mission_resolved: bool = false
var last_mission_result: Dictionary = {}
var ship_condition: Dictionary = {}
var cargo_integrity_percent: float = 100.0


func begin_mission(mission: MissionDefinition, branch_node_id: StringName) -> void:
	active_mission = mission
	selected_branch_node_id = branch_node_id
	mission_resolved = false
	cargo_integrity_percent = 100.0
	last_mission_result.clear()


## Store durability so route-node scene transitions can restore hull and shields.
func save_ship_condition(ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	ship_condition = {
		"current_hull": ship.current_hull,
		"max_hull": ship.max_hull,
		"current_shield": ship.current_shield,
		"max_shield": ship.max_shield,
	}


func restore_ship_condition(ship: Ship) -> void:
	if not is_instance_valid(ship) or ship_condition.is_empty():
		return
	ship.current_hull = clampf(float(ship_condition.get("current_hull", ship.max_hull)), 0.0, ship.max_hull)
	ship.current_shield = clampf(float(ship_condition.get("current_shield", ship.max_shield)), 0.0, ship.max_shield)
	ship.hull_changed.emit(ship.current_hull, ship.max_hull)
	ship.shield_changed.emit(ship.current_shield, ship.max_shield)


func repair_ship_condition() -> void:
	if ship_condition.is_empty():
		return
	ship_condition["current_hull"] = float(ship_condition.get("max_hull", 0.0))
	ship_condition["current_shield"] = float(ship_condition.get("max_shield", 0.0))


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
	if success:
		repair_ship_condition()
	last_mission_result = {
		"success": success,
		"mission_title": active_mission.title if active_mission != null else "Unknown Contract",
		"destination_name": active_mission.destination_name if active_mission != null else "Unknown Destination",
		"cargo_name": active_mission.cargo_name if active_mission != null else "Unknown Cargo",
		"cargo_type": active_mission.cargo_type if active_mission != null else "Unknown Type",
		"cargo_value_credits": active_mission.cargo_value_credits if active_mission != null else 0,
		"cargo_integrity_percent": cargo_integrity_percent,
		"cargo_minimum_integrity_percent": active_mission.minimum_delivery_integrity_percent if active_mission != null else 0,
		"cargo_full_reward_integrity_percent": active_mission.full_reward_integrity_percent if active_mission != null else 0,
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
