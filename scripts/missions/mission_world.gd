extends Node2D

## Simple orbital scenery for the opening leg of a delivery mission.
var moon_angle: float = 0.0
var belt_angle: float = 0.0
var stars: Array[Vector2] = []


func _ready() -> void:
	z_index = -20
	var rng := RandomNumberGenerator.new()
	rng.seed = 48291
	for _index: int in range(150):
		stars.append(Vector2(rng.randf_range(-300.0, 14000.0), rng.randf_range(-1650.0, 1650.0)))


func _process(delta: float) -> void:
	moon_angle = wrapf(moon_angle + delta * 0.18, 0.0, TAU)
	belt_angle = wrapf(belt_angle + delta * 0.025, 0.0, TAU)
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
	# A debris ring encircles the planet; the breakable lane rocks are concentrated
	# on the outward-facing arc where the courier crosses the ring.
	draw_arc(planet_center, 520.0, 0.0, TAU, 128, Color(0.4, 0.57, 0.68, 0.35), 2.0)
	for rock_index: int in range(52):
		var angle: float = TAU * float(rock_index) / 52.0 + belt_angle
		var radius: float = 520.0 + sin(float(rock_index) * 2.13) * 24.0
		var rock_position: Vector2 = planet_center + Vector2.RIGHT.rotated(angle) * radius
		var rock_size: float = 2.0 if rock_index % 4 == 0 else 1.2
		draw_circle(rock_position, rock_size, Color(0.55, 0.62, 0.68, 0.78))
	var moon_orbit := Vector2(190.0, 0.0)
	draw_arc(planet_center, moon_orbit.x, 0.0, TAU, 64, Color(0.46, 0.66, 0.79, 0.35), 1.0)
	var moon_center := planet_center + moon_orbit.rotated(moon_angle)
	draw_circle(moon_center, 25.0, Color(0.43, 0.54, 0.62))
	draw_circle(moon_center + Vector2(-5.0, -7.0), 8.0, Color(0.56, 0.65, 0.71, 0.7))
	draw_circle(moon_center + Vector2(8.0, 6.0), 5.0, Color(0.29, 0.39, 0.48, 0.8))
	var destination := Vector2(12500.0, 0.0)
	draw_line(Vector2(330.0, 0.0), destination, Color(0.2, 0.65, 0.86, 0.12), 2.0)
	# Vesper Clinic Ring is a physical orbital facility, with a docking ring,
	# central habitat, cargo arms, solar arrays and a visible approach beacon.
	draw_arc(destination, 185.0, 0.0, TAU, 96, Color(0.24, 0.77, 0.88, 0.88), 8.0)
	draw_arc(destination, 162.0, 0.0, TAU, 96, Color(0.42, 0.89, 0.94, 0.45), 2.0)
	draw_line(destination + Vector2(-240.0, 0.0), destination + Vector2(240.0, 0.0), Color(0.5, 0.76, 0.86, 0.9), 8.0)
	draw_line(destination + Vector2(0.0, -240.0), destination + Vector2(0.0, 240.0), Color(0.5, 0.76, 0.86, 0.9), 8.0)
	draw_rect(Rect2(destination + Vector2(-58.0, -34.0), Vector2(116.0, 68.0)), Color(0.11, 0.27, 0.39))
	draw_rect(Rect2(destination + Vector2(-44.0, -23.0), Vector2(88.0, 46.0)), Color(0.25, 0.56, 0.68))
	draw_rect(Rect2(destination + Vector2(-340.0, -92.0), Vector2(125.0, 42.0)), Color(0.1, 0.24, 0.39))
	draw_rect(Rect2(destination + Vector2(215.0, -92.0), Vector2(125.0, 42.0)), Color(0.1, 0.24, 0.39))
	draw_rect(Rect2(destination + Vector2(-340.0, 50.0), Vector2(125.0, 42.0)), Color(0.1, 0.24, 0.39))
	draw_rect(Rect2(destination + Vector2(215.0, 50.0), Vector2(125.0, 42.0)), Color(0.1, 0.24, 0.39))
	draw_line(destination + Vector2(-278.0, -71.0), destination + Vector2(-195.0, -120.0), Color(0.48, 0.71, 0.82, 0.9), 4.0)
	draw_line(destination + Vector2(278.0, -71.0), destination + Vector2(195.0, -120.0), Color(0.48, 0.71, 0.82, 0.9), 4.0)
	draw_line(destination + Vector2(-278.0, 71.0), destination + Vector2(-195.0, 120.0), Color(0.48, 0.71, 0.82, 0.9), 4.0)
	draw_line(destination + Vector2(278.0, 71.0), destination + Vector2(195.0, 120.0), Color(0.48, 0.71, 0.82, 0.9), 4.0)
	draw_circle(destination, 24.0, Color(0.19, 0.65, 0.78))
	draw_circle(destination, 8.0, Color(0.7, 1.0, 0.88))
	draw_circle(destination + Vector2(0.0, -245.0), 12.0, Color(0.35, 1.0, 0.65))
	draw_arc(destination + Vector2(0.0, -245.0), 26.0, 0.0, TAU, 32, Color(0.27, 1.0, 0.65, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, destination + Vector2(-160.0, 285.0), "VESPER CLINIC RING  /  DOCKING APPROACH", HORIZONTAL_ALIGNMENT_LEFT, 420.0, 20, Color(0.52, 0.96, 0.9))
