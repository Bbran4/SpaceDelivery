extends Control
class_name HQScreen

const ROUTE_MAP_SCENE: String = "res://scenes/route_map.tscn"
const CARD_TITLE_COLOR: Color = Color(0.85, 0.96, 1.0)
const CARD_DETAIL_COLOR: Color = Color(0.55, 0.76, 0.86)

@onready var ship_builder: ShipBuilder = %ShipBuilder
@onready var welcome_content: VBoxContainer = %WelcomeContent
@onready var welcome_text: Label = %WelcomeText
@onready var status_panel: PanelContainer = %StatusPanel
@onready var status_label: Label = %StatusLabel
@onready var mission_actions: VBoxContainer = %MissionActions
@onready var center_actions: VBoxContainer = %CenterActions
@onready var skill_tree: VBoxContainer = %SkillTree
@onready var skill_credits_label: Label = %SkillCredits
@onready var test_flight_button: Button = %TestFlightButton
@onready var confirm_build_button: Button = %ConfirmBuildButton
@onready var footer_label: Label = %FooterLabel
@onready var account_balance_label: Label = %AccountBalance

var available_missions: Array[MissionDefinition] = []
var selected_mission: MissionDefinition
var mission_list: VBoxContainer
var selected_details: VBoxContainer
var deliver_button: Button
var weapon_warning_label: Label
var test_flight_warning_label: Label
var cargo_capacity_warning_label: Label

## Mission card buttons keyed by mission, so selection can be synced without rebuilding the list.
var _mission_cards: Dictionary = {}


func _ready() -> void:
	_load_missions()
	_build_mission_board()
	_build_deliver_button()
	_build_weapon_warnings()
	_refresh_campaign_status()
	ship_builder.build_changed.connect(_refresh_weapon_gates)
	confirm_build_button.pressed.connect(ship_builder.confirm_build)
	_show_salvage_recovery()
	_refresh_weapon_gates()
	_build_skill_tree()


func _refresh_campaign_status() -> void:
	_refresh_balance_labels()
	if MissionRunState.last_mission_result.is_empty():
		return

	var result: Dictionary = MissionRunState.last_mission_result
	var success: bool = bool(result.get("success", false))
	var mission_title: String = str(result.get("mission_title", "Last Contract"))
	var payout: int = int(result.get("payout", 0))
	status_label.text = "%s  /  %s  /  %s CR AWARDED" % [
		"LAST DELIVERY COMPLETE" if success else "LAST MISSION FAILED",
		mission_title.to_upper(),
		payout,
	]


func _refresh_balance_labels() -> void:
	var credits: String = _format_credits(MissionRunState.total_credits)
	account_balance_label.text = "CREDITS  /  %s CR" % credits
	skill_credits_label.text = "CREDITS: %s" % credits
	footer_label.text = "HQ  /  CENTRAL DOCK  /  ACCOUNT BALANCE  /  %s CR" % credits


func _format_credits(amount: int) -> String:
	return "%s" % amount


func _load_missions() -> void:
	available_missions = MissionCatalog.load_available_missions()


func _build_mission_board() -> void:
	welcome_text.visible = false
	status_panel.visible = true
	status_label.text = "SELECT A CONTRACT TO REVIEW ITS DETAILS"

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MissionBoardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	# Without this the scroll area grows sideways to fit wide content instead of wrapping it.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var board_content: VBoxContainer = VBoxContainer.new()
	board_content.name = "MissionBoardContent"
	board_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_content.add_theme_constant_override("separation", 12)
	scroll.add_child(board_content)

	var contracts_heading: Label = Label.new()
	contracts_heading.text = "AVAILABLE CONTRACTS"
	contracts_heading.add_theme_font_size_override("font_size", 13)
	contracts_heading.add_theme_color_override("font_color", Color(0.45, 0.78, 0.92))
	board_content.add_child(contracts_heading)

	mission_list = VBoxContainer.new()
	mission_list.name = "MissionList"
	mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_list.add_theme_constant_override("separation", 6)
	board_content.add_child(mission_list)

	selected_details = VBoxContainer.new()
	selected_details.name = "SelectedMissionDetails"
	selected_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_details.add_theme_constant_override("separation", 7)
	board_content.add_child(selected_details)

	welcome_content.add_child(scroll)
	welcome_content.move_child(scroll, 1)
	_refresh_mission_list()
	_show_empty_selection()


func _build_deliver_button() -> void:
	deliver_button = Button.new()
	deliver_button.name = "DeliverButton"
	deliver_button.text = "VIEW ROUTE  /  SELECT A CONTRACT"
	deliver_button.custom_minimum_size = Vector2(0, 52)
	deliver_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Long contract titles must be trimmed, not allowed to widen the whole panel.
	deliver_button.clip_text = true
	deliver_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	deliver_button.disabled = true
	deliver_button.pressed.connect(_on_deliver_pressed)
	mission_actions.add_child(deliver_button)


