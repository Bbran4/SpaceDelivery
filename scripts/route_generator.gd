extends RefCounted
class_name RouteGenerator

const DEFAULT_LAYER_NODE_COUNTS: Array[int] = [1, 2, 3, 2, 1]
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

	var layer_counts: Array[int] = _get_safe_layer_counts(mission)
	var fixed_beats_by_slot: Dictionary = {}
	for beat: MissionRouteNode in mission.fixed_beats:
		if beat == null:
			continue
		if beat.depth <= 0 or beat.depth >= layer_counts.size() - 1:
			continue
		if beat.lane < 0 or beat.lane >= layer_counts[beat.depth]:
			continue
		fixed_beats_by_slot["%d:%d" % [beat.depth, beat.lane]] = beat

	var layers: Array[Array] = []
	var previous_layer_average_risk: float = 0.0
	for layer_index: int in range(layer_counts.size()):
		var layer: Array[MissionRouteNode] = []
		var used_titles: Array[String] = []
		for lane_index: int in range(layer_counts[layer_index]):
			var node := MissionRouteNode.new()
			node.node_id = StringName("route_%d_%d" % [layer_index, lane_index])
			node.depth = layer_index
			node.lane = lane_index

			if layer_index == 0:
				node.title = "Contract Dispatch"
				node.description = "Review the route and begin the delivery."
				node.node_kind = MissionRouteNode.NodeKind.START
				node.risk = 0
			elif layer_index == layer_counts.size() - 1:
				node.title = mission.destination_name
				node.description = "Final destination. Deliver %s and close the contract." % mission.cargo_name
				node.node_kind = MissionRouteNode.NodeKind.DESTINATION
				node.risk = 0
			else:
				var slot: String = "%d:%d" % [layer_index, lane_index]
				var fixed_beat: MissionRouteNode = fixed_beats_by_slot.get(slot) as MissionRouteNode
				if fixed_beat != null:
					_apply_fixed_beat(node, fixed_beat)
				else:
					_apply_generated_encounter(
						node, mission, rng, layer_index, used_titles, previous_layer_average_risk
					)
			if node.node_kind == MissionRouteNode.NodeKind.ENCOUNTER:
				used_titles.append(node.title)
			layer.append(node)
		layers.append(layer)
		var layer_risk_total: float = 0.0
		for layer_node: MissionRouteNode in layer:
			layer_risk_total += float(layer_node.risk)
		previous_layer_average_risk = layer_risk_total / float(layer.size())

	for layer_index: int in range(layers.size() - 1):
		var current_layer: Array = layers[layer_index]
		var next_layer: Array = layers[layer_index + 1]
		# Every node in the next layer gets a parent, ensuring reachability.
		for target_index: int in range(next_layer.size()):
			var parent: MissionRouteNode = current_layer[target_index % current_layer.size()]
			_add_connection(parent, next_layer[target_index].node_id)
		# Guarantee every node can progress. Where the next layer has alternatives,
		# give each node at least two distinct exits so choices are real.
		for source_index: int in range(current_layer.size()):
			var source: MissionRouteNode = current_layer[source_index]
			if source.next_node_ids.is_empty():
				_add_connection(source, next_layer[rng.randi_range(0, next_layer.size() - 1)].node_id)
			if next_layer.size() > 1:
				while source.next_node_ids.size() < 2:
					var candidate: MissionRouteNode = next_layer[rng.randi_range(0, next_layer.size() - 1)]
					_add_connection(source, candidate.node_id)
				if rng.randf() < clampf(mission.branch_chance, 0.0, 1.0):
					var candidate: MissionRouteNode = next_layer[rng.randi_range(0, next_layer.size() - 1)]
					_add_connection(source, candidate.node_id)

	var result: Array[MissionRouteNode] = []
	for layer: Array in layers:
		for node: MissionRouteNode in layer:
			result.append(node)
	return result


static func _get_safe_layer_counts(mission: MissionDefinition) -> Array[int]:
	var counts: Array[int] = mission.layer_node_counts.duplicate()
	var valid: bool = counts.size() >= 2
	if valid:
		valid = counts[0] == 1 and counts[counts.size() - 1] == 1
	for count: int in counts:
		if count < 1:
			valid = false
	if not valid:
		push_error("Mission '%s' has invalid layer_node_counts. Using default route shape %s." % [
			mission.mission_id,
			str(DEFAULT_LAYER_NODE_COUNTS),
		])
		return DEFAULT_LAYER_NODE_COUNTS.duplicate()
	return counts


static func _apply_fixed_beat(node: MissionRouteNode, beat: MissionRouteNode) -> void:
	node.title = beat.title
	node.description = beat.description
	node.node_kind = beat.node_kind
	node.encounter_profile = beat.encounter_profile
	node.risk = clampi(beat.risk, 0, 5)
	node.bonus_credits = maxi(0, beat.bonus_credits)


