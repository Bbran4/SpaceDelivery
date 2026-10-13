extends Control
class_name ShipBuilder

const HULL_PATHS: Array[String] = [
	"res://resources/hulls/starter_courier.tres",
	"res://resources/hulls/bulk_freighter.tres",
	"res://resources/hulls/runner_courier.tres",
]
const MODULE_PATHS: Array[String] = [
	"res://resources/modules/basic_laser_module.tres",
	"res://resources/modules/shield_generator_module.tres",
	"res://resources/modules/ion_thruster_module.tres",
	"res://resources/modules/cargo_expansion_module.tres",
	"res://resources/modules/salvage_rack_module.tres",
	"res://resources/modules/navigation_computer_module.tres",
]

@onready var hull_picker: OptionButton = %HullPicker
@onready var preview_ship: Polygon2D = %PreviewShip
@onready var hull_description: Label = %HullDescription
@onready var stats_label: Label = %StatsLabel
@onready var slot_list: VBoxContainer = %SlotList
@onready var build_name_input: LineEdit = %BuildNameInput
@onready var saved_build_picker: OptionButton = %SavedBuildPicker
@onready var status_label: Label = %StatusLabel

var selected_hull: ShipHull
var selected_modules: Array[ShipModule] = []
var selected_module_paths: Array[String] = []


func _ready() -> void:
	_populate_hulls()
	_refresh_saved_builds()
	if hull_picker.item_count > 0:
		_on_hull_selected(0)


func _populate_hulls() -> void:
	hull_picker.clear()
	for path: String in HULL_PATHS:
		var hull: ShipHull = load(path) as ShipHull
		if hull == null:
			continue
		hull_picker.add_item("%s  [%s]" % [hull.display_name, _rarity_name(hull.rarity)])
		hull_picker.set_item_metadata(hull_picker.item_count - 1, path)
	hull_picker.item_selected.connect(_on_hull_selected)


func _on_hull_selected(index: int) -> void:
	if index < 0 or index >= hull_picker.item_count:
		return
	var path: String = str(hull_picker.get_item_metadata(index))
	selected_hull = load(path) as ShipHull
	if selected_hull == null:
		return
	selected_modules.clear()
	selected_module_paths.clear()
	selected_modules.resize(selected_hull.slot_categories.size())
	selected_module_paths.resize(selected_hull.slot_categories.size())
	for slot_index: int in range(selected_module_paths.size()):
		selected_module_paths[slot_index] = ""
	preview_ship.color = selected_hull.preview_color
	preview_ship.polygon = selected_hull.preview_polygon
	hull_description.text = "%s\n%s" % [selected_hull.description, "Rarity: " + _rarity_name(selected_hull.rarity)]
	_rebuild_slot_list()
	_refresh_stats()


func _rebuild_slot_list() -> void:
	for child: Node in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()
	if selected_hull == null:
		return
	for slot_index: int in range(selected_hull.slot_categories.size()):
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_label: Label = Label.new()
		slot_label.custom_minimum_size.x = 118.0
		slot_label.text = "Slot %d · %s" % [slot_index + 1, _category_name(selected_hull.slot_categories[slot_index])]
		row.add_child(slot_label)
		var picker: OptionButton = OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_item("Empty")
		picker.set_item_metadata(0, "")
		for module_path: String in MODULE_PATHS:
			var module: ShipModule = load(module_path) as ShipModule
			if module == null or not _category_fits(selected_hull.slot_categories[slot_index], module.category):
				continue
			picker.add_item("%s  [%s]" % [module.display_name, _rarity_name(module.rarity)])
			picker.set_item_metadata(picker.item_count - 1, module_path)
		picker.item_selected.connect(_on_module_selected.bind(slot_index, picker))
		row.add_child(picker)
		slot_list.add_child(row)


func _on_module_selected(option_index: int, slot_index: int, picker: OptionButton) -> void:
	if selected_hull == null or slot_index < 0 or slot_index >= selected_modules.size():
		return
	var path: String = str(picker.get_item_metadata(option_index))
	selected_module_paths[slot_index] = path
	selected_modules[slot_index] = load(path) as ShipModule if not path.is_empty() else null
	_refresh_stats()


func _refresh_stats() -> void:
	if selected_hull == null:
		return
	var stats: Dictionary = {
		"max_hull": selected_hull.max_hull,
		"max_shield": selected_hull.max_shield,
		"movement_speed": selected_hull.movement_speed,
		"acceleration": selected_hull.acceleration,
	}
	var cargo_capacity: int = selected_hull.cargo_hold_capacity
	var salvage_capacity: int = selected_hull.salvage_hold_capacity
	for module: ShipModule in selected_modules:
		if module == null:
			continue
		for key: Variant in module.stat_modifiers.keys():
			var stat_name: String = str(key)
			if stats.has(stat_name):
				stats[stat_name] = float(stats[stat_name]) + float(module.stat_modifiers[key])
		cargo_capacity += module.cargo_capacity_bonus
		salvage_capacity += module.salvage_capacity_bonus
	stats_label.text = "HULL       %d\nSHIELDS    %d\nSPEED      %d\nACCEL.     %d\nCARGO      %d units\nSALVAGE    %d units\nMODULES    %d slots" % [
		int(stats["max_hull"]),
		int(stats["max_shield"]),
		int(stats["movement_speed"]),
		int(stats["acceleration"]),
		cargo_capacity,
		salvage_capacity,
		selected_hull.slot_categories.size(),
	]


