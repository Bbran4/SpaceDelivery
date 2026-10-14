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
	var seen_ids: Dictionary = {}
	for mission_path: String in MISSION_PATHS:
		var mission: MissionDefinition = load(mission_path) as MissionDefinition
		if mission == null:
			push_error("Could not load mission definition: " + mission_path)
			continue
		var errors: PackedStringArray = mission.validate_contract()
		if seen_ids.has(mission.mission_id):
			errors.append("Duplicate mission ID '%s' in catalog." % mission.mission_id)
		if not errors.is_empty():
			push_error("Mission '%s' rejected by catalog validation: %s" % [
				mission.mission_id, "; ".join(errors)
			])
			continue
		seen_ids[mission.mission_id] = true
		missions.append(mission)
	return missions
