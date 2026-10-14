extends Node

## Runtime handoff and campaign state shared between route-map and flight scenes.

var active_mission: MissionDefinition
var selected_branch_node_id: StringName = &""
var total_credits: int = 0:
	set(value):
		total_credits = maxi(0, value)
		_save_account_credits()
var mission_resolved: bool = false
var last_mission_result: Dictionary = {}
var ship_condition: Dictionary = {}
var pending_salvage: Array[Dictionary] = []
var salvage_recovery_pending: bool = false
var cargo_integrity_percent: float = 100.0
var generated_route_nodes: Array[MissionRouteNode] = []
var completed_node_ids: Array[StringName] = []
var visible_node_ids: Array[StringName] = []
var current_node_id: StringName = &""
var selected_route_node_id: StringName = &""
var accumulated_route_bonus: int = 0
var accumulated_salvage_cache: int = 0
var credits_collected_this_mission: int = 0
var route_seed: int = 0
var route_flags: Dictionary = {}
var route_history: Array[Dictionary] = []

const ACCOUNT_SAVE_PATH: String = "user://account_progress.cfg"


func _ready() -> void:
	_load_account_credits()


func _load_account_credits() -> void:
	var config := ConfigFile.new()
	if config.load(ACCOUNT_SAVE_PATH) != OK:
		return
	total_credits = maxi(0, int(config.get_value("account", "total_credits", 0)))


