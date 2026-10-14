extends Node2D

const HQ_SCENE_PATH: String = "res://scenes/hq.tscn"

@onready var encounter_spawner: EncounterSpawner = $EncounterSpawner
@onready var player_ship: Ship = $PlayerShip

var mission: MissionDefinition
var selected_branch: MissionRouteNode
var contact_count: int = 0
var remaining_enemies: int = 0
var mission_resolved: bool = false
var mission_label: Label
var abort_button: Button


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

	# The ship builder's saved hull and modules are loaded by Ship._ready().
	# Carry the campaign wallet into the newly instantiated player ship.
	player_ship.credits = MissionRunState.total_credits
	player_ship.credits_changed.emit(player_ship.credits)
	player_ship.destroyed.connect(_on_player_destroyed, CONNECT_ONE_SHOT)

	contact_count = clampi(3 + selected_branch.risk, 3, 8)
	encounter_spawner.spawn_count = contact_count
	encounter_spawner.spawn_on_ready = false
	_build_flight_overlay()
	call_deferred("_start_encounter")


func _start_encounter() -> void:
	if mission_resolved:
		return
	var spawned_enemies: Array[Ship] = encounter_spawner.spawn_encounter()
	remaining_enemies = spawned_enemies.size()
	for enemy: Ship in spawned_enemies:
		enemy.destroyed.connect(_on_enemy_destroyed, CONNECT_ONE_SHOT)

	if remaining_enemies <= 0:
		_resolve_mission(false, "Dispatch failed: no hostiles could be registered for this flight.")


func _build_flight_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MissionOverlay"
	layer.layer = 10
	add_child(layer)

	mission_label = Label.new()
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

	abort_button = Button.new()
	abort_button.name = "AbortMissionButton"
	abort_button.text = "ABORT MISSION"
	abort_button.position = Vector2(24, 18)
	abort_button.custom_minimum_size = Vector2(150, 34)
	abort_button.pressed.connect(_on_abort_pressed)
	layer.add_child(abort_button)


func _on_enemy_destroyed() -> void:
	if mission_resolved:
		return
	remaining_enemies = maxi(remaining_enemies - 1, 0)
	if remaining_enemies == 0:
		# All hostiles are gone. The ship has reached the delivery destination.
		_resolve_mission(true, "All hostiles cleared. Cargo delivered to the destination.")


func _on_player_destroyed() -> void:
	_resolve_mission(false, "Delivery failed: your ship was destroyed before the contract could be completed.")


func _on_abort_pressed() -> void:
	_resolve_mission(false, "Mission aborted by the pilot. Contract payment was forfeited.")


func _resolve_mission(success: bool, result_message: String) -> void:
	if mission_resolved:
		return
	mission_resolved = true

	if is_instance_valid(abort_button):
		abort_button.disabled = true

	var credits_before_payout: int = MissionRunState.total_credits
	if is_instance_valid(player_ship):
		credits_before_payout = player_ship.credits

	var base_reward: int = mission.base_reward_credits if mission != null else 0
	var route_bonus: int = selected_branch.bonus_credits if selected_branch != null else 0
	var result: Dictionary = MissionRunState.finish_mission(
		success,
		credits_before_payout,
		base_reward,
		route_bonus,
		result_message
	)

	if is_instance_valid(player_ship):
		player_ship.credits = MissionRunState.total_credits
		if player_ship.is_inside_tree():
			player_ship.credits_changed.emit(player_ship.credits)

	_show_result_screen(result)


func _show_result_screen(result: Dictionary) -> void:
	var layer: CanvasLayer = get_node_or_null("MissionResultLayer") as CanvasLayer
	if layer != null:
		layer.queue_free()
		layer = null
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "MissionResultLayer"
		layer.layer = 20
		add_child(layer)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.015, 0.028, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -190.0
	panel.offset_right = 280.0
	panel.offset_bottom = 190.0
	layer.add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var success: bool = bool(result.get("success", false))
	var heading: Label = Label.new()
	heading.text = "DELIVERY COMPLETE" if success else "MISSION FAILED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override(
		"font_color",
		Color(0.42, 0.9, 0.68) if success else Color(1.0, 0.42, 0.42)
	)
	content.add_child(heading)

	var contract_label: Label = Label.new()
	contract_label.text = str(result.get("mission_title", "Unknown Contract"))
	contract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_label.add_theme_font_size_override("font_size", 18)
	content.add_child(contract_label)

	var destination_label: Label = Label.new()
	destination_label.text = "DESTINATION  /  %s" % str(result.get("destination_name", "Unknown Destination"))
	destination_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destination_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destination_label.add_theme_color_override("font_color", Color(0.69, 0.78, 0.87))
	content.add_child(destination_label)

	var message_label: Label = Label.new()
	message_label.text = str(result.get("message", ""))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)

	var payout_label: Label = Label.new()
	payout_label.text = "CONTRACT PAY  /  %d CR\nROUTE BONUS  /  %d CR\nTOTAL PAYOUT  /  %d CR" % [
		int(result.get("base_reward", 0)),
		int(result.get("route_bonus", 0)),
		int(result.get("payout", 0)),
	]
	payout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payout_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	content.add_child(payout_label)

	var balance_label: Label = Label.new()
	balance_label.text = "ACCOUNT BALANCE  /  %d CR" % int(result.get("total_credits", 0))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.add_theme_font_size_override("font_size", 16)
	content.add_child(balance_label)

	var return_button: Button = Button.new()
	return_button.text = "RETURN TO HQ"
	return_button.custom_minimum_size = Vector2(0, 46)
	return_button.pressed.connect(_return_to_hq)
	content.add_child(return_button)


func _return_to_hq() -> void:
	MissionRunState.clear_mission()
	get_tree().change_scene_to_file(HQ_SCENE_PATH)
