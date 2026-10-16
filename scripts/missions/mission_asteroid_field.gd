extends Node2D

## Drifts and tumbles the breakable rocks while a separate invisible barrier
## prevents flight through the belt until every blocking asteroid is destroyed.
@export var drift_speed: float = 12.0
@export var rotation_speed: float = 0.18

var asteroid_nodes: Array[Ship] = []
var drift_directions: Array[Vector2] = []
var is_cleared: bool = false
var belt_center_x: float = 660.0


func configure(asteroids: Array[Ship]) -> void:
	asteroid_nodes = asteroids
	drift_directions.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _asteroid: Ship in asteroid_nodes:
		drift_directions.append(Vector2(rng.randf_range(-0.55, 0.55), rng.randf_range(-1.0, 1.0)).normalized())


func _process(delta: float) -> void:
	if is_cleared:
		return
	for index: int in range(asteroid_nodes.size()):
		var asteroid: Ship = asteroid_nodes[index]
		if not is_instance_valid(asteroid) or asteroid.is_destroyed:
			continue
		var direction: Vector2 = drift_directions[index]
		asteroid.global_position += direction * drift_speed * delta
		if asteroid.global_position.x < belt_center_x - 105.0 or asteroid.global_position.x > belt_center_x + 105.0:
			direction.x = -direction.x
		if absf(asteroid.global_position.y) > 270.0:
			direction.y = -direction.y
		drift_directions[index] = direction
		asteroid.rotation += rotation_speed * (1.0 if index % 2 == 0 else -1.0) * delta
