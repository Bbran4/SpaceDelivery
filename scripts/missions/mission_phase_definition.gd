extends Resource
class_name MissionPhaseDefinition

## One authored beat in a phase-based delivery contract.
enum PhaseType {
	ASTEROID_BOUNTY,
	PIRATE_AMBUSH,
	DELIVERY,
}

@export var phase_id: StringName = &""
@export var title: String = ""
@export_multiline var briefing: String = ""
@export var phase_type: PhaseType = PhaseType.ASTEROID_BOUNTY
@export_range(1, 3600, 1) var duration_seconds: int = 60
@export_range(1, 50, 1) var target_count: int = 5
@export_range(0, 100000, 1) var bonus_credits: int = 0


func validate_definition() -> PackedStringArray:
	var errors: PackedStringArray = []
	if phase_id == &"":
		errors.append("Mission phase ID cannot be empty.")
	if title.strip_edges().is_empty():
		errors.append("Mission phase '%s' needs a title." % phase_id)
	if duration_seconds < 1:
		errors.append("Mission phase '%s' needs a positive timer." % phase_id)
	if target_count < 1:
		errors.append("Mission phase '%s' needs at least one target." % phase_id)
	return errors
