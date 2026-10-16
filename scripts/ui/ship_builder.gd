extends Control
class_name ShipBuilder

## Ship builder console.
##
## Top half: a red warning when no weapon is fitted, the ship (arrows cycle hulls) and the
## hull name. While a slot is being filled, the top half shows the modules that fit it.
## Bottom half: the module slots in two rows.
##   Top row:    weapons and shields (and any universal slot)
##   Bottom row: engines, cargo and utility
## Click a slot to open the picker, then drag a module card onto a slot. Right-click a slot
## to clear it. confirm_build() saves the build; HQ owns the Test Flight button.

signal builder_closed
signal build_changed
## Emitted whenever the editor's hull or modules change (confirmed or not).
signal selection_changed

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
const STARTER_HULL_PATH: String = "res://resources/hulls/starter_courier.tres"
const STARTER_WEAPON_PATH: String = "res://resources/modules/basic_laser_module.tres"
const ACTIVE_BUILD_NAME: String = "Active Build"

const COLOR_TITLE: Color = Color(0.45, 0.9, 1.0)
const COLOR_MUTED: Color = Color(0.58, 0.72, 0.83)
const COLOR_OK: Color = Color(0.48, 0.83, 0.7)
const COLOR_WARN: Color = Color(1.0, 0.78, 0.35)
const COLOR_ERROR: Color = Color(1.0, 0.34, 0.34)

## Slot categories placed in the top module row. Everything else goes in the bottom row.
const TOP_ROW_CATEGORIES: Array = [ShipModule.Category.WEAPON, ShipModule.Category.DEFENSE, -1]
const SLOT_SIZE: Vector2 = Vector2(158.0, 84.0)

## When true the builder is a permanent part of the HQ screen: it cannot be
## closed, so the Close button is hidden.
@export var embedded: bool = false

var selected_slot_index: int = -1
var selected_hull: ShipHull
var selected_hull_index: int = 0
var selected_modules: Array[ShipModule] = []
var selected_module_paths: Array[String] = []

var _hulls: Array[ShipHull] = []
var _hull_paths: Array[String] = []
var _has_unconfirmed_changes: bool = false

var _ship_view: Control
var _picker_view: Control
var _preview_canvas: Control
var _preview_ship: Polygon2D
var _no_weapon_banner: Label
var _hull_name_label: Label
var _left_arrow: Button
var _right_arrow: Button
var _picker_title: Label
var _picker_cards: HFlowContainer
var _top_row: HBoxContainer
var _bottom_row: HBoxContainer
var _status_label: Label


func _ready() -> void:
	_load_hulls()
	_build_ui()
	_load_active_build_into_editor()
	_show_ship_view()


# ---------------------------------------------------------------- public API

func has_active_weapon() -> bool:
	for module: ShipModule in selected_modules:
		if module != null and module.category == ShipModule.Category.WEAPON and module.weapon_scene != null:
			return true
	return false


func has_unconfirmed_changes() -> bool:
	return _has_unconfirmed_changes


## Cargo capacity of the build currently shown in the editor (confirmed or not).
func get_cargo_capacity() -> int:
	if selected_hull == null:
		return 0
	var capacity: int = selected_hull.cargo_hold_capacity
	for module: ShipModule in selected_modules:
		if module != null:
			capacity += module.cargo_capacity_bonus
	return maxi(0, capacity)


func show_builder() -> void:
	visible = true


## Saves the current editor state as the active build.
func confirm_build() -> bool:
	if selected_hull == null:
		return false
	if not has_active_weapon():
		_set_status("Cannot confirm: install a weapon first.", COLOR_ERROR)
		return false
	var save_error: Error = ShipBuildStore.save_build(
		ACTIVE_BUILD_NAME, _hull_paths[selected_hull_index], selected_module_paths, true
	)
	if save_error != OK:
		_set_status("Could not save build (error %d)." % save_error, COLOR_ERROR)
		return false
	_has_unconfirmed_changes = false
	_set_status("Build confirmed. %s is now active." % selected_hull.display_name, COLOR_OK)
	build_changed.emit()
	return true


