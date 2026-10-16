extends Node2D

## Gauntlet flight: a long seeded route split by must-destroy gates, under a run clock.
## RunDirector owns the pressure (comets, rocks, police, enemies, gates);
## AsteroidField owns the chunked rocks. This script wires them to the HUD,
## cargo integrity, delivery and the result screen.

const HQ_SCENE_PATH: String = "res://scenes/hq.tscn"
const OBJECTIVE_PICKUP_SCENE: PackedScene = preload("res://scenes/loot/mission_objective_pickup.tscn")
const MINIMAP_SCRIPT: Script = preload("res://scripts/ui/mission_minimap.gd")
const WORLD_SCRIPT: Script = preload("res://scripts/missions/mission_world.gd")

@onready var encounter_spawner: EncounterSpawner = $EncounterSpawner
@onready var player_ship: Ship = $PlayerShip

var mission: MissionDefinition
var profile: RunProfile
var layout: Dictionary = {}
var field: AsteroidField
var director: RunDirector
var minimap: MissionMinimap

var mission_resolved: bool = false
var resolution_pending: bool = false
var cargo_integrity: float = 100.0
var cargo_condition: String = "INTACT"
var credits_at_encounter_start: int = 0
var stolen_cargo_drop_spawned: bool = false

var abort_button: Button
var cargo_status_label: Label
var route_label: Label
var banner_label: Label
var destination_button: Button
var _banner_tween: Tween
var _hud_timer: float = 0.0


func _ready() -> void:
	mission = MissionRunState.active_mission
	if mission == null:
		push_warning("Mission flight opened without an active contract.")
		_return_to_hq()
		return

	var custom_profile: Variant = mission.get("run_profile")
	profile = custom_profile as RunProfile if custom_profile != null else RunProfile.new()
	# The map depends on the mission and (unless locked) the run seed.
	var layout_seed: int = 0 if profile.lock_layout_to_mission else MissionRunState.route_seed
	layout_seed = layout_seed ^ hash(String(mission.mission_id))
	layout = profile.generate_layout(layout_seed)

	var world: Node2D = Node2D.new()
	world.set_script(WORLD_SCRIPT)
	world.set("follow_target", player_ship)
	world.set("planet_center", profile.planet_center)
	world.set("destination", layout["destination"])
	world.set("station_name", mission.destination_name.to_upper())
	add_child(world)
	move_child(world, 0)
	player_ship.global_position = profile.start_position

	# The ship builder's saved hull and modules are loaded by Ship._ready().
	MissionRunState.restore_ship_condition(player_ship)
	MissionRunState.restore_ship_salvage(player_ship)
	cargo_integrity = MissionRunState.cargo_integrity_percent
	player_ship.credits = MissionRunState.total_credits
	credits_at_encounter_start = player_ship.credits
	player_ship.credits_changed.emit(player_ship.credits)
	player_ship.destroyed.connect(_on_player_destroyed, CONNECT_ONE_SHOT)
	player_ship.damaged.connect(_on_player_damaged)

	field = AsteroidField.new()
	field.name = "AsteroidField"
	field.player = player_ship
	field.field_seed = layout_seed
	add_child(field)

	director = RunDirector.new()
	director.name = "RunDirector"
	add_child(director)
	director.setup(player_ship, profile, layout, MissionRunState.route_seed, field, encounter_spawner.enemy_scenes)
	director.banner.connect(_show_banner)
	director.clock_expired.connect(_on_clock_expired)

	_build_flight_overlay()
	call_deferred("_spawn_available_objectives")
	if cargo_integrity <= 75.0:
		call_deferred("_spawn_stolen_cargo_drop")
	_show_banner("DEPARTURE CLEARED. THE RING IS NOT.")


func _process(delta: float) -> void:
	if mission_resolved or not is_instance_valid(player_ship) or director == null:
		return
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.15
		route_label.text = director.get_status_text()
	_update_arrival()


func _update_arrival() -> void:
	if director.arrival_ready():
		if not is_instance_valid(destination_button):
			_show_destination_button("COMPLETE DELIVERY  /  CONFIRM ARRIVAL")
	elif is_instance_valid(destination_button):
		destination_button.queue_free()
		destination_button = null
		resolution_pending = false
		if is_instance_valid(abort_button):
			abort_button.disabled = false


# ----------------------------------------------------------- objectives

