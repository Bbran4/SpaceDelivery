extends Resource
class_name ShipHull

## Data definition for a selectable delivery-ship hull.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var hull_id: StringName = &"starter_courier"
@export var display_name: String = "Starter Courier"
@export_multiline var description: String = "A dependable small delivery ship."
@export var rarity: Rarity = Rarity.COMMON
@export var preview_color: Color = Color(0.35, 0.85, 1.0, 1.0)
@export var preview_polygon: PackedVector2Array = PackedVector2Array([Vector2(62, 0), Vector2(-35, -34), Vector2(-22, 0), Vector2(-35, 34)])

@export_group("Base Stats")
@export_range(1.0, 100000.0, 1.0) var max_hull: float = 100.0
@export_range(0.0, 100000.0, 1.0) var max_shield: float = 50.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_rate: float = 0.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_delay: float = 3.0
@export_range(0.0, 10000.0, 1.0) var movement_speed: float = 220.0
@export_range(0.0, 10000.0, 1.0) var acceleration: float = 500.0
@export_range(0.0, 2000.0, 1.0) var linear_drag: float = 35.0
@export_range(0.0, 1440.0, 1.0) var turn_rate: float = 180.0

@export_group("Capacity")
@export_range(0, 100000, 1) var cargo_hold_capacity: int = 20
@export_range(0, 100000, 1) var salvage_hold_capacity: int = 10

## One entry per slot. Use -1 for a universal slot, otherwise use ShipModule.Category values.
@export var slot_categories: Array[int] = [0, 1, 2, 3, 4]