static func _apply_generated_encounter(
	node: MissionRouteNode,
	mission: MissionDefinition,
	rng: RandomNumberGenerator,
	layer_index: int,
	used_titles: Array[String],
	previous_layer_average_risk: float
) -> void:
	# Keep siblings distinct, make the first playable encounter approachable,
	# and bias later layers upward in risk while adding relief after hard layers.
	var candidates: Array[Dictionary] = []
	for encounter: Dictionary in ENCOUNTERS:
		if not used_titles.has(str(encounter["title"])):
			candidates.append(encounter)
	if candidates.is_empty():
		candidates = ENCOUNTERS.duplicate()
	var target_risk: int = clampi(1 + int(floor(float(layer_index - 1) / 2.0)) + mission.risk_bias, 0, 5)
	if layer_index == 1:
		target_risk = mini(target_risk, 2)
	if previous_layer_average_risk >= 3.0:
		target_risk = maxi(0, target_risk - 1)
	elif previous_layer_average_risk <= 1.0 and layer_index >= 3:
		target_risk = mini(5, target_risk + 1)
	var encounter: Dictionary = candidates[0]
	var best_score: float = INF
	for candidate: Dictionary in candidates:
		var candidate_risk: int = clampi(int(candidate["risk"]) + mission.risk_bias, 0, 5)
		if layer_index == 1:
			candidate_risk = mini(candidate_risk, 2)
		var score: float = absf(float(candidate_risk - target_risk)) + rng.randf() * 0.35
		if score < best_score:
			best_score = score
			encounter = candidate
	var is_service_stop: bool = layer_index > 1 and rng.randf() < 0.15
	if is_service_stop:
		node.title = "Unmanned Service Beacon"
		node.description = "A neglected automated service beacon offers a brief systems check and a chance to catch your breath. The maintenance contract expired, naturally."
		node.node_kind = MissionRouteNode.NodeKind.SERVICE
		node.encounter_profile = MissionRouteNode.EncounterProfile.QUIET
		node.risk = 0
		node.bonus_credits = 0
	else:
		node.title = str(encounter["title"])
		node.description = str(encounter["description"])
		node.node_kind = MissionRouteNode.NodeKind.ENCOUNTER
		node.encounter_profile = int(encounter["profile"])
		node.risk = clampi(int(encounter["risk"]) + int(floor(float(layer_index - 1) / 2.0)), 0, 5)
		node.risk = clampi(node.risk + mission.risk_bias, 0, 5)
		if previous_layer_average_risk >= 3.0:
			node.risk = maxi(0, node.risk - 1)
		if layer_index == 1:
			node.risk = mini(node.risk, 2)
		node.bonus_credits = int(encounter["bonus"]) + rng.randi_range(0, 15)


static func _add_connection(node: MissionRouteNode, next_id: StringName) -> void:
	if not node.next_node_ids.has(String(next_id)):
		node.next_node_ids.append(String(next_id))


static func validate_route(nodes: Array[MissionRouteNode]) -> PackedStringArray:
	var errors: PackedStringArray = []
	if nodes.is_empty():
		errors.append("Route is empty.")
		return errors

	var by_id: Dictionary = {}
	for node: MissionRouteNode in nodes:
		if node == null:
			errors.append("Route contains a null node.")
			continue
		if by_id.has(node.node_id):
			errors.append("Duplicate id: %s" % node.node_id)
		by_id[node.node_id] = node

	var destinations: int = 0
	for node: MissionRouteNode in nodes:
		if node == null:
			continue
		if node.node_kind == MissionRouteNode.NodeKind.DESTINATION:
			destinations += 1
			if not node.next_node_ids.is_empty():
				errors.append("Destination has exits: %s." % node.node_id)
		elif node.next_node_ids.is_empty():
			errors.append("Dead end: %s" % node.node_id)
		for next_id: StringName in node.next_node_ids:
			var next_node: MissionRouteNode = by_id.get(StringName(next_id)) as MissionRouteNode
			if next_node == null:
				errors.append("%s points to missing %s" % [node.node_id, next_id])
			elif next_node.depth <= node.depth:
				errors.append("Non-forward edge: %s -> %s" % [node.node_id, next_id])
	if destinations != 1:
		errors.append("Expected 1 destination, found %d." % destinations)

	var seen: Dictionary = {}
	var pending: Array[StringName] = [nodes[0].node_id]
	while not pending.is_empty():
		var current_id: StringName = pending.pop_back()
		if seen.has(current_id):
			continue
		seen[current_id] = true
		var current: MissionRouteNode = by_id.get(current_id) as MissionRouteNode
		if current == null:
			continue
		for next_id: StringName in current.next_node_ids:
			pending.append(StringName(next_id))
	for node: MissionRouteNode in nodes:
		if node != null and not seen.has(node.node_id):
			errors.append("Unreachable: %s" % node.node_id)
	return errors
