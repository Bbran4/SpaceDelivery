extends CharacterBody2D
class_name Ship

## Shared ship foundation for player-controlled and AI-controlled ships.
## Controllers decide what the ship should do; this class applies movement
## and provides shared health, shield, repair, inventory, and module behavior.

signal hull_changed(current_hull: float, maximum_hull: float)
signal shield_changed(current_shield: float, maximum_shield: float)
signal damaged(amount: float, hull_damage: float, shield_damage: float)
signal repaired(amount: float)
signal destroyed
signal weapon_fired(weapon: Node, target: Node2D)
signal module_installed(module: ShipModule, slot_index: int)
signal module_uninstalled(module: ShipModule, slot_index: int)

@export_group("Durability")
@export_range(1.0, 100000.0, 1.0) var max_hull: float = 100.0
@export_range(0.0, 100000.0, 1.0) var max_shield: float = 50.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_rate: float = 0.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_delay: float = 3.0

@export_group("Combat")
@export_range(0.0, 10000.0, 0.1) var damage: float = 10.0
@export_range(0.0, 100000.0, 1.0) var attack_range: float = 300.0
## Attacks per second. Actual firing cadence may be determined by each weapon.
@export_range(0.01, 100.0, 0.01) var attack_speed: float = 1.0

@export_group("Movement")
@export_range(0.0, 10000.0, 1.0) var movement_speed: float = 220.0
@export_range(0.0, 10000.0, 1.0) var acceleration: float = 500.0
## Maximum turning speed in degrees per second.
@export_range(0.0, 1440.0, 1.0) var turn_rate: float = 180.0

@export_group("Ship Loadout")
@export_range(0, 32, 1) var module_slot_count: int = 4

var current_hull: float
var current_shield: float
var is_destroyed: bool = false

## Inventory holds cargo/items; equipped modules live in module_slots.
var inventory: Array = []
var module_slots: Array[ShipModule] = []
var weapon_instances: Array[Node] = []

var _movement_input: Vector2 = Vector2.ZERO
var _turn_input: float = 0.0
var _time_since_last_hit: float = 999999.0


func _ready() -> void:
	current_hull = max_hull
	current_shield = max_shield
	module_slots.resize(module_slot_count)
	hull_changed.emit(current_hull, max_hull)
	shield_changed.emit(current_shield, max_shield)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		velocity = Vector2.ZERO
		return

	_time_since_last_hit += delta
	_update_shield_recharge(delta)
	_apply_movement(delta)
	move_and_slide()


## Called by a player or enemy controller. Movement input is a direction
## vector; turn input ranges from -1.0 (left) to 1.0 (right).
func set_movement_input(direction: Vector2, turn: float = 0.0) -> void:
	_movement_input = direction.limit_length(1.0)
	_turn_input = clampf(turn, -1.0, 1.0)


## Convenience method for steering toward a world-space point.
## Ships are assumed to face local +X (right) by default.
func steer_toward_point(world_position: Vector2) -> float:
	var to_target := world_position - global_position
	if to_target.is_zero_approx():
		return 0.0
	var angle_difference := wrapf(to_target.angle() - rotation, -PI, PI)
	return clampf(angle_difference / deg_to_rad(maxf(turn_rate, 1.0)), -1.0, 1.0)


func _apply_movement(delta: float) -> void:
	rotation += deg_to_rad(turn_rate) * _turn_input * delta

	var desired_velocity := _movement_input * movement_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


## Damage consumes shields first, then hull. Negative damage is ignored.
func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	_time_since_last_hit = 0.0
	var remaining_damage := amount
	var shield_damage := minf(current_shield, remaining_damage)
	current_shield -= shield_damage
	remaining_damage -= shield_damage

	var hull_damage := minf(current_hull, remaining_damage)
	current_hull -= hull_damage

	shield_changed.emit(current_shield, max_shield)
	if hull_damage > 0.0:
		hull_changed.emit(current_hull, max_hull)
	damaged.emit(amount, hull_damage, shield_damage)

	if current_hull <= 0.0:
		_destroy()


## Repairs hull only and never revives a destroyed ship.
func repair(amount: float) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0

	var previous_hull := current_hull
	current_hull = minf(max_hull, current_hull + amount)
	var repaired_amount := current_hull - previous_hull
	if repaired_amount > 0.0:
		hull_changed.emit(current_hull, max_hull)
		repaired.emit(repaired_amount)
	return repaired_amount


## Restores shields without exceeding the maximum.
func restore_shield(amount: float) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0

	var previous_shield := current_shield
	current_shield = minf(max_shield, current_shield + amount)
	var restored_amount := current_shield - previous_shield
	if restored_amount > 0.0:
		shield_changed.emit(current_shield, max_shield)
	return restored_amount


func _update_shield_recharge(delta: float) -> void:
	if shield_recharge_rate <= 0.0 or current_shield >= max_shield:
		return
	if _time_since_last_hit < shield_recharge_delay:
		return
	restore_shield(shield_recharge_rate * delta)


func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	velocity = Vector2.ZERO
	destroyed.emit()


## Adds an item to the ship's inventory. Item representation is intentionally
## flexible until the game's inventory Resource schema is established.
func add_item(item: Variant) -> void:
	inventory.append(item)


func remove_item(item: Variant) -> bool:
	var index := inventory.find(item)
	if index == -1:
		return false
	inventory.remove_at(index)
	return true


## Installs any module category into a module slot. Weapon modules may
## optionally spawn their weapon_scene as a runtime child of this ship.
func install_module(module: ShipModule, slot_index: int) -> bool:
	if module == null or slot_index < 0 or slot_index >= module_slots.size():
		return false
	if module_slots[slot_index] != null:
		return false

	module_slots[slot_index] = module
	if module.category == ShipModule.Category.WEAPON and module.weapon_scene != null:
		var weapon_instance := module.weapon_scene.instantiate()
		if weapon_instance is Node:
			add_child(weapon_instance)
			weapon_instances.append(weapon_instance)
	module_installed.emit(module, slot_index)
	return true


func uninstall_module(slot_index: int) -> ShipModule:
	if slot_index < 0 or slot_index >= module_slots.size():
		return null

	var module := module_slots[slot_index]
	if module == null:
		return null

	module_slots[slot_index] = null
	# Runtime weapon instances should ideally be associated with their module
	# in a later weapon manager; clear the current simple runtime list here.
	if module.category == ShipModule.Category.WEAPON and module.weapon_scene != null:
		for weapon in weapon_instances:
			if is_instance_valid(weapon):
				weapon.queue_free()
		weapon_instances.clear()

	module_uninstalled.emit(module, slot_index)
	return module


func is_target_in_attack_range(target: Node2D) -> bool:
	return is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range
