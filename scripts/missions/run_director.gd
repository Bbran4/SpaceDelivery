extends Node2D
class_name RunDirector

## Runs the gauntlet: run clock, gates, comets and fast rocks that knock the ship
## off course, police checkpoints, and a capped enemy budget that grows with chaos.
## Rock placement lives in AsteroidField; this node supplies its density function.

signal banner(text: String)
signal gate_cleared(index: int, gate_name: String)
signal clock_expired

const GATE_SPAWN_DISTANCE: float = 2600.0
const RECYCLE_DISTANCE: float = 2300.0
const ARRIVAL_DISTANCE: float = 240.0
const GATE_WEAPONS: Array[String] = [
	"res://resources/modules/basic_laser_module.tres",
	"res://resources/modules/rapid_laser_module.tres",
	"res://resources/modules/heavy_cannon_module.tres",
	"res://resources/modules/long_range_lance_module.tres",
]
## Enemy and event pressure multiplier per zone kind.
const KIND_PRESSURE: Dictionary = {
	RunProfile.ZoneKind.RING: 0.0,
	RunProfile.ZoneKind.DRIFT: 0.55,
	RunProfile.ZoneKind.CUSTOMS: 0.7,
	RunProfile.ZoneKind.WRECKS: 1.0,
	RunProfile.ZoneKind.BLOCKADE: 1.25,
}
## Static drifting rock density per zone kind (0..1 spawn chance per candidate).
const DRIFT_DENSITY: Dictionary = {
	RunProfile.ZoneKind.RING: 0.0,
	RunProfile.ZoneKind.DRIFT: 0.10,
	RunProfile.ZoneKind.CUSTOMS: 0.05,
	RunProfile.ZoneKind.WRECKS: 0.20,
	RunProfile.ZoneKind.BLOCKADE: 0.14,
}


class Streak:
	var comet: bool = true
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var aim: Vector2 = Vector2.ZERO
	var radius: float = 10.0
	var wait: float = 0.0
	var age: float = 0.0
	var hit: bool = false
	var rotation_angle: float = 0.0
	var spin: float = 0.0


var player: Ship
var profile: RunProfile
var layout: Dictionary = {}
var field: AsteroidField
var enemy_scenes: Array[PackedScene] = []
var active: bool = true

var elapsed: float = 0.0
var clock_remaining: float = 0.0
var gates_cleared: int = 0
var best_x: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _checkpoints: Array = []
var _gates: Dictionary = {}
var _streaks: Array = []
var _comet_timer: float = 6.0
var _rock_timer: float = 5.0
var _enemy_timer: float = 3.0
var _knock: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _inspect_left: float = 0.0
var _last_player_x: float = 0.0
var _announced_zone: int = -1
var _comet_announced: bool = false


func setup(
	p_player: Ship, p_profile: RunProfile, p_layout: Dictionary, p_seed: int,
	p_field: AsteroidField, p_enemy_scenes: Array[PackedScene]
) -> void:
	player = p_player
	profile = p_profile
	layout = p_layout
	field = p_field
	enemy_scenes = p_enemy_scenes
	rng.seed = p_seed ^ 0x5bd1e995
	clock_remaining = profile.run_clock_seconds
	_checkpoints = layout["checkpoints"]
	_last_player_x = player.global_position.x
	z_index = 3
	field.density_source = rock_density
	field.rock_struck.connect(_on_rock_struck)


# ----------------------------------------------------------------- queries

func chaos_at(x: float) -> float:
	var ring_end: float = float(layout["ring_end"])
	if x <= ring_end:
		return 0.0
	var progress: float = (x - ring_end) / maxf(1.0, float(layout["length"]) - ring_end)
	return profile.chaos_for_progress(progress)


## Chaos plus a spike while approaching an unbroken gate.
func pressure_at(x: float) -> float:
	var chaos: float = chaos_at(x)
	if gates_cleared < profile.gate_count:
		var zones: Array = layout["zones"]
		var gate_x: float = float((zones[gates_cleared + 1] as Dictionary)["gate_x"])
		if gate_x - x > 0.0 and gate_x - x < 1500.0:
			chaos = minf(1.0, chaos + 0.15)
	return chaos