func _save_account_credits() -> void:
	var config := ConfigFile.new()
	var load_error: Error = config.load(ACCOUNT_SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load account save before updating credits.")
		return
	config.set_value("account", "total_credits", total_credits)
	var save_error: Error = config.save(ACCOUNT_SAVE_PATH)
	if save_error != OK:
		push_warning("Could not save account credits: %s" % error_string(save_error))


func begin_mission(mission: MissionDefinition, forced_seed: int = -1) -> void:
	ship_condition.clear()
	active_mission = mission
	mission_resolved = false
	cargo_integrity_percent = 100.0
	last_mission_result.clear()
	if forced_seed >= 0:
		route_seed = forced_seed
	else:
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		route_seed = seed_rng.randi()
	var validation_errors: PackedStringArray = []
	generated_route_nodes.clear()
	for attempt: int in range(5):
		generated_route_nodes = RouteGenerator.generate_route(mission, route_seed)
		validation_errors = RouteGenerator.validate_route(generated_route_nodes)
		if validation_errors.is_empty():
			break
		if forced_seed >= 0:
			# A forced seed is a debugging contract: preserve it and report its failure.
			break
		route_seed += 1
	if not validation_errors.is_empty():
		push_error("Generated route failed validation for mission '%s' seed %d: %s" % [
			mission.mission_id, route_seed, "; ".join(validation_errors)
		])
	completed_node_ids.clear()
	visible_node_ids.clear()
	route_flags.clear()
	route_history.clear()
	accumulated_route_bonus = 0
	accumulated_salvage_cache = 0
	credits_collected_this_mission = 0
	current_node_id = generated_route_nodes[0].node_id if not generated_route_nodes.is_empty() else &""
	selected_route_node_id = &""
	selected_branch_node_id = &""
	if current_node_id != &"":
		visible_node_ids.append(current_node_id)


func get_route_node(node_id: StringName) -> MissionRouteNode:
	for route_node: MissionRouteNode in generated_route_nodes:
		if route_node != null and route_node.node_id == node_id:
			return route_node
	return null


func is_node_visible(node_id: StringName) -> bool:
	return visible_node_ids.has(node_id)


func is_node_completed(node_id: StringName) -> bool:
	return completed_node_ids.has(node_id)


func complete_route_node(node_id: StringName) -> void:
	if is_node_completed(node_id):
		return
	var node: MissionRouteNode = get_route_node(node_id)
	if node == null:
		return
	completed_node_ids.append(node_id)
	route_history.append({
		"node_id": String(node.node_id),
		"title": node.title,
		"kind": int(node.node_kind),
		"risk": node.risk,
		"depth": node.depth,
		"lane": node.lane,
	})
	match node.node_kind:
		MissionRouteNode.NodeKind.SERVICE:
			route_flags["visited_service"] = true
		MissionRouteNode.NodeKind.ENCOUNTER:
			route_flags["visited_encounter"] = true
		MissionRouteNode.NodeKind.DESTINATION:
			route_flags["visited_destination"] = true
	route_flags["max_depth_reached"] = maxi(int(route_flags.get("max_depth_reached", 0)), node.depth)
	if node.encounter_profile == MissionRouteNode.EncounterProfile.SALVAGE:
		route_flags["salvage_seen"] = true
	if node.node_kind == MissionRouteNode.NodeKind.SERVICE:
		route_flags["service_seen"] = true
	current_node_id = node_id
	visible_node_ids = completed_node_ids.duplicate()
	for next_id: StringName in node.next_node_ids:
		if not visible_node_ids.has(next_id):
			visible_node_ids.append(next_id)
	selected_route_node_id = &""


func add_node_rewards(node: MissionRouteNode, credits_before: int, credits_after: int) -> void:
	credits_collected_this_mission += maxi(0, credits_after - credits_before)
	if node == null:
		return
	accumulated_route_bonus += maxi(0, node.bonus_credits)
	if node.encounter_profile == MissionRouteNode.EncounterProfile.SALVAGE:
		accumulated_salvage_cache += 50


## Store durability so node-to-node transitions preserve damage.
func save_ship_condition(ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	ship_condition = {
		"current_hull": ship.current_hull,
		"max_hull": ship.max_hull,
		"current_shield": ship.current_shield,
		"max_shield": ship.max_shield,
	}


func save_ship_salvage(ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	pending_salvage.clear()
	for entry: Dictionary in ship.salvage_inventory:
		var item: SalvageItemData = entry.get("item") as SalvageItemData
		var quantity: int = maxi(0, int(entry.get("units", 0)))
		if item == null or quantity <= 0:
			continue
		var found_index: int = -1
		for index: int in range(pending_salvage.size()):
			if str(pending_salvage[index].get("item_id", "")) == str(item.item_id):
				found_index = index
				break
		if found_index >= 0:
			pending_salvage[found_index]["quantity"] = int(pending_salvage[found_index]["quantity"]) + quantity
			pending_salvage[found_index]["total_value"] = int(pending_salvage[found_index]["quantity"]) * maxi(0, item.credit_value)
		else:
			pending_salvage.append({
				"item_id": str(item.item_id),
				"display_name": item.display_name,
				"quantity": quantity,
				"unit_value": maxi(0, item.credit_value),
				"total_value": maxi(0, item.credit_value) * quantity,
				"item": item,
			})
	salvage_recovery_pending = not pending_salvage.is_empty()


func restore_ship_salvage(ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	ship.salvage_inventory.clear()
	for entry: Dictionary in pending_salvage:
		var item: SalvageItemData = entry.get("item") as SalvageItemData
		var quantity: int = maxi(0, int(entry.get("quantity", 0)))
		if item != null and quantity > 0:
			ship.add_cargo_item(item, quantity, true)


func recover_pending_salvage() -> Dictionary:
	if not salvage_recovery_pending or pending_salvage.is_empty():
		return {"items": [], "total_value": 0}
	var items: Array[Dictionary] = pending_salvage.duplicate(true)
	var total_value: int = 0
	for entry: Dictionary in items:
		total_value += maxi(0, int(entry.get("total_value", 0)))
	total_credits += total_value
	pending_salvage.clear()
	salvage_recovery_pending = false
	return {"items": items, "total_value": total_value}


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


## Resolve the contract once, recording payout and wallet balance.
func finish_mission(
	success: bool,
	credits_before_payout: int,
	base_reward: int,
	route_bonus: int,
	result_message: String,
	cargo_condition: String = "INTACT",
	cargo_penalty_percent: int = 0,
	credits_collected: int = 0,
	salvage_recovered: int = 0
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
	# Route caches are side earnings, so they survive contract failure.
	var final_credits_before_payout: int = maxi(0, credits_before_payout)
	final_credits_before_payout += maxi(0, salvage_recovered)
	total_credits = final_credits_before_payout + payout
	repair_ship_condition()
	var route_titles: PackedStringArray = []
	for completed_id: StringName in completed_node_ids:
		var completed_node: MissionRouteNode = get_route_node(completed_id)
		if completed_node != null:
			route_titles.append(completed_node.title)
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
		"base_reward": safe_base_reward if success else 0,
		"route_bonus": safe_route_bonus if success else 0,
		"payout": payout,
		"cargo_condition": cargo_condition,
		"cargo_penalty_percent": penalty_percent,
		"cargo_penalty": cargo_penalty,
		"credits_collected": maxi(0, credits_collected),
		"salvage_recovered": maxi(0, salvage_recovered),
		"gross_payout": gross_payout,
		"total_credits": total_credits,
		"route_seed": route_seed,
		"route_flags": route_flags.duplicate(true),
		"route_history": route_history.duplicate(true),
		"completed_nodes": completed_node_ids.size(),
		"route_summary": "  →  ".join(route_titles),
	}
	return last_mission_result


func clear_mission() -> void:
	ship_condition.clear()
	active_mission = null
	selected_branch_node_id = &""
	selected_route_node_id = &""
	mission_resolved = false
	generated_route_nodes.clear()
	completed_node_ids.clear()
	visible_node_ids.clear()
	current_node_id = &""
