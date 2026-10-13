extends Resource
class_name WeaponData

## Tunable weapon stats shared by every instance using this resource.

@export var display_name: String = "Basic Laser"
@export_range(0.1, 100.0, 0.1) var fire_rate: float = 1.0
@export_range(1.0, 5000.0, 1.0) var range: float = 300.0
@export_range(0.1, 10000.0, 0.1) var projectile_damage: float = 10.0
@export_range(1.0, 3000.0, 1.0) var projectile_speed: float = 600.0
@export_range(0.1, 20.0, 0.1) var projectile_lifetime: float = 2.0