func rock_density(position_value: Vector2) -> float:
	var density: float = 0.0
	var ring_offset: float = absf(position_value.distance_to(profile.planet_center) - profile.ring_radius)
	if ring_offset < profile.ring_half_width:
		var edge: float = ring_offset / profile.ring_half_width
		density = 0.9 * (1.0 - edge * edge * edge)
	var zone: Dictionary = RunProfile.zone_at(layout, position_value.x)
	var kind_density: float = float(DRIFT_DENSITY.get(int(zone["kind"]), 0.0))
	density = maxf(density, kind_density * (0.6 + chaos_at(position_value.x) * 0.8))
	return density


func arrival_ready() -> bool:
	if not is_instance_valid(player) or gates_cleared < profile.gate_count:
		return false
	var destination: Vector2 = layout["destination"]
	return player.global_position.distance_to(destination) <= ARRIVAL_DISTANCE


func get_status_text() -> String:
	if not is_instance_valid(player):
		return ""
	var x: float = player.global_position.x
	var zone: Dictionary = RunProfile.zone_at(layout, x)
	var zones: Array = layout["zones"]
	var target_name: String = "DESTINATION"
	var target_x: float = float(layout["length"])
	if gates_cleared < profile.gate_count:
		var gate_zone: Dictionary = zones[gates_cleared + 1]
		target_name = str(gate_zone["gate_name"]).to_upper()
		target_x = float(gate_zone["gate_x"])
	var minutes: int = floori(clock_remaining / 60.0)
	var seconds: int = floori(fmod(clock_remaining, 60.0))
	return "ZONE %d  /  %s     CLOCK %d:%02d     GATES %d/%d     NEXT: %s  %d M" % [
		int(zone["index"]) + 1, str(zone["name"]).to_upper(), minutes, seconds,
		gates_cleared, profile.gate_count, target_name, maxi(0, roundi(target_x - x)),
	]


# -------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player) or player.is_destroyed:
		return
	elapsed += delta
	clock_remaining = maxf(0.0, clock_remaining - delta)
	best_x = maxf(best_x, player.global_position.x)
	_announce_zone()
	_apply_knock(delta)
	_update_gates()
	_update_checkpoints(delta)
	_update_events(delta)
	_update_enemies(delta)
	_update_streaks(delta)
	queue_redraw()
	if clock_remaining <= 0.0:
		active = false
		clock_expired.emit()


func _announce_zone() -> void:
	var zone: Dictionary = RunProfile.zone_at(layout, player.global_position.x)
	var index: int = int(zone["index"])
	if index == _announced_zone:
		return
	_announced_zone = index
	if index > 0:
		banner.emit("ENTERING: %s" % str(zone["name"]).to_upper())


func _apply_knock(delta: float) -> void:
	if _knock.length() > 1.0:
		player.global_position += _knock * delta
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if absf(_spin) > 0.01:
		player.rotation += _spin * delta
		_spin = move_toward(_spin, 0.0, 6.0 * delta)


## Shared by comets, fast rocks and ring rocks. Knocks the ship off course.
func apply_impact(direction: Vector2, impulse: float, damage_fraction: float, spin_amount: float) -> void:
	if not is_instance_valid(player) or player.is_destroyed:
		return
	_knock = (_knock + direction.normalized() * impulse).limit_length(700.0)
	_spin += spin_amount
	player.take_damage(maxf(1.0, player.max_hull * damage_fraction))


func _on_rock_struck(normal: Vector2, rock_radius: float) -> void:
	var rock_scale: float = rock_radius / 11.0
	apply_impact(normal, 220.0 + rock_radius * 8.0, 0.07 * clampf(rock_scale, 0.7, 1.8), rng.randf_range(-2.0, 2.0))


# ------------------------------------------------------------------- gates

func _update_gates() -> void:
	var zones: Array = layout["zones"]
	var x: float = player.global_position.x
	for zone: Dictionary in zones:
		var gate_x: float = float(zone["gate_x"])
		if gate_x < 0.0:
			continue
		var index: int = int(zone["index"]) - 1
		if index < gates_cleared or _gates.has(index):
			continue
		if gate_x - x < GATE_SPAWN_DISTANCE:
			_spawn_gate(zone, index)


