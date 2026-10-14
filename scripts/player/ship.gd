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
signal credits_changed(total_credits: int)

const LOOT_PICKUP_SCENE: PackedScene = preload("res://scenes/loot/loot_pickup.tscn")

@export var ship_name: String = "Ship"
@export var hull_data: ShipHull

var hull_rarity: int = ShipHull.Rarity.COMMON
var cargo_hold_capacity: int = 20
var salvage_hold_capacity: int = 10

@export_group("Durability")
@export_range(1.0, 100000.0, 1.0) var max_hull: float = 100.0
@export_range(0.0, 100000.0, 1.0) var max_shield: float = 50.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_rate: float = 0.0
@export_range(0.0, 10000.0, 1.0) var shield_recharge_delay: float = 3.0
@export_range(0.0, 10000.0, 1.0) var hull_recharge_rate: float = 0.0
@export_range(0.0, 10000.0, 1.0) var hull_recharge_delay: float = 5.0

@export_group("Combat")
@export_range(0.0, 10000.0, 0.1) var damage: float = 10.0
@export_range(0.0, 100000.0, 1.0) var attack_range: float = 300.0
## Attacks per second. Actual firing cadence may be determined by each weapon.
@export_range(0.01, 100.0, 0.01) var attack_speed: float = 1.0

@export_group("Movement")
@export_range(0.0, 10000.0, 1.0) var movement_speed: float = 220.0
## Acceleration applied along the ship's facing direction when thrust is used.
@export_range(0.0, 10000.0, 1.0) var acceleration: float = 500.0
## Passive slowdown applied while no thrust input is active, in pixels per second squared.
@export_range(0.0, 2000.0, 1.0) var linear_drag: float = 35.0
## Maximum turning speed in degrees per second.
@export_range(0.0, 1440.0, 1.0) var turn_rate: float = 180.0

@export_group("Ship Loadout")
@export_range(0, 32, 1) var module_slot_count: int = 4
@export var starting_weapon_module: ShipModule

@export_group("Rewards")
@export var reward_table: EnemyRewardTable
@export var enemy_loadout: EnemyLoadout

var current_hull: float
var current_shield: float
var is_destroyed: bool = false
var credits: int = 0

## Inventory holds cargo/items; equipped modules live in module_slots.
var inventory: Array = []
var cargo_inventory: Array[Dictionary] = []
var salvage_inventory: Array[Dictionary] = []
var module_slots: Array[ShipModule] = []
var weapon_instances: Array[Node] = []
var weapon_instances_by_slot: Dictionary = {}

var _movement_input: Vector2 = Vector2.ZERO
var _turn_input: float = 0.0
var _turn_rate_multiplier: float = 1.0
var _time_since_last_hit: float = 999999.0
var _base_stats: Dictionary = {}


func _ready() -> void:
	if enemy_loadout != null and is_in_group("enemy"):
		enemy_loadout.apply_to_ship(self)
	var loaded_saved_build: bool = false
	if is_in_group("player_ship"):
		loaded_saved_build = _load_active_build()
	if not loaded_saved_build:
		if hull_data != null:
			apply_hull(hull_data)
		else:
			_capture_base_stats()
			module_slots.resize(module_slot_count)
	current_hull = max_hull
	current_shield = max_shield
	hull_changed.emit(current_hull, max_hull)
	shield_changed.emit(current_shield, max_shield)
	if not loaded_saved_build and starting_weapon_module != null and module_slot_count > 0:
		install_module(starting_weapon_module, 0)


func _physics_process(delta: float) -> void:
	if is_destroyed:
		velocity = Vector2.ZERO
		return

	_time_since_last_hit += delta
	_update_shield_recharge(delta)
	_update_hull_recharge(delta)
	_apply_movement(delta)
	move_and_slide()


## Called by a controller. Movement is a world-space direction vector;
## turn ranges from -1.0 (left) to 1.0 (right).
func set_movement_input(
	direction: Vector2,
	turn: float = 0.0,
	turn_rate_multiplier: float = 1.0
) -> void:
	_movement_input = direction.limit_length(1.0)
	_turn_input = clampf(turn, -1.0, 1.0)
	_turn_rate_multiplier = maxf(turn_rate_multiplier, 0.0)


