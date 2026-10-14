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
	layer.layer = 10
	add_child(layer)

	var mission_label: Label = Label.new()
	mission_label.name = "ActiveMissionLabel"
	mission_label.anchor_left = 1.0
	mission_label.anchor_right = 1.0
	mission_label.offset_left = -460.0
	mission_label.offset_top = 18.0
	mission_label.offset_right = -24.0
	mission_label.offset_bottom = 48.0
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mission_label.text = "MISSION  /  %s" % mission.title.to_upper()
	mission_label.add_theme_font_size_override("font_size", 14)
	mission_label.add_theme_color_override("font_color", Color(0.78, 0.9, 0.98))
	mission_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.08, 0.9))
	mission_label.add_theme_constant_override("shadow_offset_x", 1)
	mission_label.add_theme_constant_override("shadow_offset_y", 1)
	mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(mission_label)


func _return_to_hq() -> void:
	MissionRunState.clear_mission()
	get_tree().change_scene_to_file(HQ_SCENE_PATH)
