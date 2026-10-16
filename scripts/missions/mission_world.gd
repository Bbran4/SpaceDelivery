extends Node2D

## Simple orbital scenery for the opening leg of a delivery mission.
var moon_angle: float = 0.0
var stars: Array[Vector2] = []


func _ready() -> void:
	z_index = -20
	var rng := RandomNumberGenerator.new()
	rng.seed = 48291
	for _index: int in range(150):
		stars.append(Vector2(rng.randf_range(-200.0, 2500.0), rng.randf_range(-620.0, 620.0)))


func _process(delta: float) -> void:
	moon_angle = wrapf(moon_angle + delta * 0.18, 0.0, TAU)
	queue_redraw()


func _draw() -> void:
	for index: int in range(stars.size()):
		var star: Vector2 = stars[index]
		var radius: float = 1.0 if index % 5 != 0 else 1.7
		draw_circle(star, radius, Color(0.55, 0.72, 0.9, 0.55 if index % 3 == 0 else 0.28))
	var planet_center := Vector2(120.0, 0.0)
	draw_circle(planet_center, 145.0, Color(0.035, 0.16, 0.31))
	draw_circle(planet_center, 132.0, Color(0.055, 0.29, 0.48))
	draw_arc(planet_center, 147.0, -0.9, 2.5, 80, Color(0.18, 0.65, 0.88, 0.7), 4.0)
	draw_arc(planet_center + Vector2(-20.0, -10.0), 95.0, 3.3, 5.9, 48, Color(0.12, 0.39, 0.56, 0.8), 12.0)
	draw_arc(planet_center, 205.0, 0.0, TAU, 96, Color(0.22, 0.53, 0.76, 0.22), 1.0)
	var moon_orbit := Vector2(190.0, 0.0)
	draw_arc(planet_center, moon_orbit.x, 0.0, TAU, 64, Color(0.46, 0.66, 0.79, 0.35), 1.0)
	var moon_center := planet_center + moon_orbit.rotated(moon_angle)
	draw_circle(moon_center, 25.0, Color(0.43, 0.54, 0.62))
	draw_circle(moon_center + Vector2(-5.0, -7.0), 8.0, Color(0.56, 0.65, 0.71, 0.7))
	draw_circle(moon_center + Vector2(8.0, 6.0), 5.0, Color(0.29, 0.39, 0.48, 0.8))
	var destination := Vector2(2200.0, 0.0)
	draw_line(Vector2(330.0, 0.0), destination, Color(0.2, 0.65, 0.86, 0.12), 1.0)
	draw_circle(destination, 28.0, Color(0.15, 0.8, 0.52, 0.08))
	draw_arc(destination, 28.0, 0.0, TAU, 48, Color(0.27, 1.0, 0.65, 0.8), 2.0)
	draw_circle(destination, 5.0, Color(0.35, 1.0, 0.65))
