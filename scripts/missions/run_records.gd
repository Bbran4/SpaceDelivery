extends RefCounted
class_name RunRecords

## Best distance and gates cleared per mission, so a failed push still counts as progress.

const SAVE_PATH: String = "user://run_records.cfg"


static func get_best_distance(mission_id: StringName) -> float:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0.0
	return float(config.get_value(String(mission_id), "best_distance", 0.0))


static func get_best_gates(mission_id: StringName) -> int:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value(String(mission_id), "best_gates", 0))


## Returns true when this run set a new best distance.
static func record(mission_id: StringName, distance: float, gates_cleared: int) -> bool:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return false
	var section: String = String(mission_id)
	var previous: float = float(config.get_value(section, "best_distance", 0.0))
	var is_best: bool = distance > previous
	if is_best:
		config.set_value(section, "best_distance", distance)
	config.set_value(section, "best_gates", maxi(gates_cleared, int(config.get_value(section, "best_gates", 0))))
	config.save(SAVE_PATH)
	return is_best