func _build_weapon_warnings() -> void:
	cargo_capacity_warning_label = Label.new()
	cargo_capacity_warning_label.text = "INSUFFICIENT CARGO CAPACITY FOR SELECTED CONTRACT"
	cargo_capacity_warning_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.24))
	cargo_capacity_warning_label.add_theme_font_size_override("font_size", 12)
	cargo_capacity_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo_capacity_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_actions.add_child(cargo_capacity_warning_label)
	cargo_capacity_warning_label.visible = false
	mission_actions.move_child(cargo_capacity_warning_label, deliver_button.get_index())
	weapon_warning_label = Label.new()
	weapon_warning_label.text = "NO ACTIVE WEAPON ON SHIP"
	weapon_warning_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	weapon_warning_label.add_theme_font_size_override("font_size", 12)
	weapon_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_actions.add_child(weapon_warning_label)
	mission_actions.move_child(weapon_warning_label, deliver_button.get_index())
	test_flight_warning_label = Label.new()
	test_flight_warning_label.text = "NO ACTIVE WEAPON ON SHIP"
	test_flight_warning_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	test_flight_warning_label.add_theme_font_size_override("font_size", 12)
	test_flight_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_actions.add_child(test_flight_warning_label)
	center_actions.move_child(test_flight_warning_label, 0)


func _refresh_weapon_gates() -> void:
	var active_build: Dictionary = ShipBuildStore.get_active_build()
	var has_weapon: bool = not active_build.is_empty()
	if active_build.is_empty():
		has_weapon = ShipBuildStore.build_has_weapon("res://resources/hulls/starter_courier.tres", PackedStringArray(["res://resources/modules/basic_laser_module.tres"]))
	var has_capacity: bool = selected_mission == null or _active_ship_cargo_capacity() >= CargoRules.get_required_capacity(selected_mission)
	if is_instance_valid(deliver_button):
		deliver_button.disabled = selected_mission == null or not has_weapon or not has_capacity
	if is_instance_valid(cargo_capacity_warning_label):
		cargo_capacity_warning_label.visible = selected_mission != null and has_weapon and not has_capacity
	if is_instance_valid(test_flight_button):
		test_flight_button.disabled = not has_weapon
	if is_instance_valid(weapon_warning_label):
		weapon_warning_label.visible = not has_weapon
	if is_instance_valid(test_flight_warning_label):
		test_flight_warning_label.visible = not has_weapon


func _active_ship_cargo_capacity() -> int:
	var build: Dictionary = ShipBuildStore.get_active_build()
	if not build.is_empty():
		return ShipBuildStore.get_cargo_capacity(
			str(build.get("hull_path", "")),
			build.get("module_paths", PackedStringArray())
		)
	return ShipBuildStore.get_cargo_capacity(
		"res://resources/hulls/starter_courier.tres",
		PackedStringArray(["res://resources/modules/basic_laser_module.tres"])
	)


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
	# Updates the header, footer and skill-panel balances together.
	_refresh_balance_labels()


## Builds the contract list once. Selection is synced in place afterwards, so cards keep
## their hover/focus state and nothing is freed from inside its own signal handler.
func _refresh_mission_list() -> void:
	_clear_children(mission_list)
	_mission_cards.clear()
	if available_missions.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No contracts are currently available."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_list.add_child(empty_label)
		return

	for mission: MissionDefinition in available_missions:
		var mission_row: HBoxContainer = HBoxContainer.new()
		mission_row.add_theme_constant_override("separation", 8)
		mission_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var card: Button = _make_mission_card(mission)
		mission_row.add_child(card)
		_mission_cards[mission] = card

		var action_button: Button = Button.new()
		action_button.text = _mission_action_label(mission)
		action_button.custom_minimum_size = Vector2(120, 68)
		action_button.add_theme_font_size_override("font_size", 14)
		action_button.clip_text = true
		action_button.tooltip_text = "Select and start this contract"
		action_button.pressed.connect(_on_mission_action_pressed.bind(mission))
		mission_row.add_child(action_button)
		mission_list.add_child(mission_row)
	_sync_mission_cards()


## A card is a toggle Button with its text as child Labels. Button text cannot be clipped
## per line, and long text would otherwise force the whole panel wider than its slot.
func _make_mission_card(mission: MissionDefinition) -> Button:
	var card: Button = Button.new()
	card.theme_type_variation = &"MissionCard"
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(0, 68)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.pressed.connect(_on_mission_button_pressed.bind(mission))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 2)
	margin.add_child(text_column)

	text_column.add_child(_make_card_label(mission.title, 15, CARD_TITLE_COLOR))
	text_column.add_child(_make_card_label(
		"%s  ·  %d CR" % [mission.client_name, mission.base_reward_credits], 12, CARD_DETAIL_COLOR
	))
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