## Convenience method for steering toward a world-space point.
## Ships are assumed to face local +X (right) by default.
func steer_toward_point(world_position: Vector2) -> float:
	var to_target: Vector2 = world_position - global_position
	if to_target.is_zero_approx():
		return 0.0
	var angle_difference: float = wrapf(to_target.angle() - global_rotation, -PI, PI)
	return clampf(angle_difference / deg_to_rad(maxf(turn_rate, 1.0)), -1.0, 1.0)


func _apply_movement(delta: float) -> void:
	rotation += deg_to_rad(turn_rate * _turn_rate_multiplier) * _turn_input * delta

	if not _movement_input.is_zero_approx():
		velocity += _movement_input * acceleration * delta
	else:
		velocity = velocity.move_toward(Vector2.ZERO, linear_drag * delta)

	velocity = velocity.limit_length(movement_speed)


## Damage consumes shields first, then hull. Negative damage is ignored.
func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	_time_since_last_hit = 0.0
	var remaining_damage: float = amount
	var shield_damage: float = minf(current_shield, remaining_damage)
	current_shield -= shield_damage
	remaining_damage -= shield_damage

	var hull_damage: float = minf(current_hull, remaining_damage)
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

	var previous_hull: float = current_hull
	current_hull = minf(max_hull, current_hull + amount)
	var repaired_amount: float = current_hull - previous_hull
	if repaired_amount > 0.0:
		hull_changed.emit(current_hull, max_hull)
		repaired.emit(repaired_amount)
	return repaired_amount


## Restores shields without exceeding the maximum.
func restore_shield(amount: float) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0

	var previous_shield: float = current_shield
	current_shield = minf(max_shield, current_shield + amount)
	var restored_amount: float = current_shield - previous_shield
	if restored_amount > 0.0:
		shield_changed.emit(current_shield, max_shield)
	return restored_amount


func _update_shield_recharge(delta: float) -> void:
	if shield_recharge_rate <= 0.0 or current_shield >= max_shield:
		return
	if _time_since_last_hit < shield_recharge_delay:
		return
	restore_shield(shield_recharge_rate * delta)


func _update_hull_recharge(delta: float) -> void:
	if hull_recharge_rate <= 0.0 or current_hull >= max_hull:
		return
	if _time_since_last_hit < hull_recharge_delay:
		return
	var previous_hull: float = current_hull
	current_hull = minf(max_hull, current_hull + hull_recharge_rate * delta)
	if current_hull > previous_hull:
		hull_changed.emit(current_hull, max_hull)


func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	velocity = Vector2.ZERO
	_spawn_reward_drops()
	destroyed.emit()
	queue_free()


## Adds credits earned from combat or other rewards.
func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	credits_changed.emit(credits)


func _spawn_reward_drops() -> void:
	if not is_in_group("enemy"):
		return
	var loot_parent: Node = get_tree().current_scene
	if loot_parent == null:
		loot_parent = get_parent()
	if loot_parent == null:
		return

	var minimum_credits: int = reward_table.minimum_credits if reward_table != null else 5
	var maximum_credits: int = reward_table.maximum_credits if reward_table != null else 12
	var currency_drop: LootPickup = LOOT_PICKUP_SCENE.instantiate() as LootPickup
	if currency_drop != null:
		currency_drop.configure_currency(randi_range(
			mini(minimum_credits, maximum_credits),
			maxi(minimum_credits, maximum_credits)
		))
		loot_parent.add_child(currency_drop)
		currency_drop.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))

	if reward_table == null:
		return
	var salvage_item: SalvageItemData = reward_table.roll_item()
	if salvage_item == null:
		return
	var item_drop: LootPickup = LOOT_PICKUP_SCENE.instantiate() as LootPickup
	if item_drop == null:
		return
	item_drop.configure_item(salvage_item)
	loot_parent.add_child(item_drop)
	item_drop.global_position = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))


## Adds an item to the ship's inventory. Item representation is intentionally
## flexible until the game's inventory Resource schema is established.
func add_item(item: Variant) -> void:
	inventory.append(item)


func remove_item(item: Variant) -> bool:
	var index: int = inventory.find(item)
	if index == -1:
		return false
	inventory.remove_at(index)
	return true


