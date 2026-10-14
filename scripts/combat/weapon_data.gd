extends Resource
class_name WeaponData

## Tunable weapon stats and projectile presentation/impact settings.

enum ProjectileStyle {
	LASER,
	PLASMA,
	LANCE,
}

@export var display_name: String = "Basic Laser"
@export_range(0.1, 100.0, 0.1) var fire_rate: float = 1.0
@export_range(1.0, 5000.0, 1.0) var range: float = 300.0
@export_range(0.1, 10000.0, 0.1) var projectile_damage: float = 10.0
@export_range(1.0, 3000.0, 1.0) var projectile_speed: float = 600.0
@export_range(0.1, 20.0, 0.1) var projectile_lifetime: float = 2.0

@export_group("Projectile")
@export var projectile_style: ProjectileStyle = ProjectileStyle.LASER
@export var projectile_color: Color = Color(1.0, 0.86, 0.25, 1.0)
@export_range(0.25, 4.0, 0.05) var projectile_scale: float = 1.0
## A positive radius adds area damage around the impact point.
@export_range(0.0, 250.0, 1.0) var impact_radius: float = 0.0