func _on_save_pressed() -> void:
	if selected_hull == null:
		return
	var build_name: String = build_name_input.text.strip_edges()
	if build_name.is_empty():
		status_label.text = "Enter a name for this build first."
		return
	var hull_path: String = str(hull_picker.get_item_metadata(hull_picker.selected))
	var save_error: Error = ShipBuildStore.save_build(build_name, hull_path, selected_module_paths, true)
	if save_error != OK:
		status_label.text = "Could not save build (error %d)." % save_error
		return
	status_label.text = "Saved '%s' and set it as the active ship." % build_name
	_refresh_saved_builds()


func _on_load_pressed() -> void:
	if saved_build_picker.selected < 0 or saved_build_picker.item_count == 0:
		status_label.text = "Choose a saved build to load."
		return
	var build_name: String = str(saved_build_picker.get_item_metadata(saved_build_picker.selected))
	var build: Dictionary = ShipBuildStore.load_build(build_name)
	if build.is_empty():
		status_label.text = "That saved build could not be found."
		return
	var hull_path: String = str(build.get("hull_path", ""))
	var loaded_hull: ShipHull = load(hull_path) as ShipHull
	if loaded_hull == null:
		status_label.text = "The saved hull resource is missing."
		return
	var module_paths: Variant = build.get("module_paths", PackedStringArray())
	var hull_index: int = _find_hull_index(hull_path)
	if hull_index >= 0:
		hull_picker.select(hull_index)
		selected_hull = loaded_hull
		selected_modules.clear()
		selected_module_paths.clear()
		selected_modules.resize(loaded_hull.slot_categories.size())
		selected_module_paths.resize(loaded_hull.slot_categories.size())
		for slot_index: int in range(selected_module_paths.size()):
			var module_path: String = str(module_paths[slot_index]) if slot_index < module_paths.size() else ""
			selected_module_paths[slot_index] = module_path
			selected_modules[slot_index] = load(module_path) as ShipModule if not module_path.is_empty() else null
		preview_ship.color = selected_hull.preview_color
		preview_ship.polygon = selected_hull.preview_polygon
		hull_description.text = "%s\n%s" % [selected_hull.description, "Rarity: " + _rarity_name(selected_hull.rarity)]
		_rebuild_slot_list()
		_sync_slot_pickers()
		_refresh_stats()
		ShipBuildStore.save_build(build_name, hull_path, selected_module_paths, true)
		build_name_input.text = build_name
		status_label.text = "Loaded '%s'. It is now the active build." % build_name


func _sync_slot_pickers() -> void:
	for slot_index: int in range(slot_list.get_child_count()):
		var row: HBoxContainer = slot_list.get_child(slot_index) as HBoxContainer
		if row == null:
			continue
		var picker: OptionButton = row.get_child(1) as OptionButton
		if picker == null:
			continue
		var selected_path: String = selected_module_paths[slot_index]
		for option_index: int in range(picker.item_count):
			if str(picker.get_item_metadata(option_index)) == selected_path:
				picker.select(option_index)
				break


func _refresh_saved_builds() -> void:
	saved_build_picker.clear()
	for build_name: String in ShipBuildStore.get_build_names():
		saved_build_picker.add_item(build_name)
		saved_build_picker.set_item_metadata(saved_build_picker.item_count - 1, build_name)


func _find_hull_index(path: String) -> int:
	for index: int in range(hull_picker.item_count):
		if str(hull_picker.get_item_metadata(index)) == path:
			return index
	return -1


func _category_fits(slot_category: int, module_category: int) -> bool:
	return slot_category == -1 or slot_category == module_category


func _category_name(category: int) -> String:
	match category:
		ShipModule.Category.WEAPON:
			return "Weapon"
		ShipModule.Category.DEFENSE:
			return "Defense"
		ShipModule.Category.ENGINE:
			return "Engine"
		ShipModule.Category.CARGO:
			return "Cargo"
		ShipModule.Category.UTILITY:
			return "Utility"
		_:
			return "Universal"


func _rarity_name(rarity: int) -> String:
	match rarity:
		0:
			return "Common"
		1:
			return "Uncommon"
		2:
			return "Rare"
		3:
			return "Epic"
		4:
			return "Legendary"
		_:
			return "Unknown"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/hud_test.tscn")