## Installs a module only when its category is compatible with the hull slot.
func install_module(module: ShipModule, slot_index: int) -> bool:
	if module == null or slot_index < 0 or slot_index >= module_slots.size():
		return false
	if module_slots[slot_index] != null:
		return false
	if not _slot_accepts_module(slot_index, module):
		return false

	var previous_max_shield: float = max_shield
	module_slots[slot_index] = module
	_apply_module_stats()
	# Shield-capacity modifiers increase the ship's existing shield pool rather
	# than requiring a defense module to enable shields.
	var shield_capacity_change: float = max_shield - previous_max_shield
	if shield_capacity_change > 0.0:
		current_shield += shield_capacity_change
	current_shield = clampf(current_shield, 0.0, max_shield)
	shield_changed.emit(current_shield, max_shield)
	if module.category == ShipModule.Category.WEAPON and module.weapon_scene != null:
		var weapon_instance: Node = module.weapon_scene.instantiate()
		if weapon_instance != null:
			var ship_weapon: ShipWeapon = weapon_instance as ShipWeapon
			if ship_weapon != null:
				ship_weapon.position = _get_weapon_mount_offset(slot_index)
			add_child(weapon_instance)
			weapon_instances.append(weapon_instance)
			weapon_instances_by_slot[slot_index] = weapon_instance
	module_installed.emit(module, slot_index)
	return true


## Spreads weapon mounts vertically so multiple equipped guns are visually distinct.
func _get_weapon_mount_offset(slot_index: int) -> Vector2:
	var centered_slot: float = float(slot_index) - (float(module_slots.size() - 1) * 0.5)
	return Vector2(-4.0, centered_slot * 7.0)


func uninstall_module(slot_index: int) -> ShipModule:
	if slot_index < 0 or slot_index >= module_slots.size():
		return null

	var module: ShipModule = module_slots[slot_index]
	if module == null:
		return null

	var previous_max_shield: float = max_shield
	module_slots[slot_index] = null
	if module.category == ShipModule.Category.WEAPON and weapon_instances_by_slot.has(slot_index):
		var weapon: Node = weapon_instances_by_slot[slot_index] as Node
		if is_instance_valid(weapon):
			weapon.queue_free()
		weapon_instances.erase(weapon)
		weapon_instances_by_slot.erase(slot_index)

	module_uninstalled.emit(module, slot_index)
	_apply_module_stats()
	current_shield = minf(current_shield, max_shield)
	shield_changed.emit(current_shield, max_shield)
	return module


func is_target_in_attack_range(target: Node2D) -> bool:
	return is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range



func _capture_base_stats() -> void:
	_base_stats = {
		"max_hull": max_hull,
		"max_shield": max_shield,
		"shield_recharge_rate": shield_recharge_rate,
		"shield_recharge_delay": shield_recharge_delay,
		"movement_speed": movement_speed,
		"acceleration": acceleration,
		"linear_drag": linear_drag,
		"turn_rate": turn_rate,
		"module_slot_count": module_slot_count,
	}
	if cargo_hold_capacity <= 0:
		cargo_hold_capacity = 20
	if salvage_hold_capacity <= 0:
		salvage_hold_capacity = 10


func apply_hull(new_hull: ShipHull) -> void:
	if new_hull == null:
		return
	hull_data = new_hull
	var ship_visual: Polygon2D = get_node_or_null("ShipVisual") as Polygon2D
	if ship_visual != null:
		ship_visual.color = new_hull.preview_color
		ship_visual.polygon = new_hull.preview_polygon
	ship_name = new_hull.display_name
	hull_rarity = new_hull.rarity
	max_hull = new_hull.max_hull
	max_shield = new_hull.max_shield
	shield_recharge_rate = new_hull.shield_recharge_rate
	shield_recharge_delay = new_hull.shield_recharge_delay
	movement_speed = new_hull.movement_speed
	acceleration = new_hull.acceleration
	linear_drag = new_hull.linear_drag
	turn_rate = new_hull.turn_rate
	cargo_hold_capacity = new_hull.cargo_hold_capacity
	salvage_hold_capacity = new_hull.salvage_hold_capacity
	module_slot_count = new_hull.slot_categories.size()
	module_slots.clear()
	module_slots.resize(module_slot_count)
	_base_stats.clear()
	_capture_base_stats()
	_apply_module_stats()


