extends Control
class_name ShipBuilder

const HULL_PATHS: Array[String] = [
	"res://resources/hulls/starter_courier.tres",
	"res://resources/hulls/bulk_freighter.tres",
	"res://resources/hulls/runner_courier.tres",
]
const MODULE_PATHS: Array[String] = [
	"res://resources/modules/basic_laser_module.tres",
	"res://resources/modules/rapid_laser_module.tres",
	"res://resources/modules/heavy_cannon_module.tres",
	"res://resources/modules/long_range_lance_module.tres",
	"res://resources/modules/shield_generator_module.tres",
	"res://resources/modules/ion_thruster_module.tres",
	"res://resources/modules/cargo_expansion_module.tres",
	"res://resources/modules/salvage_rack_module.tres",
	"res://resources/modules/navigation_computer_module.tres",
]
const CATEGORY_ORDER: Array[int] = [
	ShipModule.Category.WEAPON,
	ShipModule.Category.DEFENSE,
	ShipModule.Category.ENGINE,
	ShipModule.Category.CARGO,
	ShipModule.Category.UTILITY,
]
const NARROW_WIDTH: float = 820.0

signal builder_closed

@onready var body: BoxContainer = %Body
@onready var hull_picker: OptionButton = %HullPicker
@onready var preview_ship: Polygon2D = %PreviewShip
@onready var preview_canvas: Control = %PreviewCanvas
@onready var hull_description: Label = %HullDescription
@onready var stats_label: Label = %StatsLabel
@onready var slot_groups: VBoxContainer = %SlotGroups
@onready var module_groups: VBoxContainer = %ModuleGroups
@onready var build_name_input: LineEdit = %BuildNameInput
@onready var saved_build_picker: OptionButton = %SavedBuildPicker
@onready var status_label: Label = %StatusLabel
@onready var module_title: Label = $Margin/Layout/BodyScroll/Body/ModulesPanel/ModulesVBox/ModulesTitle
@onready var module_hint: Label = $Margin/Layout/BodyScroll/Body/ModulesPanel/ModulesVBox/ModulesHint
@onready var module_scroll: ScrollContainer = %ModuleScroll
@onready var close_button: Button = %CloseButton

var selected_slot_index: int = -1

var selected_hull: ShipHull
var selected_modules: Array[ShipModule] = []
var selected_module_paths: Array[String] = []


func _ready() -> void:
	resized.connect(_update_layout)
	preview_canvas.resized.connect(_center_ship_preview)
	_update_layout()
	module_title.visible = false
	module_hint.visible = false
	module_scroll.visible = false
	close_button.pressed.connect(_on_back_pressed)
	_center_ship_preview()
	_populate_hulls()
	_refresh_saved_builds()
	if hull_picker.item_count > 0:
		_on_hull_selected(0)


func _update_layout() -> void:
	# Three columns on wide windows, stacked panels (scrollable) on narrow ones.
	body.vertical = size.x < NARROW_WIDTH


func _populate_hulls() -> void:
	hull_picker.clear()
	for path: String in HULL_PATHS:
		var hull: ShipHull = load(path) as ShipHull
		if hull == null:
			continue
		hull_picker.add_item("%s · %s" % [hull.display_name, _rarity_name(hull.rarity)])
		hull_picker.set_item_metadata(hull_picker.item_count - 1, path)
	hull_picker.item_selected.connect(_on_hull_selected)


func _on_hull_selected(index: int) -> void:
	if index < 0 or index >= hull_picker.item_count:
		return
	selected_hull = load(str(hull_picker.get_item_metadata(index))) as ShipHull
	if selected_hull == null:
		return
	selected_modules.clear()
	selected_module_paths.clear()
	selected_modules.resize(selected_hull.slot_categories.size())
	selected_module_paths.resize(selected_hull.slot_categories.size())
	for slot_index: int in range(selected_module_paths.size()):
		selected_module_paths[slot_index] = ""
	_update_hull_preview()
	selected_slot_index = -1
	module_title.visible = false
	module_hint.visible = false
	module_scroll.visible = false
	_rebuild_slot_groups()
	_rebuild_module_groups()
	_refresh_stats()


func show_builder() -> void:
	visible = true
	if selected_hull == null and hull_picker.item_count > 0:
		_on_hull_selected(hull_picker.selected if hull_picker.selected >= 0 else 0)


