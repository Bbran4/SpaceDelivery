extends Node2D

## Scenery for the whole route. Stars are a wrapped parallax tile that follows the
## camera, so route length costs nothing. The planet, moon and destination station
## are only drawn while the player is near them.

const STAR_TILE: float = 2400.0
const STAR_COUNT: int = 220

var follow_target: Node2D
var planet_center: Vector2 = Vector2(120.0, 0.0)
var destination: Vector2 = Vector2(39600.0, 0.0)
var station_name: String = "DESTINATION"

var moon_angle: float = 0.0
var stars: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = -20
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 48291
	for _index: int in range(STAR_COUNT):
		stars.append(Vector2(rng.randf_range(0.0, STAR_TILE), rng.randf_range(0.0, STAR_TILE)))


func _process(delta: float) -> void:
	moon_angle = wrapf(moon_angle + delta * 0.18, 0.0, TAU)
	queue_redraw()


func _draw() -> void:
	var camera_position: Vector2 = follow_target.global_position if is_instance_valid(follow_target) else Vector2.ZERO
	_draw_stars(camera_position)
	if camera_position.distance_to(planet_center) < 2800.0:
		_draw_planet()
	if camera_position.distance_to(destination) < 2200.0:
		_draw_station()


func _draw_stars(camera_position: Vector2) -> void:
	var half_tile: Vector2 = Vector2(STAR_TILE, STAR_TILE) * 0.5
	for index: int in range(stars.size()):
		var star: Vector2 = stars[index]
		var relative: Vector2 = Vector2(
			fposmod(star.x - camera_position.x * 0.7, STAR_TILE),
			fposmod(star.y - camera_position.y * 0.7, STAR_TILE)
		) - half_tile
		var star_size: float = 1.0 if index % 5 != 0 else 1.8
		var alpha: float = 0.55 if index % 3 == 0 else 0.28
		draw_rect(Rect2(camera_position + relative, Vector2(star_size, star_size)), Color(0.55, 0.72, 0.9, alpha))


func _draw_planet() -> void:
	draw_circle(planet_center, 145.0, Color(0.035, 0.16, 0.31))
	draw_circle(planet_center, 132.0, Color(0.055, 0.29, 0.48))
	draw_arc(planet_center, 147.0, -0.9, 2.5, 80, Color(0.18, 0.65, 0.88, 0.7), 4.0)
	draw_arc(planet_center + Vector2(-20.0, -10.0), 95.0, 3.3, 5.9, 48, Color(0.12, 0.39, 0.56, 0.8), 12.0)
	var orbit: Vector2 = Vector2(190.0, 0.0)
	draw_arc(planet_center, orbit.x, 0.0, TAU, 64, Color(0.46, 0.66, 0.79, 0.35), 1.0)
	var moon_center: Vector2 = planet_center + orbit.rotated(moon_angle)
	draw_circle(moon_center, 25.0, Color(0.43, 0.54, 0.62))
	draw_circle(moon_center + Vector2(-5.0, -7.0), 8.0, Color(0.56, 0.65, 0.71, 0.7))
	draw_circle(moon_center + Vector2(8.0, 6.0), 5.0, Color(0.29, 0.39, 0.48, 0.8))


func _draw_station() -> void:
	var arm: Color = Color(0.5, 0.76, 0.86, 0.9)
	var module: Color = Color(0.1, 0.24, 0.39)
	draw_arc(destination, 185.0, 0.0, TAU, 96, Color(0.24, 0.77, 0.88, 0.88), 8.0)
	draw_arc(destination, 162.0, 0.0, TAU, 96, Color(0.42, 0.89, 0.94, 0.45), 2.0)
	draw_line(destination + Vector2(-240.0, 0.0), destination + Vector2(240.0, 0.0), arm, 8.0)
	draw_line(destination + Vector2(0.0, -240.0), destination + Vector2(0.0, 240.0), arm, 8.0)
	draw_rect(Rect2(destination + Vector2(-58.0, -34.0), Vector2(116.0, 68.0)), Color(0.11, 0.27, 0.39))
	draw_rect(Rect2(destination + Vector2(-44.0, -23.0), Vector2(88.0, 46.0)), Color(0.25, 0.56, 0.68))
	for corner: Vector2 in [Vector2(-340.0, -92.0), Vector2(215.0, -92.0), Vector2(-340.0, 50.0), Vector2(215.0, 50.0)]:
		draw_rect(Rect2(destination + corner, Vector2(125.0, 42.0)), module)
	draw_circle(destination, 24.0, Color(0.19, 0.65, 0.78))
	draw_circle(destination, 8.0, Color(0.7, 1.0, 0.88))
	draw_circle(destination + Vector2(0.0, -245.0), 12.0, Color(0.35, 1.0, 0.65))
	draw_arc(destination + Vector2(0.0, -245.0), 26.0, 0.0, TAU, 32, Color(0.27, 1.0, 0.65, 0.8), 2.0)
	draw_string(
		ThemeDB.fallback_font, destination + Vector2(-210.0, 285.0),
		"%s  /  DOCKING APPROACH" % station_name, HORIZONTAL_ALIGNMENT_CENTER, 420.0, 20, Color(0.52, 0.96, 0.9)
	)