## Opens the module picker for a slot, replacing the ship display.
func open_module_picker(slot_index: int) -> void:
	if selected_hull == null or slot_index < 0 or slot_index >= selected_hull.slot_categories.size():
		return
	selected_slot_index = slot_index
	var category: int = selected_hull.slot_categories[slot_index]
	_picker_title.text = "%s MODULES" % _category_label(category)
	_rebuild_picker_cards(category)
	_ship_view.visible = false
	_picker_view.visible = true
	_refresh_slot_styles()
	_set_status("Drag a module onto a compatible slot.", COLOR_MUTED)


## Closes the picker and shows the ship again.
func close_module_picker() -> void:
	selected_slot_index = -1
	_show_ship_view()
	_refresh_slot_styles()


## Equips (or, with an empty path, clears) a slot, then returns to the ship display.
func equip_module(slot_index: int, module_path: String) -> void:
	if selected_hull == null or slot_index < 0 or slot_index >= selected_modules.size():
		return
	var module: ShipModule = load(module_path) as ShipModule if not module_path.is_empty() else null
	if module != null and not _category_fits(selected_hull.slot_categories[slot_index], module.category):
		_set_status("That module does not fit this slot.", COLOR_ERROR)
		return
	_set_slot_module(slot_index, module_path)
	_mark_changed()
	close_module_picker()
	_refresh_all()
	var slot_name: String = _category_label(selected_hull.slot_categories[slot_index]).to_lower()
	if module != null:
		_set_status("Equipped %s in the %s slot. Confirm Build to apply." % [module.display_name, slot_name], COLOR_WARN)
	else:
		_set_status("Cleared the %s slot. Confirm Build to apply." % slot_name, COLOR_WARN)


# ------------------------------------------------------------------ building

func _load_hulls() -> void:
	for path: String in HULL_PATHS:
		var hull: ShipHull = load(path) as ShipHull
		if hull == null:
			push_warning("ShipBuilder could not load hull: " + path)
			continue
		_hulls.append(hull)
		_hull_paths.append(path)


func _build_ui() -> void:
	if not embedded:
		var background: ColorRect = ColorRect.new()
		background.color = Color(0.025, 0.04, 0.065, 1.0)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edge: int = 0 if embedded else 16
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, edge)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	if not embedded:
		var header: HBoxContainer = HBoxContainer.new()
		var title: Label = Label.new()
		title.text = "SHIP BUILDER"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", COLOR_TITLE)
		header.add_child(title)
		var close_button: Button = Button.new()
		close_button.text = "CLOSE"
		close_button.pressed.connect(_on_back_pressed)
		header.add_child(close_button)
		column.add_child(header)

	# Equal stretch ratios split the console into a top half and a bottom half.
	column.add_child(_build_stage())
	column.add_child(_build_module_grid())

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.custom_minimum_size = Vector2(0, 22)
	_status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_status_label)


func _build_stage() -> PanelContainer:
	var stage: PanelContainer = PanelContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 1.0
	stage.custom_minimum_size = Vector2(0, 200)
	stage.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.07, 0.11), Color(0.2, 0.5, 0.62), 2))
	# Both views fill the stage; only one is visible at a time.
	_ship_view = _build_ship_view()
	_picker_view = _build_picker_view()
	stage.add_child(_ship_view)
	stage.add_child(_picker_view)
	return stage


func _build_ship_view() -> VBoxContainer:
	var view: VBoxContainer = VBoxContainer.new()
	view.add_theme_constant_override("separation", 4)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	view.add_child(row)

	_left_arrow = _make_arrow_button("decrement", "<", -1)
	row.add_child(_left_arrow)

	_preview_canvas = Control.new()
	_preview_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_canvas.custom_minimum_size = Vector2(0, 110)
	_preview_canvas.clip_contents = true
	# No tooltip on the ship: the canvas ignores the mouse entirely.
	_preview_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_canvas.resized.connect(_center_ship_preview)
	row.add_child(_preview_canvas)

	_preview_ship = Polygon2D.new()
	_preview_canvas.add_child(_preview_ship)

	_no_weapon_banner = Label.new()
	_no_weapon_banner.text = "NO ACTIVE WEAPON ON SHIP"
	_no_weapon_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_weapon_banner.add_theme_font_size_override("font_size", 16)
	_no_weapon_banner.add_theme_color_override("font_color", COLOR_ERROR)
	_no_weapon_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_canvas.add_child(_no_weapon_banner)
	_no_weapon_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_right_arrow = _make_arrow_button("increment", ">", 1)
	row.add_child(_right_arrow)

	_hull_name_label = Label.new()
	_hull_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hull_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hull_name_label.add_theme_font_size_override("font_size", 26)
	_hull_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	view.add_child(_hull_name_label)
	return view


