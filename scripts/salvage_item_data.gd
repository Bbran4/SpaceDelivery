extends Resource
class_name SalvageItemData

## Data for a recoverable upgrade component or salvage item.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var item_id: StringName = &"scrap_component"
@export var display_name: String = "Scrap Component"
@export_multiline var description: String = "A recoverable component."
@export var rarity: Rarity = Rarity.COMMON
@export_range(0, 100000, 1) var credit_value: int = 10
