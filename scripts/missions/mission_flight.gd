extends Node2D

const HQ_SCENE_PATH: String = "res://scenes/hq.tscn"
const OBJECTIVE_PICKUP_SCENE: PackedScene = preload("res://scenes/loot/mission_objective_pickup.tscn")
const ASTEROID_SCENE: PackedScene = preload("res://scenes/mission_asteroid.tscn")
const MINIMAP_SCRIPT: Script = preload("res://scripts/ui/mission_minimap.gd")
const WORLD_SCRIPT: Script = preload("res://scripts/missions/mission_world.gd")
const ASTEROID_FIELD_SCRIPT: Script = preload("res://scripts/missions/mission_asteroid_field.gd")
const DESTINATION_POSITION: Vector2 = Vector2(2200.0, 0.0)
const ASTEROID_BELT_X: float = 1120.0
const ASTEROID_DETECTION_DISTANCE: float = 390.0
const DESTINATION_ARRIVAL_DISTANCE: float = 145.0

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
var stolen_cargo_drop_spawned: bool = false
var objective_timers: Dictionary = {}
var hazard_tick: float = 0.0
var runtime_phases: Array[MissionPhaseDefinition] = []
var phase_time_remaining: float = 60.0
var phase_targets_remaining: int = 0
var phase_bonus_credits: int = 0
var phase_mode: bool = true
var asteroid_belt_detected: bool = false
var asteroid_barrier: StaticBody2D
var asteroid_field_controller: Node2D
var asteroid_warning_label: Label
var minimap: MissionMinimap


func _ready() -> void:
	mission = MissionRunState.active_mission
	if mission == null:
		push_warning("Mission flight opened without an active contract.")
		_return_to_hq()
		return

	var world: Node2D = Node2D.new()
	world.set_script(WORLD_SCRIPT)
	add_child(world)
	move_child(world, 0)
	player_ship.global_position = Vector2(300.0, 0.0)

	# The ship builder's saved hull and modules are loaded by Ship._ready().
	# Carry the campaign wallet into the newly instantiated player ship.
	MissionRunState.restore_ship_condition(player_ship)
	MissionRunState.restore_ship_salvage(player_ship)
	cargo_integrity = MissionRunState.cargo_integrity_percent
	player_ship.credits = MissionRunState.total_credits
	credits_at_encounter_start = player_ship.credits
	player_ship.credits_changed.emit(player_ship.credits)
	player_ship.destroyed.connect(_on_player_destroyed, CONNECT_ONE_SHOT)
	player_ship.damaged.connect(_on_player_damaged)

	encounter_spawner.spawn_count = 4
	encounter_spawner.spawn_on_ready = false
	runtime_phases = _build_runtime_phases(mission)
	if runtime_phases.is_empty():
		push_warning("Mission has no usable phases. Returning to HQ.")
		_return_to_hq()
		return
	MissionRunState.current_phase_index = clampi(MissionRunState.current_phase_index, 0, runtime_phases.size() - 1)
	_build_flight_overlay()
	call_deferred("_spawn_available_objectives")
	if cargo_integrity <= 75.0:
		call_deferred("_spawn_stolen_cargo_drop")
	call_deferred("_start_current_phase")


func _process(delta: float) -> void:
	if mission_resolved or not is_instance_valid(player_ship):
		return
	if phase_mode:
		_process_current_phase(delta)
		return
	if selected_branch == null:
		return
	for objective_id: Variant in objective_timers.keys():
		var timer: Dictionary = objective_timers[objective_id]
		timer["remaining"] = float(timer.get("remaining", 0.0)) - delta
		objective_timers[objective_id] = timer
		var remaining: float = maxf(0.0, float(timer["remaining"]))
		if is_instance_valid(route_label):
			route_label.text = "%s  /  %.1f SEC" % [str(timer.get("title", "OBJECTIVE")).to_upper(), remaining]
		if remaining > 0.0:
			continue
		if int(timer.get("type", -1)) == MissionObjectiveDefinition.ObjectiveType.SURVIVE:
			ObjectiveTracker.add_progress(mission, objective_id, 1)
			objective_timers.erase(objective_id)
		else:
			ObjectiveTracker.fail_objective(mission, objective_id)
			objective_timers.erase(objective_id)
			_resolve_mission(false, "Deadline missed: %s was not completed in time." % str(timer.get("title", "Objective")))
			return
	if selected_branch.node_kind == MissionRouteNode.NodeKind.ENCOUNTER and selected_branch.risk >= 3:
		hazard_tick += delta
		var interval: float = 4.0 if selected_branch.risk < 5 else 2.8
		if hazard_tick >= interval:
			hazard_tick = 0.0
			player_ship.take_damage(2.0 + float(selected_branch.risk) * 0.8)
			if is_instance_valid(route_label):
				route_label.text = "ENVIRONMENTAL EXPOSURE  /  RISK %d" % selected_branch.risk


