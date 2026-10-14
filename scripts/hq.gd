extends Control
class_name HQScreen

const MISSION_FLIGHT_SCENE: String = "res://scenes/mission_flight.tscn"

const MISSION_PATHS: Array[String] = [
	"res://resources/missions/priority_medical_shipment.tres",
	"res://resources/missions/fragile_relay_components.tres",
]

@onready var ship_builder: ShipBuilder = %ShipBuilder
@onready var upgrades_overlay: Control = %UpgradesOverlay
@onready var welcome_content: VBoxContainer = $Margin/Layout/MainContent/WelcomePanel/WelcomeContent
@onready var welcome_text: Label = $Margin/Layout/MainContent/WelcomePanel/WelcomeContent/WelcomeText
@onready var status_panel: PanelContainer = $Margin/Layout/MainContent/WelcomePanel/WelcomeContent/StatusPanel
@onready var status_label: Label = $Margin/Layout/MainContent/WelcomePanel/WelcomeContent/StatusPanel/StatusLabel
@onready var services: VBoxContainer = $Margin/Layout/MainContent/ServicesPanel/Services
@onready var test_flight_button: Button = $Margin/Layout/MainContent/ServicesPanel/Services/TestFlightButton
@onready var footer_label: Label = $Margin/Layout/Footer/FooterLabel

var available_missions: Array[MissionDefinition] = []
var selected_mission: MissionDefinition
var selected_branch_node_id: StringName = &""
var mission_list: VBoxContainer
var selected_details: VBoxContainer
var route_preview: VBoxContainer
var deliver_button: Button


func _ready() -> void:
	_load_missions()
	_build_mission_board()
	_build_deliver_button()
	_refresh_campaign_status()


func _refresh_campaign_status() -> void:
	footer_label.text = "HQ  /  CENTRAL DOCK  /  ACCOUNT BALANCE  /  %d CR" % MissionRunState.total_credits
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


func _load_missions() -> void:
	available_missions.clear()
	for mission_path: String in MISSION_PATHS:
		var mission: MissionDefinition = load(mission_path) as MissionDefinition
		if mission == null:
			push_warning("Could not load mission definition: " + mission_path)
			continue
		var validation_errors: PackedStringArray = mission.validate_route_graph()
		if not validation_errors.is_empty():
			push_warning("Mission '%s' has an invalid route graph: %s" % [
				mission.mission_id,
				"; ".join(validation_errors),
			])
			continue
		available_missions.append(mission)


func _build_mission_board() -> void:
	welcome_text.visible = false
	status_panel.visible = true
	status_label.text = "SELECT A CONTRACT TO REVIEW ITS ROUTE"

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MissionBoardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 430)

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
	mission_list.add_theme_constant_override("separation", 6)
	board_content.add_child(mission_list)

	selected_details = VBoxContainer.new()
	selected_details.name = "SelectedMissionDetails"
	selected_details.add_theme_constant_override("separation", 7)
	board_content.add_child(selected_details)

	var route_heading: Label = Label.new()
	route_heading.text = "ROUTE MAP"
	route_heading.add_theme_font_size_override("font_size", 13)
	route_heading.add_theme_color_override("font_color", Color(0.45, 0.78, 0.92))
	board_content.add_child(route_heading)

	route_preview = VBoxContainer.new()
	route_preview.name = "RoutePreview"
	route_preview.add_theme_constant_override("separation", 5)
	board_content.add_child(route_preview)

	welcome_content.add_child(scroll)
	welcome_content.move_child(scroll, 1)
	_refresh_mission_list()
	_show_empty_selection()


func _build_deliver_button() -> void:
	deliver_button = Button.new()
	deliver_button.name = "DeliverButton"
	deliver_button.text = "DELIVER  /  SELECT A CONTRACT"
	deliver_button.custom_minimum_size = Vector2(0, 52)
	deliver_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deliver_button.disabled = true
	deliver_button.pressed.connect(_on_deliver_pressed)
	services.add_child(deliver_button)
	services.move_child(deliver_button, services.get_child_count() - 2)



