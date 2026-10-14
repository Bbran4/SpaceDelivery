extends RefCounted
class_name MissionCatalog

## Single source of truth for contracts offered by the game.
const MISSION_PATHS: Array[String] = [
	"res://resources/missions/priority_medical_shipment.tres",
	"res://resources/missions/fragile_relay_components.tres",
]

static func get_mission_paths() -> Array[String]:
	return MISSION_PATHS.duplicate()

static func load_available_missions() -> Array[MissionDefinition]:
	var missions: Array[MissionDefinition] = []
	for mission_path: String in MISSION_PATHS:
		var mission: MissionDefinition = load(mission_path) as MissionDefinition
		if mission == null:
			push_error("Could not load mission definition: " + mission_path)
			continue
		var errors: PackedStringArray = mission.validate_generator_settings()
		if not errors.is_empty():
			push_error("Mission '%s' has invalid route-generation settings: %s" % [mission.mission_id, "; ".join(errors)])
		missions.append(mission)
	return missions