func _slot_accepts_module(slot_index: int, module: ShipModule) -> bool:
	if hull_data == null or slot_index >= hull_data.slot_categories.size():
		return true
	var accepted_category: int = hull_data.slot_categories[slot_index]
	return accepted_category == -1 or accepted_category == module.category


func _apply_module_stats() -> void:
	if _base_stats.is_empty():
		_capture_base_stats()
	for stat_name: String in _base_stats.keys():
		set(stat_name, _base_stats[stat_name])
	cargo_hold_capacity = hull_data.cargo_hold_capacity if hull_data != null else 20
	salvage_hold_capacity = hull_data.salvage_hold_capacity if hull_data != null else 10
	for module: ShipModule in module_slots:
		if module == null:
			continue
		for stat_name: Variant in module.stat_modifiers.keys():
			var key: String = str(stat_name)
			if _base_stats.has(key):
				set(key, float(get(key)) + float(module.stat_modifiers[stat_name]))
		cargo_hold_capacity += module.cargo_capacity_bonus
		salvage_hold_capacity += module.salvage_capacity_bonus
	module_slot_count = module_slots.size()
	current_hull = minf(current_hull, max_hull)
	current_shield = minf(current_shield, max_shield)
	if is_inside_tree():
		hull_changed.emit(current_hull, max_hull)
		shield_changed.emit(current_shield, max_shield)


func get_slot_category(slot_index: int) -> int:
	if hull_data == null or slot_index < 0 or slot_index >= hull_data.slot_categories.size():
		return -1
	return hull_data.slot_categories[slot_index]


func clear_loadout() -> void:
	for slot_index: int in range(module_slots.size()):
		if module_slots[slot_index] != null:
			uninstall_module(slot_index)


func apply_loadout(hull: ShipHull, modules: Array[ShipModule]) -> void:
	clear_loadout()
	if hull != null:
		apply_hull(hull)
	for slot_index: int in range(mini(modules.size(), module_slots.size())):
		if modules[slot_index] != null:
			install_module(modules[slot_index], slot_index)



func _load_active_build() -> bool:
	var build: Dictionary = ShipBuildStore.get_active_build()
	if build.is_empty():
		return false
	var hull_path: String = str(build.get("hull_path", ""))
	var loaded_hull: ShipHull = load(hull_path) as ShipHull if not hull_path.is_empty() else null
	if loaded_hull == null:
		push_warning("Saved ship build references a missing hull: " + hull_path)
		return false
	apply_hull(loaded_hull)
	var module_paths: Variant = build.get("module_paths", PackedStringArray())
	for slot_index: int in range(mini(module_paths.size(), module_slots.size())):
		var module_path: String = str(module_paths[slot_index])
		if module_path.is_empty():
			continue
		var module: ShipModule = load(module_path) as ShipModule
		if module != null and not install_module(module, slot_index):
			push_warning("Could not install saved module in slot %d." % slot_index)
	return true



## Delivery cargo and salvage use separate capacity pools.
func add_cargo_item(item: Variant, units: int = 1, is_salvage: bool = false) -> bool:
	if item == null or units <= 0:
		return false
	var used_units: int = get_salvage_used_units() if is_salvage else get_cargo_used_units()
	var capacity: int = salvage_hold_capacity if is_salvage else cargo_hold_capacity
	if used_units + units > capacity:
		return false
	var entry: Dictionary = {"item": item, "units": units}
	if is_salvage:
		salvage_inventory.append(entry)
	else:
		cargo_inventory.append(entry)
	return true


func remove_cargo_item(item: Variant, is_salvage: bool = false) -> bool:
	var items: Array[Dictionary] = salvage_inventory if is_salvage else cargo_inventory
	for index: int in range(items.size()):
		if items[index].get("item") == item:
			items.remove_at(index)
			if is_salvage:
				salvage_inventory = items
			else:
				cargo_inventory = items
			return true
	return false


func get_cargo_used_units() -> int:
	return _get_used_units(cargo_inventory)


func get_salvage_used_units() -> int:
	return _get_used_units(salvage_inventory)


func _get_used_units(items: Array[Dictionary]) -> int:
	var total_units: int = 0
	for entry: Dictionary in items:
		total_units += int(entry.get("units", 0))
	return total_units
