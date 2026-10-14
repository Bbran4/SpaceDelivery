extends RefCounted
class_name RouteGenerator

const ROUTE_LAYERS: Array[int] = [1, 2, 3, 2, 1]
const ENCOUNTERS: Array[Dictionary] = [
	{"title": "Patrol Intercept", "description": "Unscheduled security patrols are scanning civilian traffic. Corporate policy recommends remaining calm and moving at a legally defensible speed.", "profile": MissionRouteNode.EncounterProfile.STANDARD, "risk": 2, "bonus": 15},
	{"title": "Quiet Corridor", "description": "Traffic is sparse and the sensor readings are reassuring. This is statistically where the sensor readings become less reassuring.", "profile": MissionRouteNode.EncounterProfile.QUIET, "risk": 1, "bonus": 5},
	{"title": "Salvage Field", "description": "A cluster of derelict cargo pods is drifting through the lane. Recovery rights are unclear, but the wrecks have not filed an objection.", "profile": MissionRouteNode.EncounterProfile.SALVAGE, "risk": 3, "bonus": 40},
	{"title": "Debris Cut", "description": "A shortcut through a dense debris field. The route is shorter on the map and longer in the insurance paperwork.", "profile": MissionRouteNode.EncounterProfile.SALVAGE, "risk": 3, "bonus": 55},
	{"title": "Licensed Trade Lane", "description": "A monitored commercial corridor with predictable traffic and only moderately unpredictable fees.", "profile": MissionRouteNode.EncounterProfile.QUIET, "risk": 1, "bonus": 10},
	{"title": "Unregistered Contact", "description": "An unidentified ship is shadowing the delivery lane. It has declined to identify itself, which is rarely a sign of excellent customer service.", "profile": MissionRouteNode.EncounterProfile.STANDARD, "risk": 2, "bonus": 25},
	{"title": "Wreckage Beacon", "description": "An automated distress beacon is broadcasting from a wreck. The beacon's warranty expired several decades ago.", "profile": MissionRouteNode.EncounterProfile.SALVAGE, "risk": 2, "bonus": 35},
]


static func generate_route(mission: MissionDefinition, seed_value: int = -1) -> Array[MissionRouteNode]:
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	var layers: Array[Array] = []
	for layer_index: int in range(ROUTE_LAYERS.size()):
		var layer: Array[MissionRouteNode] = []
		for lane_index: int in range(ROUTE_LAYERS[layer_index]):
			var node := MissionRouteNode.new()
			node.node_id = StringName("route_%d_%d" % [layer_index, lane_index])
			node.depth = layer_index
			node.lane = lane_index
			if layer_index == ROUTE_LAYERS.size() - 1:
				node.title = mission.destination_name
				node.description = "Final destination. Deliver %s and close the contract." % mission.cargo_name
				node.node_kind = MissionRouteNode.NodeKind.DESTINATION
				node.risk = 0
			else:
				var encounter: Dictionary = ENCOUNTERS[rng.randi_range(0, ENCOUNTERS.size() - 1)]
				node.title = str(encounter["title"])
				node.description = str(encounter["description"])
				node.node_kind = MissionRouteNode.NodeKind.START if layer_index == 0 else MissionRouteNode.NodeKind.ENCOUNTER
				node.encounter_profile = int(encounter["profile"])
				node.risk = clampi(int(encounter["risk"]) + (1 if mission.risk_label.to_lower().contains("elevated") and rng.randf() < 0.35 else 0), 0, 5)
				node.bonus_credits = int(encounter["bonus"]) + rng.randi_range(0, 15)
			layer.append(node)
		layers.append(layer)

	for layer_index: int in range(layers.size() - 1):
		var current_layer: Array = layers[layer_index]
		var next_layer: Array = layers[layer_index + 1]
		# Every node in the next layer gets a parent, ensuring reachability.
		for target_index: int in range(next_layer.size()):
			var parent: MissionRouteNode = current_layer[target_index % current_layer.size()]
			_add_connection(parent, next_layer[target_index].node_id)
		# Every current node has an outgoing connection; some get a second option.
		for source_index: int in range(current_layer.size()):
			var source: MissionRouteNode = current_layer[source_index]
			if source.next_node_ids.is_empty():
				_add_connection(source, next_layer[rng.randi_range(0, next_layer.size() - 1)].node_id)
			if next_layer.size() > 1 and rng.randf() < 0.55:
				_add_connection(source, next_layer[rng.randi_range(0, next_layer.size() - 1)].node_id)

	var result: Array[MissionRouteNode] = []
	for layer: Array in layers:
		for node: MissionRouteNode in layer:
			result.append(node)
	return result


static func _add_connection(node: MissionRouteNode, next_id: StringName) -> void:
	if not node.next_node_ids.has(String(next_id)):
		node.next_node_ids.append(String(next_id))
