extends Resource
class_name MissionObjectiveDefinition

## Reusable objective rules. Runtime progress belongs to a mission run, not this resource.

enum ObjectiveType {
	DELIVER,
	DESTROY,
	ELIMINATE_GROUP,
	SURVIVE,
	REACH,
	COLLECT,
	RESCUE,
	ESCORT,
	INTERCEPT,
	INVESTIGATE,
	INTERACT,
	ESCAPE,
	DEFEND,
	DISABLE,
	DELIVER_ALL,
	COMPLETE_SEQUENCE,
}

@export var objective_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var objective_type: ObjectiveType = ObjectiveType.DELIVER
@export var required: bool = true
## IDs of objectives that must be completed before this one becomes available.
@export var prerequisite_ids: Array[StringName] = []
## Optional target identifier used by target-driven objective handlers.
@export var target_id: StringName = &""
@export_range(0, 1000000, 1) var required_quantity: int = 1
@export_range(0.0, 100.0, 1.0) var minimum_integrity_percent: float = 0.0
@export_range(0, 86400, 1) var deadline_seconds: int = 0
@export_range(0, 1000000, 1) var bonus_credits: int = 0


func validate_definition() -> PackedStringArray:
	var errors: PackedStringArray = []
	if objective_id == &"":
		errors.append("Objective ID cannot be empty.")
	if title.strip_edges().is_empty():
		errors.append("Objective '%s' needs a title." % objective_id)
	if required_quantity < 1:
		errors.append("Objective '%s' must require at least one unit." % objective_id)
	if minimum_integrity_percent < 0.0 or minimum_integrity_percent > 100.0:
		errors.append("Objective '%s' has an invalid integrity threshold." % objective_id)
	if deadline_seconds < 0:
		errors.append("Objective '%s' has a negative deadline." % objective_id)
	return errors
