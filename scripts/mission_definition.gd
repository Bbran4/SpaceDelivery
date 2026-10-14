extends Resource
class_name MissionDefinition

## Authored delivery contract and parameters for procedural route generation.

@export var mission_id: StringName = &""
@export var title: String = ""
@export var client_name: String = ""
@export var cargo_name: String = "Undeclared Cargo"
@export var cargo_type: String = "General Freight"
@export var cargo_description: String = ""
@export_range(0, 1000000, 1) var cargo_value_credits: int = 0
@export_range(1, 100000, 1) var cargo_capacity_required: int = 1
@export_range(0.0, 3.0, 0.1) var cargo_damage_sensitivity: float = 1.0
@export_range(1, 100, 1) var minimum_delivery_integrity_percent: int = 1
@export_range(1, 100, 1) var full_reward_integrity_percent: int = 75
@export_range(0, 100, 1) var damaged_cargo_payout_penalty_percent: int = 25
@export var destination_name: String = ""
@export_multiline var briefing: String = ""
@export_range(0, 100000, 1) var base_reward_credits: int = 100
@export var risk_label: String = "Routine"

## Number of nodes in each route layer, including the start and destination.
## Keep the first and last values at 1 for a single start and destination.
@export var layer_node_counts: Array[int] = [1, 2, 3, 2, 1]
@export_range(0.0, 1.0, 0.05) var branch_chance: float = 0.55
## Added to generated encounter risk, clamped to the supported 0-5 range.
@export_range(-2, 2, 1) var risk_bias: int = 0
## Optional encounter templates placed at their authored depth/lane. Connections are generated.
@export var fixed_beats: Array[MissionRouteNode] = []


## Returns validation errors for generator settings. Empty means settings are usable.
func validate_generator_settings() -> PackedStringArray:
	var errors: PackedStringArray = []
	if layer_node_counts.size() < 2:
		errors.append("Route needs at least a start layer and a destination layer.")
		return errors
	if layer_node_counts[0] != 1:
		errors.append("The first route layer must contain exactly one start node.")
	if layer_node_counts[layer_node_counts.size() - 1] != 1:
		errors.append("The final route layer must contain exactly one destination node.")
	for layer_index: int in range(layer_node_counts.size()):
		if layer_node_counts[layer_index] < 1:
			errors.append("Route layer %d must contain at least one node." % layer_index)
	for beat: MissionRouteNode in fixed_beats:
		if beat == null:
			errors.append("Fixed beats cannot contain empty entries.")
			continue
		if beat.depth <= 0 or beat.depth >= layer_node_counts.size() - 1:
			errors.append("Fixed beat '%s' must be placed between the start and destination layers." % beat.node_id)
		elif beat.lane < 0 or beat.lane >= layer_node_counts[beat.depth]:
			errors.append("Fixed beat '%s' lane %d is outside layer %d." % [beat.node_id, beat.lane, beat.depth])
	return errors