func _build_runtime_phases(contract: MissionDefinition) -> Array[MissionPhaseDefinition]:
	var phases: Array[MissionPhaseDefinition] = []
	if contract != null and not contract.phases.is_empty():
		for authored_phase: MissionPhaseDefinition in contract.phases:
			if authored_phase != null:
				phases.append(authored_phase)
		return phases

	var asteroid_phase := MissionPhaseDefinition.new()
	asteroid_phase.phase_id = &"asteroid_bounty"
	asteroid_phase.title = "Asteroid Bounty"
	asteroid_phase.briefing = "Break apart the bounty rocks. Each asteroid takes two hits and drops one credit."
	asteroid_phase.phase_type = MissionPhaseDefinition.PhaseType.ASTEROID_BOUNTY
	asteroid_phase.duration_seconds = 60
	asteroid_phase.target_count = 5
	phases.append(asteroid_phase)

	var pirate_phase := MissionPhaseDefinition.new()
	pirate_phase.phase_id = &"pirate_ambush"
	pirate_phase.title = "Pirate Ambush"
	pirate_phase.briefing = "Hostiles inbound. Clear the ambush using your equipped weapons."
	pirate_phase.phase_type = MissionPhaseDefinition.PhaseType.PIRATE_AMBUSH
	pirate_phase.duration_seconds = 60
	pirate_phase.target_count = 4
	phases.append(pirate_phase)

	var delivery_phase := MissionPhaseDefinition.new()
	delivery_phase.phase_id = &"final_delivery"
	delivery_phase.title = "Final Delivery"
	delivery_phase.briefing = "The route is clear. Complete delivery before the phase timer expires."
	delivery_phase.phase_type = MissionPhaseDefinition.PhaseType.DELIVERY
	delivery_phase.duration_seconds = 60
	delivery_phase.target_count = 1
	phases.append(delivery_phase)
	return phases


func _process_current_phase(delta: float) -> void:
	if runtime_phases.is_empty() or MissionRunState.current_phase_index >= runtime_phases.size():
		return
	phase_time_remaining = maxf(0.0, phase_time_remaining - delta)
	var phase: MissionPhaseDefinition = runtime_phases[MissionRunState.current_phase_index]
	if is_instance_valid(route_label):
		route_label.text = "PHASE %d/%d  /  %s  /  %.1f SEC" % [
			MissionRunState.current_phase_index + 1,
			runtime_phases.size(),
			phase.title.to_upper(),
			phase_time_remaining,
		]
	if phase_time_remaining <= 0.0:
		_resolve_mission(false, "Phase timer expired: %s was not completed in time." % phase.title)


func _start_current_phase() -> void:
	if mission_resolved or runtime_phases.is_empty():
		return
	if MissionRunState.current_phase_index >= runtime_phases.size():
		_resolve_mission(true, "All mission phases completed. Delivery confirmed.")
		return
	resolution_pending = false
	if is_instance_valid(destination_button):
		destination_button.queue_free()
		destination_button = null
	var phase: MissionPhaseDefinition = runtime_phases[MissionRunState.current_phase_index]
	phase_time_remaining = float(phase.duration_seconds)
	phase_targets_remaining = 0
	if is_instance_valid(abort_button):
		abort_button.disabled = false
	if is_instance_valid(route_label):
		route_label.text = "PHASE %d/%d  /  %s  /  %.1f SEC" % [
			MissionRunState.current_phase_index + 1,
			runtime_phases.size(),
			phase.title.to_upper(),
			phase_time_remaining,
		]
	match phase.phase_type:
		MissionPhaseDefinition.PhaseType.ASTEROID_BOUNTY:
			phase_targets_remaining = phase.target_count
			for index: int in range(phase.target_count):
				var asteroid: Ship = ASTEROID_SCENE.instantiate() as Ship
				if asteroid == null:
					continue
				add_child(asteroid)
				var angle: float = TAU * float(index) / float(maxi(1, phase.target_count))
				var radius: float = 190.0 + float(index % 3) * 28.0
				asteroid.global_position = player_ship.global_position + Vector2.RIGHT.rotated(angle) * radius
				asteroid.destroyed.connect(_on_phase_target_destroyed, CONNECT_ONE_SHOT)
			if get_tree().get_nodes_in_group("mission_asteroid").is_empty():
				_resolve_mission(false, "Asteroid bounty targets could not be created.")
		MissionPhaseDefinition.PhaseType.PIRATE_AMBUSH:
			encounter_spawner.spawn_count = phase.target_count
			var hostiles: Array[Ship] = encounter_spawner.spawn_encounter()
			phase_targets_remaining = hostiles.size()
			for hostile: Ship in hostiles:
				hostile.destroyed.connect(_on_phase_target_destroyed, CONNECT_ONE_SHOT)
			if phase_targets_remaining <= 0:
				_resolve_mission(false, "Pirate ambush could not be spawned.")
		MissionPhaseDefinition.PhaseType.DELIVERY:
			_show_destination_button("COMPLETE DELIVERY  /  CONFIRM ARRIVAL")


