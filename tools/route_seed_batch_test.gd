extends SceneTree

const MISSION_PATHS: Array[String] = [
	"res://resources/missions/fragile_relay_components.tres",
	"res://resources/missions/priority_medical_shipment.tres",
]
const DEFAULT_SEED_COUNT: int = 1000


func _initialize() -> void:
	call_deferred("_run_batch")


func _run_batch() -> void:
	var seed_count: int = DEFAULT_SEED_COUNT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			seed_count = maxi(1, int(argument.trim_prefix("--seeds=")))

	var failures: int = 0
	var routes_checked: int = 0
	for mission_path: String in MISSION_PATHS:
		var mission: MissionDefinition = load(mission_path) as MissionDefinition
		if mission == null:
			push_error("Could not load mission resource: %s" % mission_path)
			failures += 1
			continue
		for seed_value: int in range(seed_count):
			var route: Array[MissionRouteNode] = RouteGenerator.generate_route(mission, seed_value)
			routes_checked += 1
			var errors: PackedStringArray = _validate_route(route)
			if not errors.is_empty():
				push_error("%s seed %d: %s" % [mission_path, seed_value, "; ".join(errors)])
				failures += 1

	print("Route batch complete: %d routes checked, %d failures." % [routes_checked, failures])
	quit(1 if failures > 0 else 0)


func _validate_route(route: Array[MissionRouteNode]) -> PackedStringArray:
	var errors: PackedStringArray = []
	if route.is_empty():
		errors.append("route is empty")
		return errors

	var nodes_by_id: Dictionary = {}
	var layers: Dictionary = {}
	for node: MissionRouteNode in route:
		nodes_by_id[node.node_id] = node
		if not layers.has(node.depth):
			layers[node.depth] = []
		layers[node.depth].append(node)
		if node.node_kind != MissionRouteNode.NodeKind.DESTINATION and node.next_node_ids.is_empty():
			errors.append("non-destination node %s has no exits" % node.node_id)
		for next_id: StringName in node.next_node_ids:
			if not nodes_by_id.has(next_id) and not _route_has_node(route, next_id):
				errors.append("node %s links to missing node %s" % [node.node_id, next_id])

	for depth: int in layers:
		var siblings: Array = layers[depth]
		var seen_titles: Dictionary = {}
		for node: MissionRouteNode in siblings:
			if node.node_kind == MissionRouteNode.NodeKind.ENCOUNTER:
				if seen_titles.has(node.title):
					errors.append("layer %d repeats encounter '%s'" % [depth, node.title])
				seen_titles[node.title] = true
			if depth < _max_depth(layers) and int(layers.get(depth + 1, []).size()) > 1:
				if node.next_node_ids.size() < 2:
					errors.append("node %s has fewer than two exits despite a branching next layer" % node.node_id)

	var start: MissionRouteNode = route[0]
	var visited: Dictionary = {}
	var pending: Array[StringName] = [start.node_id]
	while not pending.is_empty():
		var current_id: StringName = pending.pop_back()
		if visited.has(current_id):
			continue
		visited[current_id] = true
		var current: MissionRouteNode = nodes_by_id.get(current_id) as MissionRouteNode
		if current == null:
			continue
		for next_id: StringName in current.next_node_ids:
			pending.append(next_id)
	if visited.size() != route.size():
		errors.append("only %d of %d nodes are reachable from start" % [visited.size(), route.size()])
	return errors


func _route_has_node(route: Array[MissionRouteNode], node_id: StringName) -> bool:
	for node: MissionRouteNode in route:
		if node.node_id == node_id:
			return true
	return false


func _max_depth(layers: Dictionary) -> int:
	var result: int = 0
	for depth: int in layers.keys():
		result = maxi(result, int(depth))
	return result