func _refresh_mission_list() -> void:
	_clear_children(mission_list)
	for mission: MissionDefinition in available_missions:
		var mission_button: Button = Button.new()
		mission_button.toggle_mode = true
		mission_button.button_pressed = mission == selected_mission
		mission_button.text = "%s\n%s  ·  %d CR" % [
			mission.title,
			mission.client_name,
			mission.base_reward_credits,
		]
		mission_button.custom_minimum_size = Vector2(0, 58)
		mission_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mission_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mission_button.pressed.connect(_on_mission_button_pressed.bind(mission))
		mission_list.add_child(mission_button)


func _on_mission_button_pressed(mission: MissionDefinition) -> void:
	selected_mission = mission
	selected_branch_node_id = _get_default_branch_id(mission)
	deliver_button.disabled = false
	deliver_button.text = "DELIVER  /  %s" % mission.title.to_upper()
	status_label.text = "CONTRACT SELECTED  /  REVIEW ROUTE BEFORE DEPARTURE"
	_refresh_mission_list()
	_refresh_selected_details()
	_refresh_route_preview()


func _show_empty_selection() -> void:
	_clear_children(selected_details)
	_clear_children(route_preview)
	var prompt: Label = Label.new()
	prompt.text = "Select a contract above to inspect the cargo, payout, and route options."
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_color", Color(0.64, 0.74, 0.84))
	selected_details.add_child(prompt)

	var empty_route: Label = Label.new()
	empty_route.text = "DISPATCH  →  ROUTE CHOICE  →  DESTINATION"
	empty_route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_route.add_theme_color_override("font_color", Color(0.48, 0.61, 0.72))
	route_preview.add_child(empty_route)