func _on_phase_target_destroyed() -> void:
	if mission_resolved or runtime_phases.is_empty():
		return
	phase_targets_remaining = maxi(0, phase_targets_remaining - 1)
	var phase: MissionPhaseDefinition = runtime_phases[MissionRunState.current_phase_index]
	if phase.phase_type == MissionPhaseDefinition.PhaseType.PIRATE_AMBUSH:
		ObjectiveTracker.report_enemy_destroyed(mission, phase_targets_remaining)
	if is_instance_valid(route_label):
		route_label.text = "%s  /  %d TARGETS REMAINING  /  %.1f SEC" % [
			phase.title.to_upper(),
			phase_targets_remaining,
			phase_time_remaining,
		]
	if phase_targets_remaining <= 0:
		_complete_current_phase()


func _complete_current_phase() -> void:
	if mission_resolved or runtime_phases.is_empty():
		return
	var phase: MissionPhaseDefinition = runtime_phases[MissionRunState.current_phase_index]
	if not MissionRunState.completed_phase_ids.has(phase.phase_id):
		MissionRunState.completed_phase_ids.append(phase.phase_id)
	phase_bonus_credits += maxi(0, phase.bonus_credits)
	MissionRunState.current_phase_index += 1
	if is_instance_valid(destination_button):
		destination_button.queue_free()
		destination_button = null
	call_deferred("_start_current_phase")


func _on_phase_delivery_pressed() -> void:
	if mission_resolved or runtime_phases.is_empty():
		return
	var phase: MissionPhaseDefinition = runtime_phases[MissionRunState.current_phase_index]
	if phase.phase_type != MissionPhaseDefinition.PhaseType.DELIVERY:
		return
	if cargo_integrity <= 0.0 or not CargoRules.can_deliver(mission, cargo_integrity):
		_resolve_mission(false, CargoRules.get_delivery_failure_reason(mission, cargo_integrity))
		return
	MissionRunState.validate_returned_objectives(mission)
	if not ObjectiveTracker.can_deliver(mission):
		_resolve_mission(false, "Delivery failed: required recovered cargo or rescue objectives were not returned to %s." % mission.destination_name)
		return
	_complete_current_phase()
	_resolve_mission(true, "Delivery confirmed at %s." % mission.destination_name)


func _start_timed_objectives() -> void:
	if mission == null:
		return
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective == null or not objective.required:
			continue
		if objective.objective_type not in [MissionObjectiveDefinition.ObjectiveType.SURVIVE, MissionObjectiveDefinition.ObjectiveType.ESCAPE, MissionObjectiveDefinition.ObjectiveType.INTERCEPT]:
			continue
		if not ObjectiveTracker.activate_objective(mission, objective.objective_id):
			continue
		var duration: float = float(objective.deadline_seconds)
		if duration <= 0.0:
			duration = 10.0 if objective.objective_type == MissionObjectiveDefinition.ObjectiveType.SURVIVE else 20.0
		objective_timers[objective.objective_id] = {"remaining": duration, "type": objective.objective_type, "title": objective.title}


