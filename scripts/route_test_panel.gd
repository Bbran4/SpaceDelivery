extends Control

const MISSION_PATHS: Array[String] = [
	"res://resources/missions/fragile_relay_components.tres",
	"res://resources/missions/priority_medical_shipment.tres",
]

var results: RichTextLabel
var run_1000_button: Button
var run_5000_button: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = "ROUTE GENERATOR TESTS"
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)

	var explanation := Label.new()
	explanation.text = "Generate seeded routes and inspect graph validity, branches, risk pacing, service coverage, and rewards."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(explanation)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)

	run_1000_button = Button.new()
	run_1000_button.text = "Run 1,000 Seeds"
	run_1000_button.pressed.connect(func() -> void: _run_batch(1000))
	buttons.add_child(run_1000_button)

	run_5000_button = Button.new()
	run_5000_button.text = "Run 5,000 Seeds"
	run_5000_button.pressed.connect(func() -> void: _run_batch(5000))
	buttons.add_child(run_5000_button)

	var back_button := Button.new()
	back_button.text = "Back to HQ"
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/hq.tscn"))
	buttons.add_child(back_button)

	results = RichTextLabel.new()
	results.bbcode_enabled = true
	results.fit_content = false
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.scroll_active = true
	results.text = "Choose a seed batch to begin."
	column.add_child(results)


func _run_batch(seed_count: int) -> void:
	run_1000_button.disabled = true
	run_5000_button.disabled = true
	results.text = "Running %d seeds per mission...\n" % seed_count
	var output := ""
	for mission_path: String in MISSION_PATHS:
		var mission: MissionDefinition = load(mission_path) as MissionDefinition
		if mission == null:
			output += "[color=red]Could not load mission: %s[/color]\n" % mission_path
			continue
		var failures: int = 0
		var first_risk_high: int = 0
		var no_service: int = 0
		var duplicate_siblings: int = 0
		var node_count: int = 0
		var exit_total: int = 0
		var single_exit_count: int = 0
		var min_exits: int = 2147483647
		var min_path_risk: int = 2147483647
		var max_path_risk: int = 0
		var min_path_bonus: int = 2147483647
		var max_path_bonus: int = 0
		var worst_streak: int = 0
		var failure_examples: Array[String] = []

		for seed_value: int in range(1, seed_count + 1):
			var route: Array[MissionRouteNode] = RouteGenerator.generate_route(mission, seed_value)
			var errors: PackedStringArray = RouteGenerator.validate_route(route)
			if not errors.is_empty():
				failures += 1
				if failure_examples.size() < 5:
					failure_examples.append("Seed %d: %s" % [seed_value, "; ".join(errors)])
			var by_id: Dictionary = {}
			var layers: Dictionary = {}
			var service_found := false
			for node: MissionRouteNode in route:
				by_id[node.node_id] = node
				if not layers.has(node.depth):
					layers[node.depth] = []
				layers[node.depth].append(node)
				node_count += 1
				exit_total += node.next_node_ids.size()
				if node.node_kind != MissionRouteNode.NodeKind.DESTINATION:
					min_exits = mini(min_exits, node.next_node_ids.size())
				if node.next_node_ids.size() == 1:
					single_exit_count += 1
				if node.node_kind == MissionRouteNode.NodeKind.SERVICE:
					service_found = true
			if not service_found:
				no_service += 1

			var first_encounter: MissionRouteNode = null
			for node: MissionRouteNode in route:
				if node.node_kind == MissionRouteNode.NodeKind.ENCOUNTER and (first_encounter == null or node.depth < first_encounter.depth):
					first_encounter = node
			if first_encounter != null and first_encounter.risk >= 3:
				first_risk_high += 1

			var duplicate_found := false
			for depth: int in layers:
				var signatures: Dictionary = {}
				for node: MissionRouteNode in layers[depth]:
					if node.node_kind != MissionRouteNode.NodeKind.ENCOUNTER:
						continue
					var signature := "%d:%d" % [int(node.encounter_profile), node.risk]
					if signatures.has(signature):
						duplicate_found = true
					signatures[signature] = true
			if duplicate_found:
				duplicate_siblings += 1

			var stack: Array[Dictionary] = [{"id": route[0].node_id, "risk": 0, "bonus": 0, "streak": 0}]
			while not stack.is_empty():
				var item: Dictionary = stack.pop_back()
				var node: MissionRouteNode = by_id.get(StringName(item["id"])) as MissionRouteNode
				if node == null:
					continue
				var path_risk: int = int(item["risk"]) + node.risk
				var path_bonus: int = int(item["bonus"]) + node.bonus_credits
				var streak: int = int(item["streak"]) + 1 if node.risk >= 3 else 0
				worst_streak = maxi(worst_streak, streak)
				if node.node_kind == MissionRouteNode.NodeKind.DESTINATION:
					min_path_risk = mini(min_path_risk, path_risk)
					max_path_risk = maxi(max_path_risk, path_risk)
					min_path_bonus = mini(min_path_bonus, path_bonus)
					max_path_bonus = maxi(max_path_bonus, path_bonus)
				else:
					for next_id: StringName in node.next_node_ids:
						stack.append({"id": next_id, "risk": path_risk, "bonus": path_bonus, "streak": streak})
			if seed_value % 100 == 0:
				results.text = "Testing %s, seed %d / %d..." % [mission.title, seed_value, seed_count]
				await get_tree().process_frame

		var share_single: float = 100.0 * float(single_exit_count) / float(maxi(1, node_count))
		var average_exits: float = float(exit_total) / float(maxi(1, node_count))
		output += "[b]%s[/b]\n" % mission.title
		output += "Routes: %d | Validation failures: %d\n" % [seed_count, failures]
		output += "First encounter risk >= 3: %d (%.2f%%)\n" % [first_risk_high, 100.0 * float(first_risk_high) / float(seed_count)]
		output += "Exits per node: average %.2f | minimum %d | single-exit nodes %.2f%%\n" % [average_exits, min_exits, share_single]
		output += "Routes with duplicate sibling profile/risk: %d (%.2f%%)\n" % [duplicate_siblings, 100.0 * float(duplicate_siblings) / float(seed_count)]
		output += "Routes without service stop: %d (%.2f%%)\n" % [no_service, 100.0 * float(no_service) / float(seed_count)]
		output += "Worst consecutive risk-3+ streak: %d\n" % worst_streak
		output += "Path risk min/max: %d / %d | Path bonus min/max: %d / %d\n" % [min_path_risk, max_path_risk, min_path_bonus, max_path_bonus]
		for example: String in failure_examples:
			output += "[color=red]%s[/color]\n" % example
		output += "\n"
		results.text = output
		await get_tree().process_frame

	results.text = output + "[b]Batch complete.[/b]"
	run_1000_button.disabled = false
	run_5000_button.disabled = false