func _spawn_available_objectives() -> void:
	if mission == null:
		return
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null or objective.objective_type not in [
			MissionObjectiveDefinition.ObjectiveType.COLLECT,
			MissionObjectiveDefinition.ObjectiveType.RESCUE,
		]:
			continue
		if objective.target_id == &"stolen_cargo":
			continue
		var progress: int = int(ObjectiveTracker.objective_progress.get(objective.objective_id, 0))
		var carried: int = MissionRunState.carried_mission_objective_ids.count(objective.objective_id)
		var remaining: int = objective.required_quantity - progress - carried
		for item_index: int in range(maxi(0, remaining)):
			var pickup: MissionObjectivePickup = OBJECTIVE_PICKUP_SCENE.instantiate() as MissionObjectivePickup
			if pickup == null:
				continue
			pickup.configure(objective)
			add_child(pickup)
			pickup.global_position = Vector2(760.0, 230.0) + Vector2(float(item_index % 4) * 30.0, float(item_index / 4) * 30.0)


func _spawn_stolen_cargo_drop() -> void:
	if stolen_cargo_drop_spawned or mission == null:
		return
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null or objective.objective_type != MissionObjectiveDefinition.ObjectiveType.COLLECT:
			continue
		if objective.target_id != &"stolen_cargo":
			continue
		var objective_progress: int = int(ObjectiveTracker.objective_progress.get(objective.objective_id, 0))
		var carried_quantity: int = MissionRunState.carried_mission_objective_ids.count(objective.objective_id)
		if objective_progress + carried_quantity >= objective.required_quantity:
			return
		var pickup: MissionObjectivePickup = OBJECTIVE_PICKUP_SCENE.instantiate() as MissionObjectivePickup
		if pickup == null:
			return
		pickup.configure(objective)
		add_child(pickup)
		pickup.global_position = player_ship.global_position + Vector2(48.0, 0.0)
		stolen_cargo_drop_spawned = true
		return


# ------------------------------------------------------------------ HUD

func _build_flight_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MissionOverlay"
	layer.layer = 10
	add_child(layer)

	var mission_label: Label = Label.new()
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
	mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(mission_label)

	cargo_status_label = Label.new()
	cargo_status_label.anchor_left = 1.0
	cargo_status_label.anchor_right = 1.0
	cargo_status_label.offset_left = -460.0
	cargo_status_label.offset_top = 48.0
	cargo_status_label.offset_right = -24.0
	cargo_status_label.offset_bottom = 74.0
	cargo_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cargo_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cargo_status_label.add_theme_font_size_override("font_size", 12)
	cargo_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cargo_status_label)
	_update_cargo_status()

	route_label = Label.new()
	route_label.anchor_right = 1.0
	route_label.offset_left = 24.0
	route_label.offset_top = 82.0
	route_label.offset_right = -300.0
	route_label.offset_bottom = 108.0
	route_label.add_theme_font_size_override("font_size", 13)
	route_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	route_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(route_label)

	var minimap_node: Control = Control.new()
	minimap_node.set_script(MINIMAP_SCRIPT)
	minimap = minimap_node as MissionMinimap
	minimap.name = "MissionMinimap"
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -274.0
	minimap.offset_top = 94.0
	minimap.offset_right = -20.0
	minimap.offset_bottom = 330.0
	minimap.player_ship = player_ship
	minimap.director = director
	layer.add_child(minimap)

	banner_label = Label.new()
	banner_label.anchor_left = 0.5
	banner_label.anchor_right = 0.5
	banner_label.anchor_top = 0.24
	banner_label.anchor_bottom = 0.24
	banner_label.offset_left = -520.0
	banner_label.offset_right = 520.0
	banner_label.offset_top = -30.0
	banner_label.offset_bottom = 30.0
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 24)
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
	banner_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.05, 0.01, 1.0))
	banner_label.add_theme_constant_override("shadow_offset_x", 2)
	banner_label.add_theme_constant_override("shadow_offset_y", 2)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_label.visible = false
	layer.add_child(banner_label)

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


func _show_banner(text: String) -> void:
	if not is_instance_valid(banner_label):
		return
	banner_label.text = text
	banner_label.visible = true
	banner_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.8)
	_banner_tween.tween_callback(func() -> void:
		if is_instance_valid(banner_label):
			banner_label.visible = false
	)