func _refresh_selected_details() -> void:
	_clear_children(selected_details)
	if selected_mission == null:
		return

	var title_label: Label = Label.new()
	title_label.text = selected_mission.title
	title_label.add_theme_font_size_override("font_size", 17)
	selected_details.add_child(title_label)

	var client_label: Label = Label.new()
	client_label.text = "CLIENT  /  %s" % selected_mission.client_name
	client_label.add_theme_color_override("font_color", Color(0.45, 0.78, 0.92))
	client_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_details.add_child(client_label)

	var cargo_label: Label = Label.new()
	cargo_label.text = "CARGO  /  %s\nTYPE  /  %s\nMANIFEST  /  %s\nDECLARED VALUE  /  %d CR\nDESTINATION  /  %s\nBASE PAYOUT  /  %d CR  ·  RISK  /  %s\nMINIMUM DELIVERY INTEGRITY  /  %d%%\nFULL REWARD INTEGRITY  /  %d%%  ·  PENALTY IF BELOW  /  %d%%" % [
		selected_mission.cargo_name,
		selected_mission.cargo_type,
		selected_mission.cargo_description,
		selected_mission.cargo_value_credits,
		selected_mission.destination_name,
		selected_mission.base_reward_credits,
		selected_mission.risk_label,
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


func _refresh_route_preview() -> void:
	_clear_children(route_preview)
	if selected_mission == null:
		return

	var start_node: MissionRouteNode = selected_mission.get_route_node(selected_mission.start_node_id)
	if start_node == null:
		return
	_add_route_marker(start_node.title, "START")

	var choice_node: MissionRouteNode
	for route_node: MissionRouteNode in selected_mission.route_nodes:
		if route_node.node_kind == MissionRouteNode.NodeKind.CHOICE:
			choice_node = route_node
			break

	if choice_node != null:
		_add_route_connector()
		_add_route_marker(choice_node.title, "CHOOSE A BRANCH")
		var branch_row: HBoxContainer = HBoxContainer.new()
		branch_row.add_theme_constant_override("separation", 6)
		for branch_id: StringName in choice_node.next_node_ids:
			var branch: MissionRouteNode = selected_mission.get_route_node(branch_id)
			if branch == null:
				continue
			var branch_button: Button = Button.new()
			branch_button.toggle_mode = true
			branch_button.button_pressed = branch.node_id == selected_branch_node_id
			var profile_label: String = _get_encounter_profile_label(branch.encounter_profile)
			branch_button.text = "%s\nRISK %d  ·  %s\n+%d CR" % [
				branch.title,
				branch.risk,
				profile_label,
				branch.bonus_credits,
			]
			branch_button.custom_minimum_size = Vector2(0, 64)
			branch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			branch_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			branch_button.pressed.connect(_on_branch_selected.bind(branch.node_id))
			branch_row.add_child(branch_button)
		route_preview.add_child(branch_row)

		var selected_branch: MissionRouteNode = selected_mission.get_route_node(selected_branch_node_id)
		if selected_branch != null:
			var branch_detail: Label = Label.new()
			branch_detail.text = selected_branch.description
			branch_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			branch_detail.add_theme_color_override("font_color", Color(0.69, 0.78, 0.87))
			route_preview.add_child(branch_detail)

	var merge_node: MissionRouteNode
	var destination_node: MissionRouteNode = selected_mission.get_route_node(selected_mission.destination_node_id)
	for route_node: MissionRouteNode in selected_mission.route_nodes:
		if route_node.next_node_ids.has(selected_mission.destination_node_id):
			merge_node = route_node
			break

	if merge_node != null:
		_add_route_connector()
		_add_route_marker(merge_node.title, "ROUTES REJOIN")
	if destination_node != null:
		_add_route_connector()
		_add_route_marker(destination_node.title, "DELIVERY DESTINATION")


func _get_encounter_profile_label(profile: int) -> String:
	match profile:
		MissionRouteNode.EncounterProfile.QUIET:
			return "LIGHT PATROLS"
		MissionRouteNode.EncounterProfile.SALVAGE:
			return "HEAVY PATROLS · CACHE +50 CR"
		_:
			return "STANDARD PATROLS"


func _on_branch_selected(branch_id: StringName) -> void:
	selected_branch_node_id = branch_id
	_refresh_route_preview()


func _get_default_branch_id(mission: MissionDefinition) -> StringName:
	for route_node: MissionRouteNode in mission.route_nodes:
		if route_node.node_kind == MissionRouteNode.NodeKind.CHOICE and not route_node.next_node_ids.is_empty():
			return route_node.next_node_ids[0]
	return &""


func _add_route_connector() -> void:
	var connector: Label = Label.new()
	connector.text = "↓"
	connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	connector.add_theme_color_override("font_color", Color(0.42, 0.64, 0.76))
	route_preview.add_child(connector)


func _add_route_marker(title: String, subtitle: String) -> void:
	var marker: PanelContainer = PanelContainer.new()
	marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var subtitle_label: Label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_size_override("font_size", 10)
	subtitle_label.add_theme_color_override("font_color", Color(0.45, 0.78, 0.92))
	content.add_child(title_label)
	content.add_child(subtitle_label)
	marker.add_child(content)
	route_preview.add_child(marker)


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_deliver_pressed() -> void:
	if selected_mission == null:
		deliver_button.disabled = true
		return
	var selected_branch: MissionRouteNode = selected_mission.get_route_node(selected_branch_node_id)
	if selected_branch == null:
		status_label.text = "ROUTE ERROR  /  PLEASE SELECT THIS CONTRACT AGAIN"
		return

	MissionRunState.begin_mission(selected_mission, selected_branch_node_id)
	deliver_button.disabled = true
	status_label.text = "DISPATCHING  /  %s  /  %s" % [
		selected_mission.title,
		selected_branch.title,
	]
	var change_error: Error = get_tree().change_scene_to_file(MISSION_FLIGHT_SCENE)
	if change_error != OK:
		MissionRunState.clear_mission()
		deliver_button.disabled = false
		status_label.text = "LAUNCH FAILED  /  ERROR %d  /  PLEASE RETRY" % change_error


func _on_shipyard_pressed() -> void:
	ship_builder.show_builder()


func _on_test_flight_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/hud_test.tscn")


func _on_upgrades_pressed() -> void:
	upgrades_overlay.visible = true


func _on_upgrades_close_pressed() -> void:
	upgrades_overlay.visible = false
