extends Resource
class_name EnemyRewardTable

## Enemy-specific guaranteed credits and optional cascading salvage drops.

@export_group("Guaranteed Currency")
@export_range(1, 100000, 1) var minimum_credits: int = 5
@export_range(1, 100000, 1) var maximum_credits: int = 12

@export_group("Drop Gate")
## A d8 roll must land on drop_success_face before the rarity cascade begins.
@export_range(2, 100, 1) var drop_die_sides: int = 8
@export_range(1, 100, 1) var drop_success_face: int = 1

@export_group("Cascading Rarity Chances")
@export_range(0.0, 1.0, 0.01) var legendary_chance: float = 0.02
@export_range(0.0, 1.0, 0.01) var rare_chance: float = 0.08
@export_range(0.0, 1.0, 0.01) var uncommon_chance: float = 0.15
@export_range(0.0, 1.0, 0.01) var common_chance: float = 0.25

@export_group("Items By Rarity")
@export var legendary_items: Array[SalvageItemData] = []
@export var rare_items: Array[SalvageItemData] = []
@export var uncommon_items: Array[SalvageItemData] = []
@export var common_items: Array[SalvageItemData] = []


func roll_item() -> SalvageItemData:
	if randi_range(1, maxi(drop_die_sides, 1)) != clampi(drop_success_face, 1, maxi(drop_die_sides, 1)):
		return null

	if randf() < legendary_chance and not legendary_items.is_empty():
		return _random_item(legendary_items)
	if randf() < rare_chance and not rare_items.is_empty():
		return _random_item(rare_items)
	if randf() < uncommon_chance and not uncommon_items.is_empty():
		return _random_item(uncommon_items)
	if randf() < common_chance and not common_items.is_empty():
		return _random_item(common_items)
	return null


func _random_item(items: Array[SalvageItemData]) -> SalvageItemData:
	return items[randi_range(0, items.size() - 1)]