func _show_destination_button(button_text: String) -> void:
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
	destination_button.text = button_text
	destination_button.anchor_left = 0.5
	destination_button.anchor_right = 0.5
	destination_button.anchor_top = 1.0
	destination_button.anchor_bottom = 1.0
	destination_button.offset_left = -190.0
	destination_button.offset_top = -66.0
	destination_button.offset_right = 190.0
	destination_button.offset_bottom = -18.0
	destination_button.custom_minimum_size = Vector2(380, 44)
	destination_button.pressed.connect(_on_delivery_pressed)
	overlay.add_child(destination_button)


# -------------------------------------------------------- cargo and state

func _on_player_damaged(_amount: float, hull_damage: float, _shield_damage: float) -> void:
	if mission_resolved or mission == null:
		return
	if hull_damage > 0.0:
		var previous_integrity: float = cargo_integrity
		cargo_integrity = maxf(0.0, cargo_integrity - hull_damage * CargoRules.get_damage_sensitivity(mission))
		MissionRunState.cargo_integrity_percent = cargo_integrity
		if previous_integrity > 75.0 and cargo_integrity <= 75.0:
			_spawn_stolen_cargo_drop()
	if is_instance_valid(player_ship):
		MissionRunState.save_ship_condition(player_ship)
		MissionRunState.save_ship_salvage(player_ship)
	_update_cargo_status()
	if cargo_integrity <= 0.0:
		_resolve_mission(false, "Delivery failed: the shipment was destroyed and can no longer be delivered.")


func _update_cargo_status() -> void:
	if not is_instance_valid(cargo_status_label) or mission == null:
		return
	cargo_condition = CargoRules.get_condition(mission, cargo_integrity)
	cargo_status_label.text = "%s  /  %s  /  VALUE %d CR  /  INTEGRITY %d%%" % [
		mission.cargo_name.to_upper(), cargo_condition, mission.cargo_value_credits, roundi(cargo_integrity)
	]
	if cargo_condition == "INTACT":
		cargo_status_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.72))
	elif cargo_condition == "DAMAGED":
		cargo_status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	else:
		cargo_status_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))


func _on_player_destroyed() -> void:
	_resolve_mission(false, "Delivery failed: your ship was destroyed before the contract could be completed.")


func _on_clock_expired() -> void:
	_resolve_mission(false, "Run clock expired. The client has reassigned the shipment.")


func _on_abort_pressed() -> void:
	_resolve_mission(false, "Mission aborted by the pilot. Contract payment was forfeited.")


func _on_delivery_pressed() -> void:
	if mission_resolved or not director.arrival_ready():
		return
	if cargo_integrity <= 0.0 or not CargoRules.can_deliver(mission, cargo_integrity):
		_resolve_mission(false, CargoRules.get_delivery_failure_reason(mission, cargo_integrity))
		return
	MissionRunState.validate_returned_objectives(mission)
	if not ObjectiveTracker.can_deliver(mission):
		_resolve_mission(false, "Delivery failed: required recovered cargo or rescue objectives were not returned to %s." % mission.destination_name)
		return
	_resolve_mission(true, "Delivery confirmed at %s." % mission.destination_name)


func _resolve_mission(success: bool, result_message: String) -> void:
	if mission_resolved:
		return
	mission_resolved = true
	var progress_note: String = ""
	if director != null:
		director.active = false
		var is_best: bool = RunRecords.record(mission.mission_id, director.best_x, director.gates_cleared)
		progress_note = "  Reached %d M, gates cleared %d/%d.%s" % [
			roundi(director.best_x), director.gates_cleared, profile.gate_count, "  NEW BEST." if is_best else ""
		]
	if is_instance_valid(abort_button):
		abort_button.disabled = true

	if is_instance_valid(player_ship):
		# Returning to HQ always restores hull and shields.
		player_ship.current_hull = player_ship.max_hull
		player_ship.current_shield = player_ship.max_shield
		player_ship.hull_changed.emit(player_ship.current_hull, player_ship.max_hull)
		player_ship.shield_changed.emit(player_ship.current_shield, player_ship.max_shield)
		MissionRunState.save_ship_condition(player_ship)
		MissionRunState.save_ship_salvage(player_ship)
	MissionRunState.cargo_integrity_percent = cargo_integrity

	var base_reward: int = mission.base_reward_credits if mission != null else 0
	var credits_collected: int = MissionRunState.credits_collected_this_mission
	if is_instance_valid(player_ship):
		credits_collected += maxi(0, player_ship.credits - credits_at_encounter_start)
	var credits_before_payout: int = MissionRunState.total_credits
	if is_instance_valid(player_ship):
		credits_before_payout = player_ship.credits

	var result: Dictionary = MissionRunState.finish_mission(
		success,
		credits_before_payout,
		base_reward,
		0,
		result_message + progress_note,
		cargo_condition,
		CargoRules.get_payout_penalty_percent(mission, cargo_integrity),
		credits_collected,
		MissionRunState.accumulated_salvage_cache
	)

	if is_instance_valid(player_ship):
		player_ship.credits = MissionRunState.total_credits
		if player_ship.is_inside_tree():
			player_ship.credits_changed.emit(player_ship.credits)

	_show_result_screen(result)


