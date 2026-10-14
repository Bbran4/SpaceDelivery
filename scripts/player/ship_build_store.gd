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
	if clean_name.is_empty() or not build_has_weapon(hull_path, module_paths):
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
	var build: Dictionary = {
		"name": build_name,
		"hull_path": str(config.get_value(section, "hull_path", "")),
		"module_paths": config.get_value(section, "module_paths", PackedStringArray()),
	}
	if not build_has_weapon(str(build.get("hull_path", "")), build.get("module_paths", PackedStringArray())):
		return {}
	return build


static func build_has_weapon(hull_path: String, module_paths: Variant) -> bool:
	var hull: ShipHull = load(hull_path) as ShipHull if not hull_path.is_empty() else null
	if hull == null:
		return false
	for slot_index: int in range(mini(hull.slot_categories.size(), module_paths.size())):
		var module_path: String = str(module_paths[slot_index])
		if module_path.is_empty():
			continue
		var module: ShipModule = load(module_path) as ShipModule
		if module == null or module.category != ShipModule.Category.WEAPON or module.weapon_scene == null:
			continue
		var slot_category: int = hull.slot_categories[slot_index]
		if slot_category == -1 or slot_category == ShipModule.Category.WEAPON:
			return true
	return false


static func get_cargo_capacity(hull_path: String, module_paths: Variant) -> int:
	var hull: ShipHull = load(hull_path) as ShipHull if not hull_path.is_empty() else null
	if hull == null:
		return 0
	var capacity: int = hull.cargo_hold_capacity
	for slot_index: int in range(mini(hull.slot_categories.size(), module_paths.size())):
		var module_path: String = str(module_paths[slot_index])
		if module_path.is_empty():
			continue
		var module: ShipModule = load(module_path) as ShipModule
		if module == null:
			continue
		var slot_category: int = hull.slot_categories[slot_index]
		if slot_category == -1 or slot_category == module.category:
			capacity += module.cargo_capacity_bonus
	return maxi(0, capacity)


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