func _build_picker_view() -> VBoxContainer:
	var view: VBoxContainer = VBoxContainer.new()
	view.add_theme_constant_override("separation", 8)
	view.visible = false

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	view.add_child(header)

	_picker_title = Label.new()
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_title.clip_text = true
	_picker_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_picker_title.add_theme_font_size_override("font_size", 17)
	_picker_title.add_theme_color_override("font_color", COLOR_TITLE)
	header.add_child(_picker_title)

	var clear_button: Button = Button.new()
	clear_button.text = "CLEAR SLOT"
	clear_button.pressed.connect(_on_clear_slot_pressed)
	header.add_child(clear_button)

	var cancel_button: Button = Button.new()
	cancel_button.text = "CANCEL"
	cancel_button.pressed.connect(close_module_picker)
	header.add_child(cancel_button)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	view.add_child(scroll)

	_picker_cards = HFlowContainer.new()
	_picker_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_cards.add_theme_constant_override("h_separation", 10)
	_picker_cards.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_picker_cards)
	return view


func _build_module_grid() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.custom_minimum_size = Vector2(0, 200)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.09, 0.14), Color(0.2, 0.36, 0.48), 1))

	var rows: VBoxContainer = VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)

	_top_row = _make_slot_row()
	_bottom_row = _make_slot_row()
	rows.add_child(_top_row)
	rows.add_child(_bottom_row)
	return panel


func _make_slot_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	return row


