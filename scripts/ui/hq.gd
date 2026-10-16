extends Control
class_name HQScreen

const ROUTE_MAP_SCENE: String = "res://scenes/route_map.tscn"
const TEST_FLIGHT_SCENE: String = "res://scenes/tests/test_flight.tscn"

const CARD_HEIGHT: float = 112.0
const CARD_ICON_WIDTH: float = 92.0
const DELIVERY_BUTTON_WIDTH: float = 112.0

const COLOR_NAME: Color = Color(0.88, 0.97, 1.0)
const COLOR_DETAIL: Color = Color(0.6, 0.78, 0.88)
const COLOR_TYPE: Color = Color(0.45, 0.85, 0.95)
const COLOR_HAZARD: Color = Color(1.0, 0.72, 0.35)
const COLOR_FEE: Color = Color(1.0, 0.82, 0.3)

## Placeholder icon tint per cargo class, used until a mission has its own icon.
const VARIANT_COLORS: Dictionary = {
	CargoRules.CargoVariant.STANDARD: Color(0.2, 0.42, 0.55),
	CargoRules.CargoVariant.FRAGILE: Color(0.5, 0.3, 0.52),
	CargoRules.CargoVariant.BULK: Color(0.5, 0.42, 0.22),
	CargoRules.CargoVariant.VALUABLE: Color(0.58, 0.46, 0.14),
}

@onready var ship_builder: ShipBuilder = %ShipBuilder
@onready var mission_list: VBoxContainer = %MissionList
@onready var skill_tree: VBoxContainer = %SkillTree
@onready var skill_credits_label: Label = %SkillCredits
@onready var test_flight_button: Button = %TestFlightButton
@onready var confirm_build_button: Button = %ConfirmBuildButton
@onready var footer_label: Label = %FooterLabel
@onready var account_balance_label: Label = %AccountBalance
@onready var mission_dock: FocusPanel = %MissionDock
@onready var skill_dock: FocusPanel = %SkillDock
@onready var center_column: Control = %Center
@onready var center_top_spacer: Control = %CenterTopSpacer
@onready var center_bottom_spacer: Control = %CenterBottomSpacer

var available_missions: Array[MissionDefinition] = []

## Delivery button per mission, so gating can be refreshed without rebuilding the board.
var _delivery_buttons: Dictionary = {}
var _status_timer: Timer
var _align_queued: bool = false


func _ready() -> void:
	_status_timer = Timer.new()
	_status_timer.one_shot = true
	_status_timer.wait_time = 6.0
	_status_timer.timeout.connect(_refresh_balance_labels)
	add_child(_status_timer)

	_load_missions()
	_build_mission_board()
	_refresh_balance_labels()
	ship_builder.build_changed.connect(_refresh_gates)
	ship_builder.selection_changed.connect(_refresh_gates)
	confirm_build_button.pressed.connect(ship_builder.confirm_build)
	center_column.resized.connect(_queue_align)
	get_viewport().size_changed.connect(_queue_align)
	_show_salvage_recovery()
	_refresh_gates()
	_build_skill_tree()
	_announce_last_result()
	_queue_align()


# ------------------------------------------------------------ layout alignment

func _queue_align() -> void:
	if _align_queued:
		return
	_align_queued = true
	_align_center_to_side_panels.call_deferred()


## The centre console starts at the lowest point of the side panels' top edge (their inner,
## shortened edge) and ends at the highest point of their bottom edge.
func _align_center_to_side_panels() -> void:
	_align_queued = false
	var inner_top: float = maxf(mission_dock.get_docked_inner_top(), skill_dock.get_docked_inner_top())
	var inner_bottom: float = minf(mission_dock.get_docked_inner_bottom(), skill_dock.get_docked_inner_bottom())
	var column_top: float = center_column.global_position.y
	var column_bottom: float = column_top + center_column.size.y
	center_top_spacer.custom_minimum_size.y = maxf(0.0, inner_top - column_top)
	center_bottom_spacer.custom_minimum_size.y = maxf(0.0, column_bottom - inner_bottom)