func _spawn_gate(zone: Dictionary, index: int) -> void:
	var gate: RouteGate = RouteGate.new()
	var weapon: ShipModule = load(GATE_WEAPONS[index % GATE_WEAPONS.size()]) as ShipModule
	var cannons: int = 1 + index / 2
	gate.ship_name = str(zone["gate_name"])
	gate.gate_index = index
	gate.max_hull = float(zone["gate_hull"])
	gate.max_shield = gate.max_hull * profile.gate_shield_ratio
	gate.shield_recharge_rate = gate.max_shield * 0.02
	gate.shield_recharge_delay = 4.0
	gate.movement_speed = 0.0
	gate.acceleration = 0.0
	gate.module_slot_count = cannons
	gate.starting_weapon_module = weapon
	var table: EnemyRewardTable = EnemyRewardTable.new()
	table.minimum_credits = 20 * (index + 1)
	table.maximum_credits = 30 * (index + 1)
	gate.reward_table = table
	gate.position = Vector2(float(zone["gate_x"]), 0.0)
	get_parent().add_child(gate)
	for slot: int in range(1, cannons):
		gate.install_module(weapon, slot)
	gate.destroyed.connect(_on_gate_destroyed.bind(index, str(zone["gate_name"])), CONNECT_ONE_SHOT)
	_gates[index] = gate
	banner.emit("%s AHEAD" % str(zone["gate_name"]).to_upper())


func _on_gate_destroyed(index: int, gate_name: String) -> void:
	gates_cleared = maxi(gates_cleared, index + 1)
	_gates.erase(index)
	var bonus: int = profile.gate_clear_bonus * (index + 1)
	if is_instance_valid(player):
		player.add_credits(bonus)
	gate_cleared.emit(index, gate_name)
	banner.emit("%s CLEARED  /  +%d CR MILESTONE" % [gate_name.to_upper(), bonus])


# ------------------------------------------------------------- checkpoints

func _update_checkpoints(delta: float) -> void:
	_inspect_left = maxf(0.0, _inspect_left - delta)
	if _inspect_left > 0.0:
		player.velocity = player.velocity.move_toward(Vector2.ZERO, 700.0 * delta)
	var position_value: Vector2 = player.global_position
	for checkpoint: Dictionary in _checkpoints:
		if int(checkpoint["state"]) != 0:
			continue
		var cx: float = float(checkpoint["x"])
		if _last_player_x >= cx or position_value.x < cx:
			continue
		if absf(position_value.y - float(checkpoint["y"])) <= float(checkpoint["half_span"]):
			checkpoint["state"] = 1
			_inspect_left = 2.6
			banner.emit(RunProfile.CHECKPOINT_LINES[int(checkpoint["line"])])
		else:
			checkpoint["state"] = 2
			banner.emit("EVASION NOTED. INTERCEPTORS DISPATCHED.")
			for offset: float in [-160.0, 160.0]:
				_spawn_enemy(1, 0.4, Vector2(cx + 450.0, float(checkpoint["y"]) + offset))
	_last_player_x = position_value.x


# ------------------------------------------------------- comets and rocks

func _update_events(delta: float) -> void:
	var x: float = player.global_position.x
	var kind: int = int(RunProfile.zone_at(layout, x)["kind"])
	if kind == RunProfile.ZoneKind.RING:
		return
	var chaos: float = pressure_at(x)
	var calm: float = 1.4 if kind == RunProfile.ZoneKind.CUSTOMS else 1.0
	_comet_timer -= delta
	if _comet_timer <= 0.0:
		_comet_timer = lerpf(9.0, 2.4, chaos) * calm * rng.randf_range(0.8, 1.2)
		var burst: int = 1 + (1 if rng.randf() < chaos * 0.7 else 0)
		for _i: int in range(burst):
			_spawn_streak(true, chaos)
		if not _comet_announced:
			_comet_announced = true
			banner.emit("COMET TRAFFIC DETECTED. THE COMPANY IS NOT LIABLE.")
	_rock_timer -= delta
	if _rock_timer <= 0.0:
		_rock_timer = lerpf(6.0, 1.8, chaos) * calm * rng.randf_range(0.8, 1.2)
		var volley: int = 1
		if kind == RunProfile.ZoneKind.WRECKS or kind == RunProfile.ZoneKind.BLOCKADE:
			volley = rng.randi_range(2, 4)
		for _i: int in range(volley):
			_spawn_streak(false, chaos)