func _sync_mission_cards() -> void:
	for mission: MissionDefinition in _mission_cards:
		var card: Button = _mission_cards[mission] as Button
		if is_instance_valid(card):
			card.set_pressed_no_signal(mission == selected_mission)


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


func _on_mission_action_pressed(mission: MissionDefinition) -> void:
	selected_mission = mission
	_sync_mission_cards()
	_refresh_selected_details()
	_refresh_weapon_gates()
	_on_deliver_pressed()


func _on_mission_button_pressed(mission: MissionDefinition) -> void:
	selected_mission = mission
	deliver_button.disabled = false
	deliver_button.text = "VIEW ROUTE  /  %s" % mission.title.to_upper()
	_refresh_weapon_gates()
	status_label.text = "CONTRACT SELECTED  /  VIEW ROUTE TO BEGIN"
	# Re-pressing the selected card would otherwise toggle it off.
	_sync_mission_cards()
	_refresh_selected_details()


func _show_empty_selection() -> void:
	_clear_children(selected_details)
	var prompt: Label = Label.new()
	prompt.text = "Select a contract above to inspect its cargo, client, destination, and payout. Route intelligence is generated after selection."
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_color", Color(0.64, 0.74, 0.84))
	selected_details.add_child(prompt)


func _refresh_selected_details() -> void:
	_clear_children(selected_details)
	if selected_mission == null:
		return

	var title_label: Label = Label.new()
	title_label.text = selected_mission.title
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_details.add_child(title_label)

	var client_label: Label = Label.new()
	client_label.text = "CLIENT  /  %s" % selected_mission.client_name
	client_label.add_theme_color_override("font_color", Color(0.45, 0.78, 0.92))
	client_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_details.add_child(client_label)

	var cargo_label: Label = Label.new()
	cargo_label.text = "CARGO  /  %s\nTYPE  /  %s  ·  CLASS / %s\nMANIFEST  /  %s\nDECLARED VALUE  /  %d CR\nDESTINATION  /  %s\nBASE PAYOUT  /  %d CR  ·  RISK  /  %s\nCARGO CAPACITY REQUIRED  /  %d UNITS\nMINIMUM DELIVERY INTEGRITY  /  %d%%\nFULL REWARD INTEGRITY  /  %d%%  ·  PENALTY IF BELOW  /  %d%%" % [
		selected_mission.cargo_name,
		selected_mission.cargo_type,
		CargoRules.get_variant_name(selected_mission.cargo_variant).to_upper(),
		selected_mission.cargo_description,
		selected_mission.cargo_value_credits,
		selected_mission.destination_name,
		selected_mission.base_reward_credits,
		selected_mission.risk_label,
		CargoRules.get_required_capacity(selected_mission),
		selected_mission.minimum_delivery_integrity_percent,
		selected_mission.full_reward_integrity_percent,
		selected_mission.damaged_cargo_payout_penalty_percent,
	]
	cargo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_details.add_child(cargo_label)

	var briefing_label: Label = Label.new()
	briefing_label.text = selected_mission.briefing
	briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_label.add_theme_color_override("font_color", Color(0.69, 0.78, 0.87))
	selected_details.add_child(briefing_label)


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_deliver_pressed() -> void:
	_refresh_weapon_gates()
	if selected_mission == null or deliver_button.disabled:
		deliver_button.disabled = true
		return

	var contract_errors: PackedStringArray = selected_mission.validate_contract()
	if not contract_errors.is_empty():
		status_label.text = "CONTRACT INVALID  /  %s" % "; ".join(contract_errors)
		deliver_button.disabled = true
		return
	if not ObjectiveTracker.begin_run(selected_mission):
		status_label.text = "CONTRACT INVALID  /  %s" % ObjectiveTracker.last_error
		deliver_button.disabled = true
		return
	if not MissionRunState.begin_mission(selected_mission):
		status_label.text = "ROUTE GENERATION FAILED  /  CHECK CONTRACT VALIDATION LOG"
		deliver_button.disabled = false
		return
	deliver_button.disabled = true
	status_label.text = "GENERATING ROUTE INTELLIGENCE  /  %s" % selected_mission.title.to_upper()
	var change_error: Error = get_tree().change_scene_to_file(ROUTE_MAP_SCENE)
	if change_error != OK:
		MissionRunState.clear_mission()
		deliver_button.disabled = false
		status_label.text = "ROUTE GENERATION FAILED  /  ERROR %d  /  PLEASE RETRY" % change_error


func _on_test_flight_pressed() -> void:
	_refresh_weapon_gates()
	if test_flight_button.disabled:
		return
	get_tree().change_scene_to_file("res://scenes/tests/hud_test.tscn")


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
