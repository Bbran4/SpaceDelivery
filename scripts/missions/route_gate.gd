extends Ship
class_name RouteGate

## A stationary must-destroy barrier. It is a Ship so existing projectiles,
## auto-targeting, the target HUD and loot drops all work unchanged.
## While alive it blocks the player from passing its x position, at any y.

const STATUS_BAR_SCENE: PackedScene = preload("res://scenes/ui/enemy_status_bar.tscn")

@export var barrier_half_height: float = 760.0
@export var clearance: float = 30.0

var gate_index: int = 0
var _pulse: float = 0.0


func _init() -> void:
	# Joined in _init so SceneTree.node_added listeners (camera shake) see the group.
	add_to_group("enemy")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	super._ready()
	var bar: EnemyStatusBar = STATUS_BAR_SCENE.instantiate() as EnemyStatusBar
	if bar != null:
		bar.ship = self
		bar.vertical_offset = 95.0
		bar.scale = Vector2(2.4, 2.4)
		add_child(bar)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_destroyed:
		return
	_pulse += delta
	queue_redraw()
	var blocked_ship: Ship = get_tree().get_first_node_in_group("player_ship") as Ship
	if blocked_ship == null or blocked_ship.is_destroyed:
		return
	var limit: float = global_position.x - clearance
	if blocked_ship.global_position.x > limit:
		blocked_ship.global_position.x = limit
		blocked_ship.velocity.x = minf(blocked_ship.velocity.x, 0.0)


func _draw() -> void:
	var shield_ratio: float = current_shield / maxf(max_shield, 1.0)
	var alpha: float = 0.35 + 0.2 * sin(_pulse * 5.0)
	var top: Vector2 = Vector2(0.0, -barrier_half_height)
	var bottom: Vector2 = Vector2(0.0, barrier_half_height)
	draw_line(top, bottom, Color(1.0, 0.25, 0.2, alpha * 0.6), 14.0)
	draw_line(top, bottom, Color(1.0, 0.55, 0.4, alpha + 0.3), 3.0)
	for pylon: Vector2 in [top, bottom]:
		draw_circle(pylon, 16.0, Color(0.35, 0.1, 0.12))
		draw_circle(pylon, 8.0, Color(1.0, 0.4, 0.3))
	var hexagon: PackedVector2Array = PackedVector2Array()
	for k: int in range(6):
		hexagon.append(Vector2.RIGHT.rotated(TAU * float(k) / 6.0) * 46.0)
	draw_colored_polygon(hexagon, Color(0.42, 0.12, 0.16))
	var inner: PackedVector2Array = PackedVector2Array()
	for k: int in range(6):
		inner.append(Vector2.RIGHT.rotated(TAU * float(k) / 6.0) * 26.0)
	draw_colored_polygon(inner, Color(1.0, 0.35, 0.25))
	if shield_ratio > 0.0:
		draw_arc(Vector2.ZERO, 64.0, 0.0, TAU, 48, Color(0.3, 0.6, 1.0, 0.25 + 0.5 * shield_ratio), 3.0)
	draw_string(
		ThemeDB.fallback_font, Vector2(-160.0, -barrier_half_height - 26.0), ship_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, 320.0, 18, Color(1.0, 0.7, 0.55)
	)