func _make_arrow_button(icon_name: String, fallback_text: String, step: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(48, 72)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	var icon: Texture2D = get_theme_icon(icon_name, "TabBar")
	if icon != null:
		button.icon = icon
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = fallback_text
	button.tooltip_text = "Previous hull" if step < 0 else "Next hull"
	button.pressed.connect(_cycle_hull.bind(step))
	return button


# ------------------------------------------------------------------- loading

func _load_active_build_into_editor() -> void:
	var build: Dictionary = ShipBuildStore.get_active_build()
	if not build.is_empty():
		var hull_index: int = _hull_paths.find(str(build.get("hull_path", "")))
		if hull_index >= 0:
			_select_hull(hull_index, false)
			var module_paths: Variant = build.get("module_paths", PackedStringArray())
			for slot_index: int in range(selected_modules.size()):
				var module_path: String = str(module_paths[slot_index]) if slot_index < module_paths.size() else ""
				var module: ShipModule = load(module_path) as ShipModule if not module_path.is_empty() else null
				if module != null and _category_fits(selected_hull.slot_categories[slot_index], module.category):
					_set_slot_module(slot_index, module_path)
			_refresh_all()
			_set_status("Active build loaded.", COLOR_OK)
			return

	var starter_index: int = maxi(_hull_paths.find(STARTER_HULL_PATH), 0)
	_select_hull(starter_index, false)
	for slot_index: int in range(selected_modules.size()):
		if _category_fits(selected_hull.slot_categories[slot_index], ShipModule.Category.WEAPON):
			_set_slot_module(slot_index, STARTER_WEAPON_PATH)
			break
	_refresh_all()
	_set_status("Default starter build loaded. Confirm Build to save it.", COLOR_MUTED)


## Switches hull. With keep_modules, modules that still fit their slot index stay.
func _select_hull(index: int, keep_modules: bool) -> void:
	if _hulls.is_empty():
		return
	var previous_paths: Array[String] = selected_module_paths.duplicate()
	selected_hull_index = posmod(index, _hulls.size())
	selected_hull = _hulls[selected_hull_index]
	var slot_count: int = selected_hull.slot_categories.size()
	selected_modules.clear()
	selected_module_paths.clear()
	selected_modules.resize(slot_count)
	selected_module_paths.resize(slot_count)
	for slot_index: int in range(slot_count):
		selected_module_paths[slot_index] = ""
		if not keep_modules or slot_index >= previous_paths.size() or previous_paths[slot_index].is_empty():
			continue
		var module: ShipModule = load(previous_paths[slot_index]) as ShipModule
		if module != null and _category_fits(selected_hull.slot_categories[slot_index], module.category):
			_set_slot_module(slot_index, previous_paths[slot_index])


func _set_slot_module(slot_index: int, module_path: String) -> void:
	selected_module_paths[slot_index] = module_path
	selected_modules[slot_index] = load(module_path) as ShipModule if not module_path.is_empty() else null


func _cycle_hull(step: int) -> void:
	if _hulls.size() < 2:
		return
	selected_slot_index = -1
	_select_hull(selected_hull_index + step, true)
	_mark_changed()
	_show_ship_view()
	_refresh_all()
	_set_status("Hull changed. Confirm Build to apply.", COLOR_WARN)


# ------------------------------------------------------------------ refreshing

func _show_ship_view() -> void:
	if is_instance_valid(_ship_view):
		_ship_view.visible = true
	if is_instance_valid(_picker_view):
		_picker_view.visible = false


func _refresh_all() -> void:
	if selected_hull == null:
		return
	_update_hull_display()
	_rebuild_slots()
	selection_changed.emit()


func _update_hull_display() -> void:
	_preview_ship.color = selected_hull.preview_color
	_preview_ship.polygon = selected_hull.preview_polygon
	_center_ship_preview()
	_hull_name_label.text = selected_hull.display_name.to_upper()
	_left_arrow.disabled = _hulls.size() < 2
	_right_arrow.disabled = _hulls.size() < 2
	_no_weapon_banner.visible = not has_active_weapon()


func _center_ship_preview() -> void:
	if not is_instance_valid(_preview_canvas) or not is_instance_valid(_preview_ship):
		return
	var points: PackedVector2Array = _preview_ship.polygon
	var canvas_size: Vector2 = _preview_canvas.size
	if points.is_empty() or canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	# Keep the top strip clear for the weapon warning.
	var reserved_top: float = 30.0
	var usable: Vector2 = Vector2(canvas_size.x, maxf(canvas_size.y - reserved_top, 1.0))
	var fit: float = minf(usable.x * 0.8 / bounds.size.x, usable.y * 0.85 / bounds.size.y)
	var ship_scale: float = clampf(fit, 0.4, 4.0)
	_preview_ship.scale = Vector2.ONE * ship_scale
	# Centre the polygon's bounds, not its origin, so the ship sits in the middle.
	var centre: Vector2 = Vector2(canvas_size.x * 0.5, reserved_top + usable.y * 0.5)
	_preview_ship.position = centre - bounds.get_center() * ship_scale


func _rebuild_slots() -> void:
	_clear_container(_top_row)
	_clear_container(_bottom_row)
	var top_indices: Array[int] = []
	var bottom_indices: Array[int] = []
	for slot_index: int in range(selected_hull.slot_categories.size()):
		if TOP_ROW_CATEGORIES.has(selected_hull.slot_categories[slot_index]):
			top_indices.append(slot_index)
		else:
			bottom_indices.append(slot_index)
	top_indices.sort_custom(_slot_order)
	bottom_indices.sort_custom(_slot_order)
	for slot_index: int in top_indices:
		_top_row.add_child(_make_slot(slot_index))
	for slot_index: int in bottom_indices:
		_bottom_row.add_child(_make_slot(slot_index))
	_top_row.visible = not top_indices.is_empty()
	_bottom_row.visible = not bottom_indices.is_empty()
	_refresh_slot_styles()


## Orders slots within a row by category (weapons before shields, engines before cargo...).
func _slot_order(a: int, b: int) -> bool:
	var category_a: int = selected_hull.slot_categories[a]
	var category_b: int = selected_hull.slot_categories[b]
	if category_a != category_b:
		return category_a < category_b
	return a < b


func _make_slot(slot_index: int) -> ShipSlotDropTarget:
	var category: int = selected_hull.slot_categories[slot_index]
	var slot: ShipSlotDropTarget = ShipSlotDropTarget.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.slot_index = slot_index
	slot.accepted_category = category
	slot.builder = self

	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 3)
	var slot_label: Label = Label.new()
	slot_label.add_theme_font_size_override("font_size", 12)
	slot_label.add_theme_color_override("font_color", COLOR_MUTED)
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.clip_text = true
	slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var module_label: Label = Label.new()
	module_label.add_theme_font_size_override("font_size", 15)
	module_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	module_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	module_label.clip_text = true
	module_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(slot_label)
	inner.add_child(module_label)
	slot.add_child(inner)
	slot.slot_title = slot_label
	slot.module_title = module_label
	slot.set_slot_content(
		_category_label(category),
		selected_modules[slot_index],
		selected_module_paths[slot_index]
	)
	if selected_modules[slot_index] != null:
		slot.tooltip_text = selected_modules[slot_index].description
	return slot