func _center_ship_preview() -> void:
	if not is_instance_valid(preview_canvas) or not is_instance_valid(preview_ship):
		return
	preview_ship.position = preview_canvas.size / 2.0
	var bounds: Rect2 = Rect2()
	for i: int in range(preview_ship.polygon.size()):
		var point: Vector2 = preview_ship.polygon[i]
		bounds = Rect2(point, Vector2.ZERO) if i == 0 else bounds.expand(point)
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		var fit: float = minf(
			preview_canvas.size.x * 0.7 / bounds.size.x,
			preview_canvas.size.y * 0.7 / bounds.size.y
		)
		preview_ship.scale = Vector2.ONE * clampf(fit, 0.4, 3.0)


func _update_hull_preview() -> void:
	if selected_hull == null:
		return
	preview_ship.color = selected_hull.preview_color
	preview_ship.polygon = selected_hull.preview_polygon
	_center_ship_preview()
	hull_description.text = "%s\nRarity: %s" % [
		selected_hull.description,
		_rarity_name(selected_hull.rarity),
	]


func _rebuild_slot_groups() -> void:
	_clear_container(slot_groups)
	if selected_hull == null:
		return
	var category_groups: Dictionary = {}
	for slot_index: int in range(selected_hull.slot_categories.size()):
		var category: int = selected_hull.slot_categories[slot_index]
		if not category_groups.has(category):
			category_groups[category] = []
		category_groups[category].append(slot_index)
	var categories: Array = category_groups.keys()
	categories.sort()
	for category_value: Variant in categories:
		var category: int = int(category_value)
		var group: VBoxContainer = VBoxContainer.new()
		group.add_theme_constant_override("separation", 6)
		var heading: Label = Label.new()
		heading.text = "%s SLOTS" % _category_name(category).to_upper()
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", Color(0.55, 0.78, 0.94))
		group.add_child(heading)
		for slot_index_value: Variant in category_groups[category]:
			var slot_index: int = int(slot_index_value)
			var slot: ShipSlotDropTarget = ShipSlotDropTarget.new()
			slot.custom_minimum_size = Vector2(0, 56)
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.slot_index = slot_index
			slot.accepted_category = category
			slot.builder = self
			slot.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.16, 0.23), Color(0.24, 0.38, 0.49)))
			var inner: VBoxContainer = VBoxContainer.new()
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_theme_constant_override("separation", 2)
			var slot_label: Label = Label.new()
			slot_label.text = "SLOT %02d" % (slot_index + 1)
			slot_label.add_theme_font_size_override("font_size", 10)
			slot_label.add_theme_color_override("font_color", Color(0.58, 0.69, 0.79))
			slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var module_label: Label = Label.new()
			module_label.text = "Empty slot · drop module here"
			module_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			module_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(slot_label)
			inner.add_child(module_label)
			slot.add_child(inner)
			slot.slot_title = slot_label
			slot.module_title = module_label
			slot.set_slot_content("SLOT %02d" % (slot_index + 1), selected_modules[slot_index], selected_module_paths[slot_index])
			group.add_child(slot)
		slot_groups.add_child(group)


func _rebuild_module_groups() -> void:
	_clear_container(module_groups)
	for category: int in CATEGORY_ORDER:
		if selected_slot_index < 0 or selected_slot_index >= selected_hull.slot_categories.size():
			continue
		var selected_category: int = selected_hull.slot_categories[selected_slot_index]
		if not _category_fits(selected_category, category):
			continue
		var matching_paths: Array[String] = []
		for module_path: String in MODULE_PATHS:
			var module: ShipModule = load(module_path) as ShipModule
			if module != null and module.category == category:
				matching_paths.append(module_path)
		if matching_paths.is_empty():
			continue
		var group: VBoxContainer = VBoxContainer.new()
		group.add_theme_constant_override("separation", 6)
		var heading: Label = Label.new()
		heading.text = _category_name(category).to_upper()
		heading.add_theme_font_size_override("font_size", 13)
		heading.add_theme_color_override("font_color", Color(0.55, 0.78, 0.94))
		group.add_child(heading)
		for module_path: String in matching_paths:
			var module: ShipModule = load(module_path) as ShipModule
			if module == null:
				continue
			var card: ModuleDragCard = ModuleDragCard.new()
			card.custom_minimum_size = Vector2(0, 58)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.module_path = module_path
			card.module_data = module
			card.builder = self
			card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.16, 0.23), Color(0.27, 0.43, 0.56)))
			var details: VBoxContainer = VBoxContainer.new()
			details.mouse_filter = Control.MOUSE_FILTER_IGNORE
			details.add_theme_constant_override("separation", 2)
			var name_label: Label = Label.new()
			name_label.text = module.display_name
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rarity_label: Label = Label.new()
			rarity_label.text = "%s · DRAG TO EQUIP" % _rarity_name(module.rarity).to_upper()
			rarity_label.add_theme_font_size_override("font_size", 9)
			rarity_label.add_theme_color_override("font_color", Color(0.58, 0.72, 0.83))
			rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			details.add_child(name_label)
			details.add_child(rarity_label)
			card.add_child(details)
			group.add_child(card)
		module_groups.add_child(group)


