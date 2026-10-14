extends Control

const HQ_SCENE_PATH: String = "res://scenes/hq.tscn"
const MISSION_FLIGHT_SCENE: String = "res://scenes/mission_flight.tscn"

var map_area: Control
var selected_node_label: Label
var selected_node_description: Label
var selected_node_details: Label
var action_button: Button
var status_label: Label
var node_positions: Dictionary = {}
var result_layer: Control


func _ready() -> void:
	if MissionRunState.active_mission == null:
		get_tree().change_scene_to_file(HQ_SCENE_PATH)
		return
	_build_interface()
	map_area.resized.connect(_refresh_map)
	call_deferred("_refresh_map")
	_refresh_selection()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.075)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = "NAVIGATION  /  PROCEDURAL ROUTE"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color(0.62, 0.86, 0.98))
	layout.add_child(heading)

	var mission_heading := Label.new()
	mission_heading.text = "%s  /  DESTINATION: %s" % [MissionRunState.active_mission.title.to_upper(), MissionRunState.active_mission.destination_name.to_upper()]
	mission_heading.add_theme_font_size_override("font_size", 13)
	mission_heading.add_theme_color_override("font_color", Color(0.76, 0.84, 0.91))
	layout.add_child(mission_heading)

	status_label = Label.new()
	status_label.text = "UNKNOWN SPACE AHEAD. ROUTE INTELLIGENCE IS REVEALED AS YOU PROGRESS."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.93, 0.75, 0.36))
	layout.add_child(status_label)

	map_area = Control.new()
	map_area.name = "ProceduralRouteMap"
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_area.custom_minimum_size = Vector2(860, 350)
	map_area.clip_contents = true
	layout.add_child(map_area)

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(0, 106)
	layout.add_child(details_panel)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	details_panel.add_child(details)

	selected_node_label = Label.new()
	selected_node_label.text = "SELECTED NODE  /  NONE"
	selected_node_label.add_theme_font_size_override("font_size", 16)
	details.add_child(selected_node_label)

	selected_node_description = Label.new()
	selected_node_description.text = "Hover over a revealed node to inspect available intelligence."
	selected_node_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_node_description.add_theme_color_override("font_color", Color(0.76, 0.84, 0.91))
	details.add_child(selected_node_description)

	selected_node_details = Label.new()
	selected_node_details.text = ""
	selected_node_details.add_theme_color_override("font_color", Color(0.53, 0.79, 0.91))
	details.add_child(selected_node_details)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)

	var back_button := Button.new()
	back_button.text = "ABANDON CONTRACT"
	back_button.custom_minimum_size = Vector2(190, 44)
	back_button.pressed.connect(_on_abandon_pressed)
	actions.add_child(back_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)

	action_button = Button.new()
	action_button.text = "SELECT A NODE"
	action_button.custom_minimum_size = Vector2(260, 44)
	action_button.disabled = true
	action_button.pressed.connect(_on_action_pressed)
	actions.add_child(action_button)


func _refresh_map() -> void:
	if not is_instance_valid(map_area):
		return
	for child: Node in map_area.get_children():
		map_area.remove_child(child)
		child.queue_free()
	node_positions.clear()

	var nodes: Array[MissionRouteNode] = MissionRunState.generated_route_nodes
	if nodes.is_empty():
		return
	var width: float = maxf(map_area.size.x, 860.0)
	var height: float = maxf(map_area.size.y, 350.0)
	var max_depth: int = 0
	for node: MissionRouteNode in nodes:
		max_depth = maxi(max_depth, node.depth)

	for node: MissionRouteNode in nodes:
		if not MissionRunState.is_node_visible(node.node_id):
			continue
		var nodes_in_layer: Array[MissionRouteNode] = []
		for other: MissionRouteNode in nodes:
			if other.depth == node.depth and MissionRunState.is_node_visible(other.node_id):
				nodes_in_layer.append(other)
		var x: float = 82.0 + (width - 164.0) * float(node.depth) / maxf(1.0, float(max_depth))
		var y: float = height * 0.5
		if nodes_in_layer.size() > 1:
			var visible_lane_index: int = nodes_in_layer.find(node)
			y = height * float(visible_lane_index + 1) / float(nodes_in_layer.size() + 1)
		node_positions[node.node_id] = Vector2(x, y)

	# Draw only connections whose endpoints have both been revealed.
	for node: MissionRouteNode in nodes:
		if not node_positions.has(node.node_id):
			continue
		for next_id: StringName in node.next_node_ids:
			if not node_positions.has(next_id):
				continue
			var line := Line2D.new()
			line.width = 3.0
			line.default_color = Color(0.22, 0.49, 0.65, 0.9)
			line.add_point(node_positions[node.node_id])
			line.add_point(node_positions[next_id])
			line.z_index = 0
			map_area.add_child(line)

	for node: MissionRouteNode in nodes:
		if not node_positions.has(node.node_id):
			continue
		var node_button := Button.new()
		node_button.position = node_positions[node.node_id] - Vector2(72, 25)
		node_button.size = Vector2(144, 50)
		node_button.z_index = 2
		node_button.text = _get_node_button_text(node)
		node_button.tooltip_text = _get_node_tooltip(node)
		node_button.pressed.connect(_on_node_selected.bind(node.node_id))
		node_button.mouse_entered.connect(_on_node_hovered.bind(node.node_id))
		if MissionRunState.is_node_completed(node.node_id):
			node_button.add_theme_color_override("font_color", Color(0.45, 0.9, 0.68))
			node_button.text = "✓  " + node_button.text
		elif node.node_id == MissionRunState.selected_route_node_id:
			node_button.add_theme_color_override("font_color", Color(0.65, 0.87, 1.0))
		map_area.add_child(node_button)