func _spawn_streak(is_comet: bool, chaos: float) -> void:
	var streak: Streak = Streak.new()
	streak.comet = is_comet
	var center: Vector2 = player.global_position + player.velocity * 1.2
	streak.aim = center + Vector2(rng.randf_range(-260.0, 260.0), rng.randf_range(-260.0, 260.0))
	# Approach from ahead or the sides more often than from behind.
	streak.direction = -Vector2.RIGHT.rotated(rng.randf_range(-PI * 0.85, PI * 0.85))
	var speed: float
	if is_comet:
		speed = rng.randf_range(900.0, 1250.0) + chaos * 200.0
		streak.radius = 9.0
		streak.wait = 1.1
	else:
		speed = rng.randf_range(380.0, 620.0)
		streak.radius = rng.randf_range(16.0, 34.0)
		streak.spin = rng.randf_range(-2.0, 2.0)
	streak.velocity = streak.direction * speed
	streak.position = streak.aim - streak.direction * 1500.0
	streak.rotation_angle = rng.randf_range(0.0, TAU)
	_streaks.append(streak)


func _update_streaks(delta: float) -> void:
	var index: int = _streaks.size() - 1
	while index >= 0:
		var streak: Streak = _streaks[index]
		if streak.wait > 0.0:
			streak.wait -= delta
		else:
			streak.position += streak.velocity * delta
			streak.age += delta
			streak.rotation_angle += streak.spin * delta
			if not streak.hit and streak.position.distance_to(player.global_position) < streak.radius + 14.0:
				streak.hit = true
				if streak.comet:
					apply_impact(streak.velocity, 520.0, 0.12, rng.randf_range(-4.0, 4.0))
				else:
					apply_impact(streak.velocity, 300.0 + streak.radius * 6.0, 0.09, rng.randf_range(-3.0, 3.0))
			if streak.age > 6.0 or streak.position.distance_to(player.global_position) > 2600.0:
				_streaks.remove_at(index)
		index -= 1


# ----------------------------------------------------------------- enemies

func _update_enemies(delta: float) -> void:
	_enemy_timer -= delta
	if _enemy_timer > 0.0:
		return
	var x: float = player.global_position.x
	var kind: int = int(RunProfile.zone_at(layout, x)["kind"])
	var chaos: float = pressure_at(x)
	var pressure: float = float(KIND_PRESSURE.get(kind, 1.0))
	if pressure <= 0.0 or chaos <= 0.02 or enemy_scenes.is_empty():
		_enemy_timer = 1.0
		return
	_enemy_timer = lerpf(5.0, 0.9, chaos) / pressure
	var cap: int = roundi(float(profile.enemy_cap_at_full_chaos) * chaos * pressure)
	if _count_hostiles() >= cap:
		return
	var ahead: bool = rng.randf() < 0.6
	var angle: float = rng.randf_range(-1.2, 1.2) if ahead else rng.randf_range(0.0, TAU)
	var spawn_position: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * rng.randf_range(1150.0, 1400.0)
	_spawn_enemy(_pick_enemy_index(chaos), chaos, spawn_position)


## Counts live hostiles and recycles any left far behind.
func _count_hostiles() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var hostile: Ship = node as Ship
		if hostile == null or hostile is RouteGate or hostile.is_destroyed:
			continue
		if hostile.global_position.distance_to(player.global_position) > RECYCLE_DISTANCE:
			hostile.queue_free()
			continue
		count += 1
	return count


func _pick_enemy_index(chaos: float) -> int:
	var scout: float = 1.0 - chaos * 0.5
	var fighter: float = 0.3 + chaos * 0.7
	var heavy: float = maxf(0.0, chaos - 0.4) * 1.2
	var roll: float = rng.randf() * (scout + fighter + heavy)
	if roll < scout:
		return 0
	if roll < scout + fighter:
		return 1
	return 2


