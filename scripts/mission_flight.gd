extends Node2D

const HQ_SCENE_PATH: String = "res://scenes/hq.tscn"

@onready var encounter_spawner: EncounterSpawner = $EncounterSpawner

var mission: MissionDefinition
var selected_branch: MissionRouteNode
var contact_count: int = 0


func _ready() -> void:
	mission = MissionRunState.active_mission
	if mission == null:
		push_warning("Mission flight opened without an active contract.")
		_return_to_hq()
		return

	selected_branch = mission.get_route_node(MissionRunState.selected_branch_node_id)
	if selected_branch == null:
		push_warning("Selected mission branch is missing. Returning to HQ.")
		_return_to_hq()
		return

	contact_count = clampi(3 + selected_branch.risk, 3, 8)
	encounter_spawner.spawn_count = contact_count
	encounter_spawner.spawn_on_ready = false
	_build_flight_overlay()
	encounter_spawner.spawn_encounter.call_deferred()


func _build_flight_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MissionOverlay"
	add_child(layer)

	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(340, 0)
	layer.add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var heading: Label = Label.new()
	heading.text = "MISSION ACTIVE  /  SPACE DELIVERY"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.45, 0.78, 0.92))
	content.add_child(heading)

	var title_label: Label = Label.new()
	title_label.text = mission.title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)

	var route_label: Label = Label.new()
	route_label.text = "ROUTE  /  %s\nDESTINATION  /  %s\nBASE PAYOUT  /  %d CR\nROUTE BONUS  /  %d CR\nHOSTILE CONTACTS  /  %d" % [
		selected_branch.title,
		mission.destination_name,
		mission.base_reward_credits,
		selected_branch.bonus_credits,
		contact_count,
	]
	route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(route_label)

	var objective_label: Label = Label.new()
	objective_label.text = "CURRENT OBJECTIVE\nClear the hostile contacts along your selected corridor."
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_color", Color(0.69, 0.78, 0.87))
	content.add_child(objective_label)

	var return_button: Button = Button.new()
	return_button.text = "ABORT DELIVERY  /  RETURN TO HQ"
	return_button.custom_minimum_size = Vector2(0, 42)
	return_button.pressed.connect(_return_to_hq)
	content.add_child(return_button)


func _return_to_hq() -> void:
	MissionRunState.clear_mission()
	get_tree().change_scene_to_file(HQ_SCENE_PATH)
