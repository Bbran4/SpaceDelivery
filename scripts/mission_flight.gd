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
var cargo_status_label: Label
var cargo_integrity: float = 100.0
var cargo_condition: String = "INTACT"
var resolution_pending: bool = false
var credits_at_encounter_start: int = 0
var route_label: Label
var destination_button: Button


func _ready() -> void:
	mission = MissionRunState.active_mission
	if mission == null:
		push_warning("Mission flight opened without an active contract.")
		_return_to_hq()
		return

	selected_branch = MissionRunState.get_route_node(MissionRunState.selected_branch_node_id)
	if selected_branch == null:
		push_warning("Selected mission branch is missing. Returning to HQ.")
		_return_to_hq()
		return

	# The ship builder's saved hull and modules are loaded by Ship._ready().
	# Carry the campaign wallet into the newly instantiated player ship.
	MissionRunState.restore_ship_condition(player_ship)
	cargo_integrity = MissionRunState.cargo_integrity_percent
	player_ship.credits = MissionRunState.total_credits
	credits_at_encounter_start = player_ship.credits
	player_ship.credits_changed.emit(player_ship.credits)
	player_ship.destroyed.connect(_on_player_destroyed, CONNECT_ONE_SHOT)
	player_ship.damaged.connect(_on_player_damaged)

	contact_count = clampi(2 + selected_branch.risk, 3, 8)
	encounter_spawner.spawn_count = contact_count
	encounter_spawner.spawn_on_ready = false
	_build_flight_overlay()
	if is_instance_valid(route_label):
		route_label.text = "CURRENT NODE  /  %s  /  RISK %d" % [selected_branch.title, selected_branch.risk]
	call_deferred("_start_encounter")


func _start_encounter() -> void:
	if mission_resolved:
		return
	var spawned_enemies: Array[Ship] = encounter_spawner.spawn_encounter(selected_branch.encounter_profile)
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

	cargo_status_label = Label.new()
	cargo_status_label.name = "CargoStatusLabel"
	cargo_status_label.anchor_left = 1.0
	cargo_status_label.anchor_right = 1.0
	cargo_status_label.offset_left = -460.0
	cargo_status_label.offset_top = 48.0
	cargo_status_label.offset_right = -24.0
	cargo_status_label.offset_bottom = 74.0
	cargo_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cargo_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cargo_status_label.add_theme_font_size_override("font_size", 12)
	cargo_status_label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.92))
	cargo_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cargo_status_label)
	_update_cargo_status()

	route_label = Label.new()
	route_label.name = "ExecutedRouteLabel"
	route_label.anchor_left = 0.0
	route_label.anchor_right = 1.0
	route_label.offset_left = 24.0
	route_label.offset_top = 82.0
	route_label.offset_right = -24.0
	route_label.offset_bottom = 108.0
	route_label.add_theme_font_size_override("font_size", 12)
	route_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	route_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(route_label)

	abort_button = Button.new()
	abort_button.name = "AbortMissionButton"
	abort_button.text = "ABORT MISSION"
	abort_button.anchor_top = 1.0
	abort_button.anchor_bottom = 1.0
	abort_button.offset_left = 24.0
	abort_button.offset_top = -52.0
	abort_button.offset_right = 174.0
	abort_button.offset_bottom = -18.0
	abort_button.custom_minimum_size = Vector2(150, 34)
	abort_button.pressed.connect(_on_abort_pressed)
	layer.add_child(abort_button)


func _on_player_damaged(_amount: float, hull_damage: float, _shield_damage: float) -> void:
	if mission_resolved or mission == null:
		return
	if hull_damage > 0.0:
		cargo_integrity = maxf(0.0, cargo_integrity - hull_damage * mission.cargo_damage_sensitivity)
		MissionRunState.cargo_integrity_percent = cargo_integrity
	if is_instance_valid(player_ship):
		MissionRunState.save_ship_condition(player_ship)
	_update_cargo_status()


func _update_cargo_status() -> void:
	if not is_instance_valid(cargo_status_label) or mission == null:
		return
	if cargo_integrity >= float(mission.full_reward_integrity_percent):
		cargo_condition = "INTACT"
	elif cargo_integrity > 0.0:
		cargo_condition = "DAMAGED"
	else:
		cargo_condition = "LOST"
	cargo_status_label.text = "%s  /  %s  /  VALUE %d CR  /  INTEGRITY %d%%" % [mission.cargo_name.to_upper(), cargo_condition, mission.cargo_value_credits, roundi(cargo_integrity)]
	if cargo_condition == "INTACT":
		cargo_status_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.72))
	elif cargo_condition == "DAMAGED":
		cargo_status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	else:
		cargo_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))


func _on_enemy_destroyed() -> void:
	if mission_resolved:
		return
	remaining_enemies = maxi(remaining_enemies - 1, 0)
	if remaining_enemies == 0:
		# Leave flight and loot pickups active until the pilot chooses to proceed.
		_show_destination_button()


func _on_player_destroyed() -> void:
	_resolve_mission(false, "Delivery failed: your ship was destroyed before the contract could be completed.")


func _on_abort_pressed() -> void:
	_resolve_mission(false, "Mission aborted by the pilot. Contract payment was forfeited.")


func _on_node_completed() -> void:
	if mission_resolved or mission == null or selected_branch == null:
		return
	if is_instance_valid(player_ship):
		var credits_after_node: int = player_ship.credits
		var credits_before_node: int = MissionRunState.total_credits
		MissionRunState.total_credits = credits_after_node
		MissionRunState.add_node_rewards(selected_branch, credits_before_node, credits_after_node)
		MissionRunState.save_ship_condition(player_ship)
	MissionRunState.cargo_integrity_percent = cargo_integrity
	MissionRunState.complete_route_node(selected_branch.node_id)
	var change_error: Error = get_tree().change_scene_to_file("res://scenes/route_map.tscn")
	if change_error != OK:
		_resolve_mission(false, "Navigation failure: the route map could not be restored after this node.")