# ------------------------------------------------------------------- status

## Shows a message in the footer for a few seconds, then restores the balance line.
func _flash_status(text: String) -> void:
	footer_label.text = text
	_status_timer.start()


func _announce_last_result() -> void:
	if MissionRunState.last_mission_result.is_empty():
		return
	var result: Dictionary = MissionRunState.last_mission_result
	_flash_status("%s  /  %s  /  %d CR AWARDED" % [
		"LAST DELIVERY COMPLETE" if bool(result.get("success", false)) else "LAST MISSION FAILED",
		str(result.get("mission_title", "Last Contract")).to_upper(),
		int(result.get("payout", 0)),
	])


func _refresh_balance_labels() -> void:
	var credits: String = _format_credits(MissionRunState.total_credits)
	account_balance_label.text = "CREDITS  /  %s CR" % credits
	skill_credits_label.text = "CREDITS: %s" % credits
	footer_label.text = "HQ  /  CENTRAL DOCK  /  ACCOUNT BALANCE  /  %s CR" % credits


func _format_credits(amount: int) -> String:
	return "%s" % amount


# ------------------------------------------------------------- mission board

func _load_missions() -> void:
	available_missions = MissionCatalog.load_available_missions()


func _build_mission_board() -> void:
	_clear_children(mission_list)
	_delivery_buttons.clear()
	if available_missions.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No contracts are currently available."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_list.add_child(empty_label)
		return
	for mission: MissionDefinition in available_missions:
		mission_list.add_child(_make_mission_row(mission))


func _make_mission_row(mission: MissionDefinition) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_make_mission_card(mission))

	var delivery: Button = Button.new()
	delivery.text = _mission_action_label(mission)
	delivery.custom_minimum_size = Vector2(DELIVERY_BUTTON_WIDTH, CARD_HEIGHT)
	delivery.add_theme_font_size_override("font_size", 14)
	delivery.clip_text = true
	delivery.pressed.connect(_start_mission.bind(mission))
	row.add_child(delivery)
	_delivery_buttons[mission] = delivery
	return row


## The card is a Button whose content is built from child controls: icon on the left at full
## height, then name + fee, type, client, cargo and hazard. Every label clips, so nothing can
## widen the panel.
func _make_mission_card(mission: MissionDefinition) -> Button:
	var card: Button = Button.new()
	card.theme_type_variation = &"MissionCard"
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.pressed.connect(_start_mission.bind(mission))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var content: HBoxContainer = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	content.add_child(_make_mission_icon(mission))

	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 1)
	content.add_child(text_column)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 8)
	var name_label: Label = _make_card_label(mission.title, 15, COLOR_NAME)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var fee_label: Label = _make_card_label("%d CR" % mission.base_reward_credits, 15, COLOR_FEE)
	fee_label.clip_text = false
	title_row.add_child(fee_label)
	text_column.add_child(title_row)

	text_column.add_child(_make_card_label(_mission_type_text(mission), 12, COLOR_TYPE))
	text_column.add_child(_make_card_label("Client: %s" % mission.client_name, 12, COLOR_DETAIL))
	text_column.add_child(_make_card_label("Cargo: %s" % mission.cargo_name, 12, COLOR_DETAIL))
	text_column.add_child(_make_card_label("Hazard: %s" % mission.risk_label, 12, COLOR_HAZARD))
	return card