func _get_node_button_text(node: MissionRouteNode) -> String:
	if node.node_kind == MissionRouteNode.NodeKind.DESTINATION:
		return "DESTINATION\n%s" % node.title
	if node.node_kind == MissionRouteNode.NodeKind.START:
		return "ENTRY NODE\n%s" % node.title
	return "%s\nRISK %d" % [node.title, node.risk]


func _get_node_tooltip(node: MissionRouteNode) -> String:
	var state_text: String = "COMPLETED" if MissionRunState.is_node_completed(node.node_id) else "AVAILABLE"
	var reward_text: String = "DELIVERY DESTINATION" if node.node_kind == MissionRouteNode.NodeKind.DESTINATION else "ROUTE BONUS: +%d CR" % node.bonus_credits
	return "%s\n%s\nRISK: %d  /  %s\n%s" % [node.title, node.description, node.risk, state_text, reward_text]


func _on_node_hovered(node_id: StringName) -> void:
	var node: MissionRouteNode = MissionRunState.get_route_node(node_id)
	if node == null:
		return
	_show_node_details(node)


func _on_node_selected(node_id: StringName) -> void:
	if not MissionRunState.is_node_visible(node_id) or MissionRunState.is_node_completed(node_id):
		return
	MissionRunState.selected_route_node_id = node_id
	_refresh_map()
	_refresh_selection()


func _show_node_details(node: MissionRouteNode) -> void:
	selected_node_label.text = "NODE INTEL  /  %s" % node.title.to_upper()
	selected_node_description.text = node.description
	if node.node_kind == MissionRouteNode.NodeKind.DESTINATION:
		selected_node_details.text = "FINAL DELIVERY  /  %s" % MissionRunState.active_mission.destination_name
	else:
		var profile: String = "STANDARD PATROLS"
		if node.encounter_profile == MissionRouteNode.EncounterProfile.QUIET:
			profile = "LIGHT PATROLS"
		elif node.encounter_profile == MissionRouteNode.EncounterProfile.SALVAGE:
			profile = "HEAVY PATROLS  /  CACHE +50 CR"
		selected_node_details.text = "RISK %d  /  %s  /  ROUTE BONUS +%d CR" % [node.risk, profile, node.bonus_credits]


func _refresh_selection() -> void:
	var selected: MissionRouteNode = MissionRunState.get_route_node(MissionRunState.selected_route_node_id)
	if selected == null or not MissionRunState.is_node_visible(selected.node_id) or MissionRunState.is_node_completed(selected.node_id):
		action_button.disabled = true
		action_button.text = "SELECT A NODE"
		selected_node_label.text = "NODE INTEL  /  NO NODE SELECTED"
		selected_node_description.text = "Hover over the revealed node for intelligence, then select it to proceed."
		selected_node_details.text = ""
		return
	_show_node_details(selected)
	action_button.disabled = false
	action_button.text = "COMPLETE DELIVERY" if selected.node_kind == MissionRouteNode.NodeKind.DESTINATION else "DELIVER  /  ENTER NODE"