func _refresh_slot_styles() -> void:
	for row: HBoxContainer in [_top_row, _bottom_row]:
		for child: Node in row.get_children():
			var slot: ShipSlotDropTarget = child as ShipSlotDropTarget
			if slot == null or slot.is_queued_for_deletion():
				continue
			var is_open: bool = slot.slot_index == selected_slot_index
			var filled: bool = slot.slot_index < selected_modules.size() and selected_modules[slot.slot_index] != null
			var background: Color = Color(0.14, 0.22, 0.31) if filled else Color(0.08, 0.13, 0.19)
			var border: Color = Color(0.45, 0.9, 1.0) if is_open else Color(0.24, 0.38, 0.49)
			slot.add_theme_stylebox_override("panel", _make_panel_style(background, border, 2 if is_open else 1, 8.0, 6.0))


func _rebuild_picker_cards(slot_category: int) -> void:
	_clear_container(_picker_cards)
	var shown: int = 0
	for module_path: String in MODULE_PATHS:
		var module: ShipModule = load(module_path) as ShipModule
		if module == null or not _category_fits(slot_category, module.category):
			continue
		var card: ModuleDragCard = ModuleDragCard.new()
		card.custom_minimum_size = Vector2(176, 62)
		card.mouse_default_cursor_shape = Control.CURSOR_DRAG
		card.module_path = module_path
		card.module_data = module
		card.builder = self
		card.tooltip_text = _module_tooltip(module)
		card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.17, 0.25), Color(0.3, 0.5, 0.64), 1, 10.0, 6.0))

		var details: VBoxContainer = VBoxContainer.new()
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_theme_constant_override("separation", 2)
		var name_label: Label = Label.new()
		name_label.text = module.display_name
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag_label: Label = Label.new()
		var equipped: bool = selected_slot_index >= 0 and selected_module_paths[selected_slot_index] == module_path
		tag_label.text = "EQUIPPED" if equipped else "%s  /  DRAG" % _rarity_name(module.rarity).to_upper()
		tag_label.clip_text = true
		tag_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tag_label.add_theme_font_size_override("font_size", 11)
		tag_label.add_theme_color_override("font_color", COLOR_OK if equipped else COLOR_MUTED)
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(name_label)
		details.add_child(tag_label)
		card.add_child(details)
		_picker_cards.add_child(card)
		shown += 1
	if shown == 0:
		var empty: Label = Label.new()
		empty.text = "No modules fit this slot."
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_picker_cards.add_child(empty)


# ------------------------------------------------------------------- helpers

func _mark_changed() -> void:
	_has_unconfirmed_changes = true


func _set_status(text: String, color: Color) -> void:
	if not is_instance_valid(_status_label):
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _on_clear_slot_pressed() -> void:
	if selected_slot_index >= 0:
		equip_module(selected_slot_index, "")


func _on_back_pressed() -> void:
	if embedded:
		return
	close_module_picker()
	visible = false
	builder_closed.emit()


func _category_fits(slot_category: int, module_category: int) -> bool:
	return slot_category == -1 or slot_category == module_category


func _category_label(category: int) -> String:
	match category:
		ShipModule.Category.WEAPON:
			return "WEAPON"
		ShipModule.Category.DEFENSE:
			return "SHIELD"
		ShipModule.Category.ENGINE:
			return "ENGINE"
		ShipModule.Category.CARGO:
			return "CARGO"
		ShipModule.Category.UTILITY:
			return "UTILITY"
		_:
			return "ANY"


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


func _module_tooltip(module: ShipModule) -> String:
	var lines: PackedStringArray = [module.display_name, module.description]
	for key: Variant in module.stat_modifiers.keys():
		lines.append("%s %+d" % [str(key).replace("_", " "), int(module.stat_modifiers[key])])
	if module.cargo_capacity_bonus > 0:
		lines.append("cargo +%d" % module.cargo_capacity_bonus)
	if module.salvage_capacity_bonus > 0:
		lines.append("salvage +%d" % module.salvage_capacity_bonus)
	return "\n".join(lines)


func _make_panel_style(
	background_color: Color,
	border_color: Color,
	border_width: int = 1,
	margin_x: float = 10.0,
	margin_y: float = 7.0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
