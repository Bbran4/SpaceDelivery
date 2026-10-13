extends Resource
class_name EnemyLoadout

## Data-driven enemy archetype. Shared Ship and EnemyController scripts remain reusable.

@export var archetype_name: String = "Fighter"
@export_range(1.0, 100000.0, 1.0) var max_hull: float = 30.0
@export_range(0.0, 100000.0, 1.0) var max_shield: float = 10.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_rate: float = 0.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_delay: float = 2.0
@export_range(0.0, 10000.0, 1.0) var hull_recharge_rate: float = 0.0
@export_range(0.0, 10000.0, 1.0) var hull_recharge_delay: float = 5.0
@export_range(0.0, 10000.0, 1.0) var movement_speed: float = 160.0
@export_range(0.0, 10000.0, 1.0) var acceleration: float = 350.0
@export_range(0.0, 2000.0, 1.0) var linear_drag: float = 35.0
@export_range(0.0, 1440.0, 1.0) var turn_rate: float = 150.0
@export_range(0.0, 2000.0, 1.0) var preferred_distance: float = 180.0
@export_range(1.0, 89.0, 1.0) var pursuit_angle_tolerance: float = 65.0
@export var weapon_module: ShipModule
@export var reward_table: EnemyRewardTable
@export var visual_color: Color = Color(1.0, 0.28, 0.22, 1.0)
@export var visual_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(18.0, 0.0), Vector2(-12.0, -11.0), Vector2(-7.0, 0.0), Vector2(-12.0, 11.0)
])


func apply_to_ship(ship: Ship) -> void:
	if ship == null:
		return
	ship.ship_name = archetype_name
	ship.max_hull = max_hull
	ship.max_shield = max_shield
	ship.shield_recharge_rate = shield_recharge_rate
	ship.shield_recharge_delay = shield_recharge_delay
	ship.hull_recharge_rate = hull_recharge_rate
	ship.hull_recharge_delay = hull_recharge_delay
	ship.movement_speed = movement_speed
	ship.acceleration = acceleration
	ship.linear_drag = linear_drag
	ship.turn_rate = turn_rate
	ship.starting_weapon_module = weapon_module
	ship.reward_table = reward_table
	var visual: Polygon2D = ship.get_node_or_null("ShipVisual") as Polygon2D
	if visual != null:
		visual.color = visual_color
		visual.polygon = visual_polygon