func _on_action_pressed() -> void:
	var selected: MissionRouteNode = MissionRunState.get_route_node(MissionRunState.selected_route_node_id)
	if selected == null or not MissionRunState.is_node_visible(selected.node_id) or MissionRunState.is_node_completed(selected.node_id):
		return
	if selected.node_kind == MissionRouteNode.NodeKind.DESTINATION:
		_complete_delivery()
		return
	MissionRunState.selected_branch_node_id = selected.node_id
	var error: Error = get_tree().change_scene_to_file(MISSION_FLIGHT_SCENE)
	if error != OK:
		status_label.text = "NAVIGATION ERROR  /  COULD NOT ENTER NODE (%d)" % error


func _complete_delivery() -> void:
	var mission: MissionDefinition = MissionRunState.active_mission
	if mission == null:
		return
	var integrity: float = MissionRunState.cargo_integrity_percent
	var success: bool = integrity >= float(mission.minimum_delivery_integrity_percent)
	var condition: String = "INTACT" if integrity >= float(mission.full_reward_integrity_percent) else ("DAMAGED" if integrity > 0.0 else "LOST")
	var message: String
	if not success:
		message = "Delivery rejected: cargo integrity is below the contract minimum of %d%%." % mission.minimum_delivery_integrity_percent
	elif integrity < float(mission.full_reward_integrity_percent):
		message = "Delivery accepted with damage. Contract payment reduced under the cargo condition clause."
	else:
		message = "Delivery accepted at %s. Cargo condition meets the full-reward requirement." % mission.destination_name
	var penalty: int = mission.damaged_cargo_payout_penalty_percent if success and integrity < float(mission.full_reward_integrity_percent) else 0
	var result: Dictionary = MissionRunState.finish_mission(
		success,
		MissionRunState.total_credits,
		mission.base_reward_credits,
		MissionRunState.accumulated_route_bonus,
		message,
		condition,
		penalty,
		MissionRunState.credits_collected_this_mission,
		MissionRunState.accumulated_salvage_cache
	)
	_show_result(result)


func _show_result(result: Dictionary) -> void:
	result_layer = Control.new()
	result_layer.name = "DeliverySummary"
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_layer.z_index = 20
	add_child(result_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.015, 0.028, 0.88)
	result_layer.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_top = -220
	panel.offset_right = 280
	panel.offset_bottom = 220
	result_layer.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var success: bool = bool(result.get("success", false))
	var heading := Label.new()
	heading.text = "DELIVERY COMPLETE" if success else "DELIVERY REJECTED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(0.42, 0.9, 0.68) if success else Color(1.0, 0.42, 0.42))
	content.add_child(heading)

	var contract := Label.new()
	contract.text = "%s\nDESTINATION  /  %s" % [str(result.get("mission_title", "")), str(result.get("destination_name", ""))]
	contract.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contract.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(contract)

	var cargo := Label.new()
	cargo.text = "CARGO  /  %s  /  %s  /  INTEGRITY %d%%" % [str(result.get("cargo_name", "")), str(result.get("cargo_condition", "")), roundi(float(result.get("cargo_integrity_percent", 0.0)))]
	cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cargo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(cargo)

	var report := Label.new()
	report.text = "%s\n\nSALVAGED CREDITS  +%d CR\nROUTE CACHE  +%d CR\nCONTRACT PAY  %d CR\nROUTE BONUS  %d CR\nCARGO PENALTY  -%d CR\nTOTAL PAYOUT  %d CR" % [
		str(result.get("message", "")),
		int(result.get("credits_collected", 0)),
		int(result.get("salvage_recovered", 0)),
		int(result.get("base_reward", 0)),
		int(result.get("route_bonus", 0)),
		int(result.get("cargo_penalty", 0)),
		int(result.get("payout", 0)),
	]
	report.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	content.add_child(report)

	var balance := Label.new()
	balance.text = "ACCOUNT BALANCE  /  %d CR" % int(result.get("total_credits", 0))
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 16)
	content.add_child(balance)

	var finish := Button.new()
	finish.text = "COMPLETE CONTRACT  /  RETURN TO HQ"
	finish.custom_minimum_size = Vector2(0, 44)
	finish.pressed.connect(_return_to_hq)
	content.add_child(finish)


func _on_abandon_pressed() -> void:
	var mission: MissionDefinition = MissionRunState.active_mission
	if mission == null:
		_return_to_hq()
		return
	var result := MissionRunState.finish_mission(
		false,
		MissionRunState.total_credits,
		0,
		0,
		"Mission abandoned from navigation. Contract payment was forfeited.",
		"UNKNOWN",
		0,
		MissionRunState.credits_collected_this_mission,
		0
	)
	_show_result(result)


func _return_to_hq() -> void:
	MissionRunState.clear_mission()
	get_tree().change_scene_to_file(HQ_SCENE_PATH)
