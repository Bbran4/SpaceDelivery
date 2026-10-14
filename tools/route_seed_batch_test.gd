extends SceneTree

const MISSION_PATHS: Array[String] = [
	"res://resources/missions/fragile_relay_components.tres",
	"res://resources/missions/priority_medical_shipment.tres",
]
const DEFAULT_SEED_COUNT: int = 2000


func _initialize() -> void:
	call_deferred("_run_batch")


func _run_batch() -> void:
	var seed_count: int = DEFAULT_SEED_COUNT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			seed_count = maxi(1, int(argument.trim_prefix("--seeds=")))

	for mission_path: String in MISSION_PATHS:
		var mission: MissionDefinition = load(mission_path) as MissionDefinition
		if mission == null:
			push_error("Could not load mission resource: %s" % mission_path)
			continue
		var stats: Dictionary = _new_stats()
		for seed_value: int in range(1, seed_count + 1):
			var route: Array[MissionRouteNode] = RouteGenerator.generate_route(mission, seed_value)
			_record_route(stats, route, RouteGenerator.validate_route(route), seed_value)
		_print_stats(mission_path, seed_count, stats)
	quit()


func _new_stats() -> Dictionary:
	return {
		"routes": 0, "validation_failures": 0, "failure_examples": [],
		"first_encounter_risk_3_plus": 0, "exit_total": 0, "node_total": 0,
		"single_exit_nodes": 0, "duplicate_sibling_routes": 0, "no_service_routes": 0,
		"worst_risk_streak": 0, "min_path_risk": 2147483647, "max_path_risk": 0,
		"min_path_bonus": 2147483647, "max_path_bonus": 0,
	}


func _record_route(stats: Dictionary, route: Array[MissionRouteNode], errors: PackedStringArray, seed_value: int) -> void:
	stats["routes"] += 1
	if not errors.is_empty():
		stats["validation_failures"] += 1
		if (stats["failure_examples"] as Array).size() < 10:
			stats["failure_examples"].append("seed %d: %s" % [seed_value, "; ".join(errors)])

	if route.is_empty():
		return
	var by_id: Dictionary = {}
	var layers: Dictionary = {}
	var has_service: bool = false
	for node: MissionRouteNode in route:
		by_id[node.node_id] = node
		if not layers.has(node.depth):
			layers[node.depth] = []
		layers[node.depth].append(node)
		stats["node_total"] += 1
		stats["exit_total"] += node.next_node_ids.size()
		if node.next_node_ids.size() == 1:
			stats["single_exit_nodes"] += 1
		if node.node_kind == MissionRouteNode.NodeKind.SERVICE:
			has_service = true
	if not has_service:
		stats["no_service_routes"] += 1

	var first_encounter: MissionRouteNode = _first_encounter(route)
	if first_encounter != null and first_encounter.risk >= 3:
		stats["first_encounter_risk_3_plus"] += 1

	var duplicate_siblings: bool = false
	for depth: int in layers:
		var signatures: Dictionary = {}
		for node: MissionRouteNode in layers[depth]:
			if node.node_kind != MissionRouteNode.NodeKind.ENCOUNTER:
				continue
			var signature: String = "%d:%d" % [int(node.encounter_profile), node.risk]
			if signatures.has(signature):
				duplicate_siblings = true
			signatures[signature] = true
	if duplicate_siblings:
		stats["duplicate_sibling_routes"] += 1

	var stack: Array[Dictionary] = [{"id": route[0].node_id, "risk": 0, "bonus": 0, "streak": 0}]
	while not stack.is_empty():
		var item: Dictionary = stack.pop_back()
		var node: MissionRouteNode = by_id.get(StringName(item["id"])) as MissionRouteNode
		if node == null:
			continue
		var path_risk: int = int(item["risk"]) + node.risk
		var path_bonus: int = int(item["bonus"]) + node.bonus_credits
		var streak: int = int(item["streak"]) + 1 if node.risk >= 3 else 0
		stats["worst_risk_streak"] = maxi(int(stats["worst_risk_streak"]), streak)
		if node.node_kind == MissionRouteNode.NodeKind.DESTINATION:
			stats["min_path_risk"] = mini(int(stats["min_path_risk"]), path_risk)
			stats["max_path_risk"] = maxi(int(stats["max_path_risk"]), path_risk)
			stats["min_path_bonus"] = mini(int(stats["min_path_bonus"]), path_bonus)
			stats["max_path_bonus"] = maxi(int(stats["max_path_bonus"]), path_bonus)
		else:
			for next_id: StringName in node.next_node_ids:
				stack.append({
					"id": next_id, "risk": path_risk, "bonus": path_bonus, "streak": streak
				})


func _first_encounter(route: Array[MissionRouteNode]) -> MissionRouteNode:
	var best: MissionRouteNode = null
	for node: MissionRouteNode in route:
		if node.node_kind != MissionRouteNode.NodeKind.ENCOUNTER:
			continue
		if best == null or node.depth < best.depth:
			best = node
	return best


func _print_stats(mission_path: String, seed_count: int, stats: Dictionary) -> void:
	var routes: int = maxi(1, int(stats["routes"]))
	var nodes: int = maxi(1, int(stats["node_total"]))
	var exit_average: float = float(stats["exit_total"]) / float(nodes)
	var single_exit_share: float = 100.0 * float(stats["single_exit_nodes"]) / float(nodes)
	var first_risk_share: float = 100.0 * float(stats["first_encounter_risk_3_plus"]) / float(routes)
	var duplicate_share: float = 100.0 * float(stats["duplicate_sibling_routes"]) / float(routes)
	var service_missing_share: float = 100.0 * float(stats["no_service_routes"]) / float(routes)
	print("\n=== Route batch: %s ===" % mission_path)
	print("Seeds: 1..%d | Routes: %d | Validation failures: %d" % [seed_count, routes, stats["validation_failures"]])
	print("First encounter risk >= 3: %d (%.2f%%)" % [stats["first_encounter_risk_3_plus"], first_risk_share])
	print("Exits per node: average %.2f | minimum %d | single-exit share %.2f%%" % [
		exit_average, _minimum_exits_for_shape(), single_exit_share
	])
	print("Routes with duplicate sibling profile+risk: %d (%.2f%%)" % [stats["duplicate_sibling_routes"], duplicate_share])
	print("Routes without a service stop: %d (%.2f%%)" % [stats["no_service_routes"], service_missing_share])
	print("Worst consecutive risk-3+ streak: %d" % stats["worst_risk_streak"])
	print("Path total risk: min %d | max %d" % [stats["min_path_risk"], stats["max_path_risk"]])
	print("Path total bonus: min %d | max %d" % [stats["min_path_bonus"], stats["max_path_bonus"]])
	for example: String in stats["failure_examples"]:
		print("  FAILURE: %s" % example)


func _minimum_exits_for_shape() -> int:
	# Non-destination nodes should all have an exit; destination has zero.
	return 0