func _start_selected_objective() -> void:
	if mission_resolved or selected_branch == null:
		return
	# Preserve legacy service nodes while new authored nodes use explicit objectives.
	if selected_branch.node_kind == MissionRouteNode.NodeKind.SERVICE:
		_start_service_node()
		return
	match selected_branch.objective_type:
		MissionRouteNode.ObjectiveType.COMBAT:
			_start_encounter()
		MissionRouteNode.ObjectiveType.SERVICE:
			_start_service_node()
		MissionRouteNode.ObjectiveType.SALVAGE_RECOVERY, MissionRouteNode.ObjectiveType.RESCUE:
			if selected_branch.objective_type == MissionRouteNode.ObjectiveType.SALVAGE_RECOVERY:
				_show_destination_button("RETURN RECOVERED CARGO  /  CONTINUE")
			else:
				_show_destination_button("RETURN RESCUEES  /  CONTINUE")
		_:
			push_warning("Objective '%s' is not implemented yet." % MissionRouteNode.ObjectiveType.keys()[selected_branch.objective_type])
			_resolve_mission(false, "Dispatch failed: this route objective is not available in the current build.")



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


func _get_contact_count(node: MissionRouteNode) -> int:
	if node.encounter_profile == MissionRouteNode.EncounterProfile.QUIET:
		return clampi(node.risk, 1, 2)
	if node.encounter_profile == MissionRouteNode.EncounterProfile.SALVAGE:
		return clampi(1 + node.risk, 2, 4)
	return clampi(1 + node.risk, 2, 4)


func _start_service_node() -> void:
	if mission_resolved:
		return
	if is_instance_valid(player_ship):
		player_ship.current_hull = minf(player_ship.max_hull, player_ship.current_hull + player_ship.max_hull * 0.35)
		player_ship.current_shield = player_ship.max_shield
		player_ship.hull_changed.emit(player_ship.current_hull, player_ship.max_hull)
		player_ship.shield_changed.emit(player_ship.current_shield, player_ship.max_shield)
		MissionRunState.save_ship_condition(player_ship)
	if is_instance_valid(route_label):
		route_label.text = "SERVICE STOP  /  HULL REPAIRED 35%  /  SHIELDS RESTORED"
	if is_instance_valid(abort_button):
		abort_button.disabled = true
	_show_destination_button("COMPLETE SERVICE STOP  /  RETURN TO ROUTE MAP")


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
	ObjectiveTracker.report_enemy_destroyed(mission, remaining_enemies)
	if remaining_enemies == 0:
		for objective: MissionObjectiveDefinition in mission.objectives:
			if objective != null and objective.objective_type == MissionObjectiveDefinition.ObjectiveType.INTERCEPT:
				ObjectiveTracker.add_progress(mission, objective.objective_id, 1)
				objective_timers.erase(objective.objective_id)
		# Leave flight and loot pickups active until the pilot chooses to proceed.
		_show_destination_button()


func _on_player_destroyed() -> void:
	_resolve_mission(false, "Delivery failed: your ship was destroyed before the contract could be completed.")


func _on_abort_pressed() -> void:
	_resolve_mission(false, "Mission aborted by the pilot. Contract payment was forfeited.")


func _on_node_completed() -> void:
	if mission_resolved or mission == null or selected_branch == null:
		return
	if cargo_integrity <= 0.0:
		_resolve_mission(false, CargoRules.get_delivery_failure_reason(mission, cargo_integrity))
		return
	for objective: MissionObjectiveDefinition in mission.objectives:
		if objective != null and objective.objective_type == MissionObjectiveDefinition.ObjectiveType.ESCAPE:
			ObjectiveTracker.add_progress(mission, objective.objective_id, 1)
			objective_timers.erase(objective.objective_id)
	if selected_branch.node_kind == MissionRouteNode.NodeKind.DESTINATION:
		MissionRunState.validate_returned_objectives(mission)
		if not ObjectiveTracker.can_deliver(mission):
			_resolve_mission(false, "Delivery failed: required recovered cargo or rescue objectives were not returned to %s." % mission.destination_name)
			return
		if not CargoRules.can_deliver(mission, cargo_integrity):
			_resolve_mission(false, CargoRules.get_delivery_failure_reason(mission, cargo_integrity))
			return
	if is_instance_valid(player_ship):
		var credits_after_node: int = player_ship.credits
		var credits_before_node: int = MissionRunState.total_credits
		MissionRunState.total_credits = credits_after_node
		MissionRunState.add_node_rewards(selected_branch, credits_before_node, credits_after_node)
		MissionRunState.save_ship_condition(player_ship)
		MissionRunState.save_ship_salvage(player_ship)
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
		MissionRunState.save_ship_salvage(player_ship)
	MissionRunState.cargo_integrity_percent = cargo_integrity

	var base_reward: int = mission.base_reward_credits if mission != null else 0
	var route_bonus: int = phase_bonus_credits + (selected_branch.bonus_credits if selected_branch != null else 0)
	var credits_collected: int = MissionRunState.credits_collected_this_mission
	if is_instance_valid(player_ship):
		credits_collected += maxi(0, player_ship.credits - credits_at_encounter_start)

	# Salvage-profile routes include a recoverable cache, paid only when the delivery succeeds.
	var salvage_recovered: int = MissionRunState.accumulated_salvage_cache
	var credits_before_payout: int = MissionRunState.total_credits
	if is_instance_valid(player_ship):
		credits_before_payout = player_ship.credits

	var cargo_penalty_percent: int = CargoRules.get_payout_penalty_percent(mission, cargo_integrity)
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