func open_module_picker(slot_index: int) -> void:
	if selected_hull == null or slot_index < 0 or slot_index >= selected_hull.slot_categories.size():
		return
	selected_slot_index = slot_index
	module_title.visible = true
	module_hint.visible = true
	module_scroll.visible = true
	_rebuild_module_groups()
	status_label.text = "Choose a compatible module for slot %d." % (slot_index + 1)


func equip_module(slot_index: int, module_path: String) -> void:
	if selected_hull == null or slot_index < 0 or slot_index >= selected_modules.size():
		return
	var module: ShipModule = load(module_path) as ShipModule if not module_path.is_empty() else null
	if module != null and not _category_fits(selected_hull.slot_categories[slot_index], module.category):
		status_label.text = "That module does not fit this slot."
		return
	selected_module_paths[slot_index] = module_path
	selected_modules[slot_index] = module
	_rebuild_slot_groups()
	_refresh_stats()
	module_title.visible = false
	module_hint.visible = false
	module_scroll.visible = false
	selected_slot_index = -1
	_rebuild_module_groups()
	status_label.text = "Equipped %s in slot %d." % [module.display_name, slot_index + 1] if module != null else "Slot %d cleared." % (slot_index + 1)


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
	stats_label.text = "HULL      %d\nSHIELDS   %d\nSPEED     %d\nACCEL.    %d\nCARGO     %d\nSALVAGE   %d\nSLOTS     %d" % [
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
		status_label.text = "Enter a name before saving."
		return
	var hull_path: String = str(hull_picker.get_item_metadata(hull_picker.selected))
	var save_error: Error = ShipBuildStore.save_build(build_name, hull_path, selected_module_paths, true)
	if save_error != OK:
		status_label.text = "Could not save build (error %d)." % save_error
		return
	status_label.text = "Saved '%s' · now active." % build_name
	_refresh_saved_builds()


func _on_load_pressed() -> void:
	if saved_build_picker.item_count == 0 or saved_build_picker.selected < 0:
		status_label.text = "Choose a saved build first."
		return
	var build_name: String = str(saved_build_picker.get_item_metadata(saved_build_picker.selected))
	var build: Dictionary = ShipBuildStore.load_build(build_name)
	if build.is_empty():
		status_label.text = "Saved build could not be found."
		return
	var hull_path: String = str(build.get("hull_path", ""))
	var loaded_hull: ShipHull = load(hull_path) as ShipHull
	var hull_index: int = _find_hull_index(hull_path)
	if loaded_hull == null or hull_index < 0:
		status_label.text = "The saved hull resource is missing."
		return
	selected_hull = loaded_hull
	hull_picker.select(hull_index)
	selected_modules.clear()
	selected_module_paths.clear()
	selected_modules.resize(selected_hull.slot_categories.size())
	selected_module_paths.resize(selected_hull.slot_categories.size())
	var module_paths: Variant = build.get("module_paths", PackedStringArray())
	for slot_index: int in range(selected_module_paths.size()):
		var module_path: String = str(module_paths[slot_index]) if slot_index < module_paths.size() else ""
		var module: ShipModule = load(module_path) as ShipModule if not module_path.is_empty() else null
		if module != null and not _category_fits(selected_hull.slot_categories[slot_index], module.category):
			module = null
			module_path = ""
		selected_modules[slot_index] = module
		selected_module_paths[slot_index] = module_path
	_update_hull_preview()
	_rebuild_slot_groups()
	_rebuild_module_groups()
	_refresh_stats()
	build_name_input.text = build_name
	status_label.text = "Loaded '%s' · now active." % build_name
	ShipBuildStore.save_build(build_name, hull_path, selected_module_paths, true)


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
			return "Weapons"
		ShipModule.Category.DEFENSE:
			return "Defense"
		ShipModule.Category.ENGINE:
			return "Engines"
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


func _make_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_back_pressed() -> void:
	visible = false
	modules_panel.visible = false
	selected_slot_index = -1
	builder_closed.emit()
