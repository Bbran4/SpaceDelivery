extends Resource
class_name MissionDefinition

## Authored delivery contract and parameters for procedural route generation.
## Treat this resource as immutable during play; per-attempt progress belongs to MissionRunState.

@export var mission_id: StringName = &""
@export var title: String = ""
@export var client_name: String = ""
@export var cargo_name: String = "Undeclared Cargo"
@export var cargo_type: String = "General Freight"
@export_enum("Standard", "Fragile", "Bulk", "Valuable") var cargo_variant: int = 0
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

@export_group("Mission Board")
## Shown on the mission card, e.g. "Standard  ·  Mining Colony". When empty the card
## falls back to the cargo class plus the destination name.
@export var mission_type: String = ""
## Card artwork. Square art works best. When empty the card draws a placeholder.
@export var icon: Texture2D

@export_group("Route and Objectives")
## Required and optional objectives. Empty preserves legacy delivery-only contracts.
@export var objectives: Array[MissionObjectiveDefinition] = []

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


## Full authoring validation, run before a contract is offered or launched.
func validate_contract() -> PackedStringArray:
	var errors: PackedStringArray = validate_generator_settings()
	if mission_id == &"":
		errors.append("Mission ID cannot be empty.")
	if title.strip_edges().is_empty():
		errors.append("Mission title cannot be empty.")
	if client_name.strip_edges().is_empty():
		errors.append("Mission '%s' needs a client name." % mission_id)
	if destination_name.strip_edges().is_empty():
		errors.append("Mission '%s' needs a destination." % mission_id)
	if base_reward_credits < 0:
		errors.append("Mission '%s' has a negative base reward." % mission_id)
	if cargo_variant < CargoRules.CargoVariant.STANDARD or cargo_variant > CargoRules.CargoVariant.VALUABLE:
		errors.append("Mission cargo variant is unsupported.")
	if cargo_capacity_required < 1:
		errors.append("Mission '%s' must require at least one cargo unit." % mission_id)
	if minimum_delivery_integrity_percent < 1 or minimum_delivery_integrity_percent > 100:
		errors.append("Mission '%s' has an invalid minimum cargo integrity." % mission_id)
	if full_reward_integrity_percent < minimum_delivery_integrity_percent or full_reward_integrity_percent > 100:
		errors.append("Mission '%s' full-reward integrity must be at least the delivery minimum and at most 100." % mission_id)
	if damaged_cargo_payout_penalty_percent < 0 or damaged_cargo_payout_penalty_percent > 100:
		errors.append("Mission '%s' cargo penalty must be between 0 and 100 percent." % mission_id)
	if cargo_damage_sensitivity < 0.0:
		errors.append("Mission '%s' cargo damage sensitivity cannot be negative." % mission_id)

	var objective_ids: Dictionary = {}
	for objective: MissionObjectiveDefinition in objectives:
		if objective == null:
			errors.append("Mission '%s' contains an empty objective." % mission_id)
			continue
		for objective_error: String in objective.validate_definition():
			errors.append("Mission '%s': %s" % [mission_id, objective_error])
		if objective_ids.has(objective.objective_id):
			errors.append("Mission '%s' has duplicate objective ID '%s'." % [mission_id, objective.objective_id])
		objective_ids[objective.objective_id] = objective
	for objective: MissionObjectiveDefinition in objectives:
		if objective == null:
			continue
		for prerequisite_id: StringName in objective.prerequisite_ids:
			if not objective_ids.has(prerequisite_id):
				errors.append("Objective '%s' references missing prerequisite '%s'." % [objective.objective_id, prerequisite_id])
			elif prerequisite_id == objective.objective_id:
				errors.append("Objective '%s' cannot depend on itself." % objective.objective_id)

	if not _objectives_have_acyclic_prerequisites(objective_ids):
		errors.append("Mission '%s' objective prerequisites contain a cycle." % mission_id)
	return errors


func _objectives_have_acyclic_prerequisites(objective_ids: Dictionary) -> bool:
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for objective_id: Variant in objective_ids.keys():
		if not _visit_objective(StringName(objective_id), objective_ids, visiting, visited):
			return false
	return true


func _visit_objective(
	objective_id: StringName,
	objective_ids: Dictionary,
	visiting: Dictionary,
	visited: Dictionary
) -> bool:
	if visited.has(objective_id):
		return true
	if visiting.has(objective_id):
		return false
	var objective: MissionObjectiveDefinition = objective_ids.get(objective_id) as MissionObjectiveDefinition
	if objective == null:
		return true
	visiting[objective_id] = true
	for prerequisite_id: StringName in objective.prerequisite_ids:
		if objective_ids.has(prerequisite_id) and not _visit_objective(prerequisite_id, objective_ids, visiting, visited):
			return false
	visiting.erase(objective_id)
	visited[objective_id] = true
	return true