func _make_card_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Uses the mission's icon when it has one; otherwise draws a tinted placeholder.
func _make_mission_icon(mission: MissionDefinition) -> Control:
	if mission.icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = mission.icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.clip_contents = true
		picture.custom_minimum_size = Vector2(CARD_ICON_WIDTH, 0.0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return picture

	var tint: Color = VARIANT_COLORS.get(mission.cargo_variant, VARIANT_COLORS[CargoRules.CargoVariant.STANDARD])
	var placeholder: PanelContainer = PanelContainer.new()
	placeholder.custom_minimum_size = Vector2(CARD_ICON_WIDTH, 0.0)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = tint.lightened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	placeholder.add_theme_stylebox_override("panel", style)
	var letter: Label = Label.new()
	letter.text = CargoRules.get_variant_name(mission.cargo_variant).substr(0, 1).to_upper()
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.add_theme_font_size_override("font_size", 42)
	letter.add_theme_color_override("font_color", tint.lightened(0.6))
	placeholder.add_child(letter)
	return placeholder


func _mission_type_text(mission: MissionDefinition) -> String:
	if not mission.mission_type.strip_edges().is_empty():
		return mission.mission_type
	return "%s  ·  %s" % [CargoRules.get_variant_name(mission.cargo_variant), mission.destination_name]


func _mission_action_label(mission: MissionDefinition) -> String:
	if mission == null:
		return "SELECT"
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null or not objective.required:
			continue
		match objective.objective_type:
			MissionObjectiveDefinition.ObjectiveType.COLLECT:
				return "COLLECT"
			MissionObjectiveDefinition.ObjectiveType.RESCUE:
				return "RESCUE"
			MissionObjectiveDefinition.ObjectiveType.ESCORT:
				return "ESCORT"
			MissionObjectiveDefinition.ObjectiveType.INTERCEPT:
				return "INTERCEPT"
			MissionObjectiveDefinition.ObjectiveType.INVESTIGATE:
				return "INVESTIGATE"
			MissionObjectiveDefinition.ObjectiveType.ESCAPE:
				return "ESCAPE"
			MissionObjectiveDefinition.ObjectiveType.SURVIVE:
				return "SURVIVE"
			MissionObjectiveDefinition.ObjectiveType.DEFEND:
				return "DEFEND"
			MissionObjectiveDefinition.ObjectiveType.DISABLE:
				return "DISABLE"
			MissionObjectiveDefinition.ObjectiveType.DESTROY, MissionObjectiveDefinition.ObjectiveType.ELIMINATE_GROUP:
				return "DESTROY"
			MissionObjectiveDefinition.ObjectiveType.REACH:
				return "REACH"
			MissionObjectiveDefinition.ObjectiveType.INTERACT:
				return "INTERACT"
			MissionObjectiveDefinition.ObjectiveType.DELIVER_ALL, MissionObjectiveDefinition.ObjectiveType.DELIVER:
				return "DELIVER"
			MissionObjectiveDefinition.ObjectiveType.COMPLETE_SEQUENCE:
				return "COMPLETE"
	return "DELIVER"


# --------------------------------------------------------------------- gating

## Gating follows the build shown in the builder, since launching confirms it first.
## Reasons are written on the button itself, because panel tooltips are unreliable.
func _refresh_gates() -> void:
	var has_weapon: bool = ship_builder.has_active_weapon()
	var capacity: int = ship_builder.get_cargo_capacity()
	if is_instance_valid(test_flight_button):
		test_flight_button.disabled = not has_weapon
	for mission: MissionDefinition in _delivery_buttons:
		var button: Button = _delivery_buttons[mission] as Button
		if not is_instance_valid(button):
			continue
		var required: int = CargoRules.get_required_capacity(mission)
		if not has_weapon:
			button.disabled = true
			button.text = "NO\nWEAPON"
			button.tooltip_text = "Install a weapon in the ship builder first."
		elif capacity < required:
			button.disabled = true
			button.text = "NEEDS\n%d CARGO" % required
			button.tooltip_text = "This contract needs %d cargo units; the current build has %d." % [required, capacity]
		else:
			button.disabled = false
			button.text = _mission_action_label(mission)
			button.tooltip_text = "Start this contract"


## Saves unconfirmed builder changes so the flight uses exactly what the player sees.
func _ensure_build_confirmed() -> bool:
	if not ship_builder.has_unconfirmed_changes():
		return true
	if ship_builder.confirm_build():
		return true
	_flash_status("BUILD COULD NOT BE CONFIRMED  /  CHECK THE SHIP BUILDER")
	return false


func _set_delivery_buttons_disabled(disabled: bool) -> void:
	for button: Variant in _delivery_buttons.values():
		if is_instance_valid(button):
			(button as Button).disabled = disabled


# ----------------------------------------------------------- launching flights

func _start_mission(mission: MissionDefinition) -> void:
	_refresh_gates()
	var button: Button = _delivery_buttons.get(mission) as Button
	if button == null or button.disabled:
		return
	if not _ensure_build_confirmed():
		return

	var contract_errors: PackedStringArray = mission.validate_contract()
	if not contract_errors.is_empty():
		_flash_status("CONTRACT INVALID  /  %s" % "; ".join(contract_errors))
		return
	if not ObjectiveTracker.begin_run(mission):
		_flash_status("CONTRACT INVALID  /  %s" % ObjectiveTracker.last_error)
		return
	if not MissionRunState.begin_mission(mission):
		_flash_status("ROUTE GENERATION FAILED  /  CHECK CONTRACT VALIDATION LOG")
		return
	_set_delivery_buttons_disabled(true)
	var change_error: Error = get_tree().change_scene_to_file(ROUTE_MAP_SCENE)
	if change_error != OK:
		MissionRunState.clear_mission()
		_refresh_gates()
		_flash_status("ROUTE GENERATION FAILED  /  ERROR %d  /  PLEASE RETRY" % change_error)


func _on_test_flight_pressed() -> void:
	_refresh_gates()
	if test_flight_button.disabled:
		return
	if not _ensure_build_confirmed():
		return
	var change_error: Error = get_tree().change_scene_to_file(TEST_FLIGHT_SCENE)
	if change_error != OK:
		_flash_status("COULD NOT OPEN TEST FLIGHT  /  ERROR %d" % change_error)


# ------------------------------------------------------------------- popups

func _show_salvage_recovery() -> void:
	if not MissionRunState.salvage_recovery_pending:
		return
	var recovery: Dictionary = MissionRunState.recover_pending_salvage()
	var items: Array = recovery.get("items", [])
	var total_value: int = int(recovery.get("total_value", 0))
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SalvageRecoveryLayer"
	layer.layer = 30
	add_child(layer)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.015, 0.028, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	# CanvasLayers do not pass the HQ theme down, so apply it explicitly.
	panel.theme = theme
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_top = -240
	panel.offset_right = 320
	panel.offset_bottom = 240
	layer.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var heading: Label = Label.new()
	heading.text = "SALVAGE RECOVERED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(0.45, 0.86, 1.0))
	content.add_child(heading)
	var subtitle: Label = Label.new()
	subtitle.text = "Recovered items have been converted into credits."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry: Dictionary in items:
		var item_label: Label = Label.new()
		item_label.text = "%s  ×%d   ·   %d CR each   ·   %d CR total" % [
			str(entry.get("display_name", "Unknown Salvage")),
			int(entry.get("quantity", 0)),
			int(entry.get("unit_value", 0)),
			int(entry.get("total_value", 0)),
		]
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(item_label)
	var total_label: Label = Label.new()
	total_label.text = "SALVAGE CREDITED  /  +%d CR" % total_value
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 18)
	total_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	content.add_child(total_label)
	var close: Button = Button.new()
	close.text = "CONTINUE TO HQ"
	close.custom_minimum_size = Vector2(0, 48)
	close.pressed.connect(layer.queue_free)
	content.add_child(close)
	_refresh_balance_labels()


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_skill_tree() -> void:
	for child in skill_tree.get_children():
		child.queue_free()
	var intro := Label.new()
	intro.text = "PERMANENT ACCOUNT UPGRADES"
	intro.add_theme_color_override("font_color", Color(0.65, 0.9, 0.67))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_tree.add_child(intro)
	var note := Label.new()
	note.text = "Upgrade purchasing is the next progression pass. This console is ready for real upgrade nodes."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_tree.add_child(note)
