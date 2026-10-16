extends Ship

## Bounty asteroids always take exactly two successful projectile impacts,
## regardless of the equipped weapon's damage value.
var hits_remaining: int = 2


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_destroyed:
		return
	hits_remaining -= 1
	if hits_remaining <= 0:
		super.take_damage(max_hull)
	else:
		super.take_damage(1.0)
