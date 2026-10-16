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


## Returns a relative power score where the starter courier and basic laser equal 100.
## Hull durability, shields, mobility, cargo capacity, slots, equipped module roles and
## stat modifiers all contribute, so changing the build updates mission threat estimates.
static func calculate_build_power(hull: ShipHull, modules: Array[ShipModule]) -> int:
	if hull == null:
		return 0
	var baseline_hull: ShipHull = load("res://resources/hulls/starter_courier.tres") as ShipHull
	var baseline_module: ShipModule = load("res://resources/modules/basic_laser_module.tres") as ShipModule
	var baseline_modules: Array[ShipModule] = []
	if baseline_module != null:
		baseline_modules.append(baseline_module)
	var baseline_score: float = _raw_build_power(baseline_hull, baseline_modules)
	if baseline_score <= 0.0:
		return 100
	return maxi(1, roundi(_raw_build_power(hull, modules) / baseline_score * 100.0))


static func _raw_build_power(hull: ShipHull, modules: Array[ShipModule]) -> float:
	if hull == null:
		return 0.0
	var score: float = hull.max_hull * 0.45
	score += hull.max_shield * 0.35
	score += hull.shield_recharge_rate * 2.0
	score += hull.movement_speed * 0.12
	score += hull.acceleration * 0.015
	score += float(hull.cargo_hold_capacity) * 0.8
	score += float(hull.slot_categories.size()) * 5.0
	for module: ShipModule in modules:
		if module == null:
			continue
		match module.category:
			ShipModule.Category.WEAPON:
				score += _weapon_power_score(module)
			ShipModule.Category.DEFENSE:
				score += 12.0
			ShipModule.Category.ENGINE:
				score += 10.0
			ShipModule.Category.CARGO:
				score += 8.0
			ShipModule.Category.UTILITY:
				score += 7.0
		score += float(module.cargo_capacity_bonus) * 0.8
		score += float(module.salvage_capacity_bonus) * 0.35
		for stat_name: Variant in module.stat_modifiers.keys():
			var value: float = float(module.stat_modifiers[stat_name])
			match str(stat_name):
				"max_hull":
					score += value * 0.45
				"max_shield":
					score += value * 0.35
				"shield_recharge_rate":
					score += value * 2.0
				"movement_speed":
					score += value * 0.12
				"acceleration":
					score += value * 0.015
				"damage":
					score += value * 2.5
				"attack_speed":
					score += value * 8.0
	return maxf(1.0, score)


## Weapon strength uses the same WeaponData that combat uses, so damage, cadence,
## range and area impact all influence the rating. Basic Laser is worth 25 score points.
static func _weapon_power_score(module: ShipModule) -> float:
	if module == null or module.weapon_scene == null:
		return 0.0
	var weapon_node: Node = module.weapon_scene.instantiate()
	if weapon_node == null:
		return 0.0
	var weapon_data: WeaponData = weapon_node.get("weapon_data") as WeaponData
	weapon_node.free()
	if weapon_data == null:
		return 0.0
	var baseline_scene: PackedScene = load("res://scenes/weapons/basic_weapon.tscn") as PackedScene
	if baseline_scene == null:
		return 25.0
	var baseline_node: Node = baseline_scene.instantiate()
	if baseline_node == null:
		return 25.0
	var baseline_data: WeaponData = baseline_node.get("weapon_data") as WeaponData
	baseline_node.free()
	if baseline_data == null:
		return 25.0
	var weapon_dps: float = weapon_data.projectile_damage * weapon_data.fire_rate
	var baseline_dps: float = baseline_data.projectile_damage * baseline_data.fire_rate
	if baseline_dps <= 0.0:
		return 25.0
	var dps_factor: float = pow(maxf(0.1, weapon_dps / baseline_dps), 0.65)
	var range_factor: float = pow(maxf(0.1, weapon_data.range / maxf(1.0, baseline_data.range)), 0.15)
	var splash_factor: float = 1.0 + minf(0.35, weapon_data.impact_radius / 125.0)
	return 25.0 * dps_factor * range_factor * splash_factor


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
