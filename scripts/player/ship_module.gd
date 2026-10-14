extends Resource
class_name ShipModule

## Data definition for any equippable ship module.
## Weapons are modules too; weapon-specific behavior can be provided by a scene.

enum Category {
	WEAPON,
	DEFENSE,
	ENGINE,
	CARGO,
	UTILITY,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var module_id: StringName = &""
@export var display_name: String = "New Module"
@export_multiline var description: String = ""
@export var category: Category = Category.UTILITY
@export var rarity: Rarity = Rarity.COMMON

## Optional stat changes applied by the ship/loadout system.
## Example keys: "max_hull", "max_shield", "movement_speed", "damage".
@export var stat_modifiers: Dictionary = {}

## Used by WEAPON modules to spawn their runtime weapon behavior.
## Non-weapon modules can leave this empty.
@export var weapon_scene: PackedScene

## Optional cargo capacity granted by this module.
@export_range(0, 100000, 1) var cargo_capacity_bonus: int = 0
@export_range(0, 100000, 1) var salvage_capacity_bonus: int = 0