func _spawn_enemy(scene_index: int, chaos: float, at: Vector2) -> void:
	if enemy_scenes.is_empty():
		return
	var scene: PackedScene = enemy_scenes[clampi(scene_index, 0, enemy_scenes.size() - 1)]
	var enemy: Ship = scene.instantiate() as Ship
	if enemy == null:
		return
	enemy.position = at
	get_parent().add_child(enemy)
	var scaling: float = 1.0 + chaos * profile.enemy_hull_scaling
	enemy.max_hull *= scaling
	enemy.max_shield *= scaling
	enemy.current_hull = enemy.max_hull
	enemy.current_shield = enemy.max_shield
	enemy.hull_changed.emit(enemy.current_hull, enemy.max_hull)
	enemy.shield_changed.emit(enemy.current_shield, enemy.max_shield)


# ----------------------------------------------------------------- drawing

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var player_x: float = player.global_position.x
	for checkpoint: Dictionary in _checkpoints:
		if absf(float(checkpoint["x"]) - player_x) < 2200.0:
			_draw_checkpoint(checkpoint)
	for item: Variant in _streaks:
		var streak: Streak = item
		_draw_streak(streak)


func _draw_streak(streak: Streak) -> void:
	if streak.wait > 0.0:
		var alpha: float = 0.25 + 0.25 * sin(elapsed * 20.0)
		draw_line(streak.aim - streak.direction * 900.0, streak.aim + streak.direction * 900.0, Color(1.0, 0.35, 0.2, alpha), 2.0)
		return
	if streak.comet:
		draw_line(streak.position, streak.position - streak.direction * 220.0, Color(0.5, 0.85, 1.0, 0.25), streak.radius * 1.8)
		draw_line(streak.position, streak.position - streak.direction * 120.0, Color(0.85, 0.95, 1.0, 0.8), streak.radius * 0.9)
		draw_circle(streak.position, streak.radius, Color(1.0, 1.0, 1.0))
		return
	var points: PackedVector2Array = PackedVector2Array()
	for k: int in range(9):
		var wobble: float = 0.8 + 0.2 * sin(float(k) * 2.3)
		points.append(streak.position + Vector2.RIGHT.rotated(streak.rotation_angle + TAU * float(k) / 9.0) * streak.radius * wobble)
	draw_colored_polygon(points, Color(0.5, 0.55, 0.6))


func _draw_checkpoint(checkpoint: Dictionary) -> void:
	var cx: float = float(checkpoint["x"])
	var cy: float = float(checkpoint["y"])
	var span: float = float(checkpoint["half_span"])
	var state: int = int(checkpoint["state"])
	var top: Vector2 = Vector2(cx, cy - span)
	var bottom: Vector2 = Vector2(cx, cy + span)
	var flash: bool = int(elapsed * 4.0) % 2 == 0
	var beam: Color = Color(0.5, 0.6, 0.7, 0.2)
	if state == 0:
		beam = Color(0.3, 0.55, 1.0, 0.6) if flash else Color(1.0, 0.25, 0.25, 0.6)
	draw_line(top, bottom, beam, 3.0)
	for end_point: Vector2 in [top, bottom]:
		var hull: PackedVector2Array = PackedVector2Array([
			end_point + Vector2(-26.0, 0.0), end_point + Vector2(18.0, -14.0),
			end_point + Vector2(10.0, 0.0), end_point + Vector2(18.0, 14.0),
		])
		draw_colored_polygon(hull, Color(0.75, 0.82, 0.92) if state == 0 else Color(0.4, 0.45, 0.5))
		draw_circle(end_point + Vector2(4.0, 0.0), 5.0, Color(1.0, 0.25, 0.25) if flash else Color(0.3, 0.55, 1.0))
	if state == 0:
		draw_string(
			ThemeDB.fallback_font, Vector2(cx - 170.0, cy - span - 24.0),
			"SPACE POLICE  /  MANDATORY INSPECTION", HORIZONTAL_ALIGNMENT_CENTER, 340.0, 16, Color(0.6, 0.8, 1.0)
		)
