extends RefCounted
class_name ShipBuildStore

const SAVE_PATH: String = "user://ship_builds.cfg"


static func get_build_names() -> PackedStringArray:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return PackedStringArray()
	var names: PackedStringArray = config.get_value("builds", "names", PackedStringArray())
	names.sort()
	return names


static func save_build(
	build_name: String,
	hull_path: String,
	module_paths: Array[String],
	make_active: bool = true
) -> Error:
	var clean_name: String = build_name.strip_edges()
	if clean_name.is_empty():
		return ERR_INVALID_PARAMETER
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	var names: PackedStringArray = config.get_value("builds", "names", PackedStringArray())
	if not names.has(clean_name):
		names.append(clean_name)
	config.set_value("builds", "names", names)
	var section: String = _section_for_name(clean_name)
	config.set_value(section, "hull_path", hull_path)
	config.set_value(section, "module_paths", module_paths)
	if make_active:
		config.set_value("active", "name", clean_name)
	return config.save(SAVE_PATH)


static func load_build(build_name: String) -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	var section: String = _section_for_name(build_name)
	if not config.has_section(section):
		return {}
	return {
		"name": build_name,
		"hull_path": str(config.get_value(section, "hull_path", "")),
		"module_paths": config.get_value(section, "module_paths", PackedStringArray()),
	}


static func get_active_build() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {}
	var active_name: String = str(config.get_value("active", "name", ""))
	if active_name.is_empty():
		return {}
	return load_build(active_name)


static func _section_for_name(build_name: String) -> String:
	var safe_name: String = build_name.strip_edges().to_lower().replace(" ", "_")
	return "build_" + safe_name