# ---------------------------------------------------------------- result

func _show_result_screen(result: Dictionary) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MissionResultLayer"
	layer.layer = 20
	add_child(layer)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.015, 0.028, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270.0
	panel.offset_top = -230.0
	panel.offset_right = 270.0
	panel.offset_bottom = 230.0
	layer.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var success: bool = bool(result.get("success", false))
	content.add_child(_make_result_label(
		"DELIVERY COMPLETE" if success else "MISSION FAILED", 24,
		Color(0.42, 0.9, 0.68) if success else Color(1.0, 0.42, 0.42)
	))
	content.add_child(_make_result_label(str(result.get("message", "")), 13, Color(0.78, 0.88, 0.94)))
	content.add_child(_make_result_label("%s  /  %s" % [
		str(result.get("mission_title", "Unknown Contract")), str(result.get("destination_name", "Unknown Destination"))
	], 14, Color(0.85, 0.92, 0.96)))
	content.add_child(_make_result_label("%s  /  %s  /  INTEGRITY %d%%" % [
		str(result.get("cargo_name", "Cargo")), str(result.get("cargo_condition", "UNKNOWN")),
		roundi(float(result.get("cargo_integrity_percent", 0.0)))
	], 14, Color(0.85, 0.92, 0.96)))

	var objective_lines: PackedStringArray = []
	for entry: Dictionary in result.get("objective_snapshot", []):
		objective_lines.append("%s: %s (%d/%d)" % [
			str(entry.get("title", entry.get("id", "Objective"))), str(entry.get("state", "UNKNOWN")),
			int(entry.get("progress", 0)), int(entry.get("required_quantity", 1))
		])
	content.add_child(_make_result_label(
		"\n".join(objective_lines) if not objective_lines.is_empty() else "No additional objectives.", 14, Color(0.69, 0.78, 0.87)
	))
	content.add_child(_make_result_label(
		"SIDE EARNINGS +%d CR    CONTRACT %d CR\nBONUS %d CR    PENALTY -%d CR\nTOTAL PAYOUT %d CR" % [
			int(result.get("credits_collected", 0)) + int(result.get("salvage_recovered", 0)),
			int(result.get("base_reward", 0)), int(result.get("route_bonus", 0)),
			int(result.get("cargo_penalty", 0)), int(result.get("payout", 0))
		], 14, Color(1.0, 0.82, 0.3)
	))
	content.add_child(_make_result_label("ACCOUNT BALANCE / %d CR" % int(result.get("total_credits", 0)), 16, Color(0.85, 0.92, 0.96)))

	if not success:
		var retry_button: Button = Button.new()
		retry_button.text = "RETRY MISSION"
		retry_button.custom_minimum_size = Vector2(0, 40)
		retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		retry_button.pressed.connect(_retry_mission)
		content.add_child(retry_button)
	var return_button: Button = Button.new()
	return_button.text = "RETURN TO HQ"
	return_button.custom_minimum_size = Vector2(0, 44)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.pressed.connect(_return_to_hq)
	content.add_child(return_button)


func _make_result_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _retry_mission() -> void:
	if mission == null:
		_return_to_hq()
		return
	var retry_mission: MissionDefinition = mission
	if not ObjectiveTracker.begin_run(retry_mission):
		_return_to_hq()
		return
	if not MissionRunState.begin_mission(retry_mission):
		_return_to_hq()
		return
	if get_tree().change_scene_to_file("res://scenes/mission_flight.tscn") != OK:
		_return_to_hq()


func _return_to_hq() -> void:
	MissionRunState.clear_mission()
	get_tree().change_scene_to_file(HQ_SCENE_PATH)
