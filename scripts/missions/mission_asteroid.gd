extends Ship
class_name MissionAsteroid

## Mission asteroids drift independently, spin at different rates, collide with
## one another, and damage the player on contact. Objective rocks count toward
## the 60-second belt-clear phase; the rest are persistent orbital hazards.
var hits_remaining: int = 2
var is_objective_target: bool = false
var spin_rate: float = 0.0
var contact_damage_cooldown: float = 0.0
var size_factor: float = 1.0


func _ready() -> void:
	super._ready()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	size_factor = rng.randf_range(0.65, 1.95)
	spin_rate = rng.randf_range(-0.9, 0.9)
	velocity = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(12.0, 72.0)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		circle = circle.duplicate() as CircleShape2D
		circle.radius = 12.0 * size_factor
		collision.shape = circle
	var rock := get_node_or_null("Rock") as Polygon2D
	if rock != null:
		var points := PackedVector2Array()
		var point_count: int = rng.randi_range(7, 11)
		for point_index: int in range(point_count):
			var angle: float = TAU * float(point_index) / float(point_count)
			var radius: float = rng.randf_range(10.0, 22.0) * size_factor
			points.append(Vector2.RIGHT.rotated(angle) * radius)
		rock.polygon = points
		rock.color = Color(
			rng.randf_range(0.28, 0.53),
			rng.randf_range(0.32, 0.56),
			rng.randf_range(0.36, 0.61),
			1.0
		)
	var highlight := get_node_or_null("Highlight") as Polygon2D
	if highlight != null:
		highlight.visible = size_factor > 1.15


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	contact_damage_cooldown = maxf(0.0, contact_damage_cooldown - delta)
	rotation += spin_rate * delta
	# A little orbital drift plus a large random velocity spread makes the ring
	# feel alive rather than moving as one synchronized wall.
	move_and_slide()
	for collision_index: int in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		var collider: Object = collision.get_collider()
		if collider is MissionAsteroid and collider != self:
			var other := collider as MissionAsteroid
			var normal: Vector2 = collision.get_normal()
			velocity = velocity.bounce(normal) * 0.92
			other.velocity = other.velocity.bounce(-normal) * 0.92
			velocity += normal * 3.0
			other.velocity -= normal * 3.0
		elif collider is Ship and (collider as Ship).is_in_group("player_ship"):
			if contact_damage_cooldown <= 0.0:
				var player := collider as Ship
				player.take_damage(maxf(1.0, player.max_hull * 0.25))
				contact_damage_cooldown = 0.9


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_destroyed:
		return
	hits_remaining -= 1
	if hits_remaining <= 0:
		super.take_damage(max_hull)
	else:
		super.take_damage(1.0)
