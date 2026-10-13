extends Resource
class_name MissionDefinition

## Authored delivery contract plus a directed route graph.

@export var mission_id: StringName = &""
@export var title: String = ""
@export var client_name: String = ""
@export var cargo_description: String = ""
@export var destination_name: String = ""
@export_multiline var briefing: String = ""
@export_range(0, 100000, 1) var base_reward_credits: int = 100
@export var risk_label: String = "Routine"
@export var start_node_id: StringName = &"dispatch"
@export var destination_node_id: StringName = &"destination"
@export var route_nodes: Array[MissionRouteNode] = []


func get_route_node(node_id: StringName) -> MissionRouteNode:
	for route_node: MissionRouteNode in route_nodes:
		if route_node != null and route_node.node_id == node_id:
			return route_node
	return null


## Returns validation errors. An empty array means the graph is structurally valid.
func validate_route_graph() -> PackedStringArray:
	var errors: PackedStringArray = []
	var node_ids: Dictionary = {}

	for route_node: MissionRouteNode in route_nodes:
		if route_node == null:
			errors.append("Route contains an empty node.")
			continue
		if route_node.node_id == &"":
			errors.append("Every route node needs an ID.")
			continue
		if node_ids.has(route_node.node_id):
			errors.append("Duplicate route node ID: %s" % route_node.node_id)
		node_ids[route_node.node_id] = true

	if not node_ids.has(start_node_id):
		errors.append("Start node '%s' does not exist." % start_node_id)
	if not node_ids.has(destination_node_id):
		errors.append("Destination node '%s' does not exist." % destination_node_id)
	if not errors.is_empty():
		return errors

	for route_node: MissionRouteNode in route_nodes:
		if route_node == null:
			continue
		if route_node.node_id == destination_node_id and not route_node.next_node_ids.is_empty():
			errors.append("Destination node must not have outgoing connections.")
		for next_id: StringName in route_node.next_node_ids:
			if not node_ids.has(next_id):
				errors.append("Node '%s' points to missing node '%s'." % [route_node.node_id, next_id])

	var visited: Dictionary = {}
	var pending: Array[StringName] = [start_node_id]
	while not pending.is_empty():
		var current_id: StringName = pending.pop_front()
		if visited.has(current_id):
			continue
		visited[current_id] = true
		var current_node: MissionRouteNode = get_route_node(current_id)
		if current_node == null:
			continue
		for next_id: StringName in current_node.next_node_ids:
			if node_ids.has(next_id) and not visited.has(next_id):
				pending.append(next_id)

	if not visited.has(destination_node_id):
		errors.append("Destination is unreachable from the start node.")
	for route_node: MissionRouteNode in route_nodes:
		if route_node != null and not visited.has(route_node.node_id):
			errors.append("Node '%s' is unreachable from the start." % route_node.node_id)

	return errors