func _resolve_mission(success: bool, result_message: String) -> void:
	if mission_resolved:
		return
	mission_resolved = true

	if is_instance_valid(abort_button):
		abort_button.disabled = true

	if is_instance_valid(player_ship):
		# Returning to HQ always restores hull and shields, whether the mission succeeded or was aborted/failed.
		player_ship.current_hull = player_ship.max_hull
		player_ship.current_shield = player_ship.max_shield
		player_ship.hull_changed.emit(player_ship.current_hull, player_ship.max_hull)
		player_ship.shield_changed.emit(player_ship.current_shield, player_ship.max_shield)
		MissionRunState.save_ship_condition(player_ship)
	MissionRunState.cargo_integrity_percent = cargo_integrity

	var base_reward: int = mission.base_reward_credits if mission != null else 0
	var route_bonus: int = selected_branch.bonus_credits if selected_branch != null else 0
	var credits_collected: int = MissionRunState.credits_collected_this_mission
	if is_instance_valid(player_ship):
		credits_collected += maxi(0, player_ship.credits - credits_at_encounter_start)

	# Salvage-profile routes include a recoverable cache, paid only when the delivery succeeds.
	var salvage_recovered: int = 50 if success and selected_branch != null and selected_branch.encounter_profile == MissionRouteNode.EncounterProfile.SALVAGE else 0
	if salvage_recovered > 0 and is_instance_valid(player_ship):
		player_ship.credits += salvage_recovered
		player_ship.credits_changed.emit(player_ship.credits)

	var credits_before_payout: int = MissionRunState.total_credits
	if is_instance_valid(player_ship):
		credits_before_payout = player_ship.credits

	var cargo_penalty_percent: int = 0
	if success and cargo_integrity < float(mission.full_reward_integrity_percent):
		cargo_penalty_percent = mission.damaged_cargo_payout_penalty_percent
	var result: Dictionary = MissionRunState.finish_mission(
		success,
		credits_before_payout,
		base_reward,
		route_bonus,
		result_message,
		cargo_condition,
		cargo_penalty_percent,
		credits_collected,
		salvage_recovered
	)

	if is_instance_valid(player_ship):
		player_ship.credits = MissionRunState.total_credits
		if player_ship.is_inside_tree():
			player_ship.credits_changed.emit(player_ship.credits)

	_show_result_screen(result)


func _show_destination_button() -> void:
	if resolution_pending or mission_resolved:
		return
	resolution_pending = true
	if is_instance_valid(abort_button):
		abort_button.disabled = true
	var overlay: CanvasLayer = get_node_or_null("MissionOverlay") as CanvasLayer
	if overlay == null:
		return
	destination_button = Button.new()
	destination_button.name = "CompleteDeliveryButton"
	destination_button.text = "RETURN TO ROUTE MAP  /  NODE COMPLETE"
	destination_button.anchor_left = 0.5
	destination_button.anchor_right = 0.5
	destination_button.anchor_top = 1.0
	destination_button.anchor_bottom = 1.0
	destination_button.offset_left = -190.0
	destination_button.offset_top = -66.0
	destination_button.offset_right = 190.0
	destination_button.offset_bottom = -18.0
	destination_button.custom_minimum_size = Vector2(380, 44)
	destination_button.pressed.connect(_on_node_completed)
	overlay.add_child(destination_button)


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
	panel.offset_top = -250.0
	panel.offset_right = 280.0
	panel.offset_bottom = 250.0
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

	var cargo_label: Label = Label.new()
	cargo_label.text = "CARGO  /  %s  ·  %s  ·  VALUE %d CR  ·  INTEGRITY %d%%" % [
		str(result.get("cargo_name", "Unknown Cargo")),
		str(result.get("cargo_condition", "UNKNOWN")),
		int(result.get("cargo_value_credits", 0)),
		roundi(float(result.get("cargo_integrity_percent", 0.0))),
	]
	cargo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cargo_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.72) if str(result.get("cargo_condition", "")) == "INTACT" else (Color(1.0, 0.78, 0.35) if str(result.get("cargo_condition", "")) == "DAMAGED" else Color(1.0, 0.42, 0.42)))
	content.add_child(cargo_label)

	var requirement_label: Label = Label.new()
	requirement_label.text = "DELIVERY MINIMUM  /  %d%%     FULL REWARD  /  %d%%" % [
		int(result.get("cargo_minimum_integrity_percent", 0)),
		int(result.get("cargo_full_reward_integrity_percent", 0)),
	]
	requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	requirement_label.add_theme_color_override("font_color", Color(0.69, 0.78, 0.87))
	content.add_child(requirement_label)

	var message_label: Label = Label.new()
	message_label.text = str(result.get("message", ""))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)

	var payout_label: Label = Label.new()
	payout_label.text = "SALVAGED CREDITS  /  +%d CR\nROUTE CACHE  /  +%d CR\nCONTRACT PAY  /  %d CR\nROUTE BONUS  /  %d CR\nCARGO PENALTY  /  -%d CR\nTOTAL PAYOUT  /  %d CR" % [
		int(result.get("credits_collected", 0)),
		int(result.get("salvage_recovered", 0)),
		int(result.get("base_reward", 0)),
		int(result.get("route_bonus", 0)),
		int(result.get("cargo_penalty", 0)),
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