func _show_destination_button(button_text: String = "RETURN TO ROUTE MAP  /  NODE COMPLETE") -> void:
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
	if phase_mode:
		destination_button.pressed.connect(_on_phase_delivery_pressed)
	else:
		destination_button.pressed.connect(_on_node_completed)
	overlay.add_child(destination_button)


func _show_result_screen(result: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.name = "MissionResultLayer"
	layer.layer = 20
	add_child(layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.015, 0.028, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270.0
	panel.offset_top = -205.0
	panel.offset_right = 270.0
	panel.offset_bottom = 205.0
	layer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)
	var success: bool = bool(result.get("success", false))
	var heading := Label.new()
	heading.text = "DELIVERY COMPLETE" if success else "MISSION FAILED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(0.42, 0.9, 0.68) if success else Color(1.0, 0.42, 0.42))
	layout.add_child(heading)
	var contract := Label.new()
	contract.text = "%s  /  %s" % [str(result.get("mission_title", "Unknown Contract")), str(result.get("destination_name", "Unknown Destination"))]
	contract.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(contract)
	var cargo := Label.new()
	cargo.text = "%s  /  %s  /  INTEGRITY %d%%" % [str(result.get("cargo_name", "Cargo")), str(result.get("cargo_condition", "UNKNOWN")), roundi(float(result.get("cargo_integrity_percent", 0.0)))]
	cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(cargo)
	var objective_lines: PackedStringArray = []
	for entry: Dictionary in result.get("objective_snapshot", []):
		objective_lines.append("%s: %s (%d/%d)" % [str(entry.get("title", entry.get("id", "Objective"))), str(entry.get("state", "UNKNOWN")), int(entry.get("progress", 0)), int(entry.get("required_quantity", 1))])
	var objectives := Label.new()
	objectives.text = "\n".join(objective_lines) if not objective_lines.is_empty() else "No additional objectives."
	objectives.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objectives.add_theme_color_override("font_color", Color(0.69, 0.78, 0.87))
	layout.add_child(objectives)
	var payout := Label.new()
	payout.text = "SIDE EARNINGS +%d CR    CONTRACT %d CR\nBONUS %d CR    PENALTY -%d CR\nTOTAL PAYOUT %d CR" % [int(result.get("credits_collected", 0)) + int(result.get("salvage_recovered", 0)), int(result.get("base_reward", 0)), int(result.get("route_bonus", 0)), int(result.get("cargo_penalty", 0)), int(result.get("payout", 0))]
	payout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payout.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	layout.add_child(payout)
	var balance := Label.new()
	balance.text = "ACCOUNT BALANCE / %d CR" % int(result.get("total_credits", 0))
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 16)
	layout.add_child(balance)
	if not success:
		var retry_button := Button.new()
		retry_button.text = "RETRY MISSION"
		retry_button.custom_minimum_size = Vector2(0, 40)
		retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		retry_button.pressed.connect(_retry_mission)
		layout.add_child(retry_button)

	var return_button := Button.new()
	return_button.text = "RETURN TO HQ"
	return_button.custom_minimum_size = Vector2(0, 44)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	return_button.pressed.connect(_return_to_hq)
	layout.add_child(return_button)


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
	var change_error: Error = get_tree().change_scene_to_file("res://scenes/mission_flight.tscn")
	if change_error != OK:
		_return_to_hq()


func _return_to_hq() -> void:
	MissionRunState.clear_mission()
	get_tree().change_scene_to_file(HQ_SCENE_PATH)
