extends Area2D
class_name LootPickup

## A lightweight collectible. Currency is credited immediately; components use salvage capacity.

enum PickupType {
	CURRENCY,
	ITEM,
}

@export var pickup_radius: float = 28.0
@export var currency_amount: int = 0
@export var item_data: SalvageItemData

var pickup_type: PickupType = PickupType.CURRENCY
var _visual: Polygon2D


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	_update_visual()


func configure_currency(amount: int) -> void:
	pickup_type = PickupType.CURRENCY
	currency_amount = maxi(amount, 1)
	item_data = null
	_update_visual()


func configure_item(item: SalvageItemData) -> void:
	if item == null:
		return
	pickup_type = PickupType.ITEM
	item_data = item
	currency_amount = 0
	_update_visual()


func _process(_delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group("player_ship"):
		var player_ship: Ship = node as Ship
		if player_ship == null or player_ship.is_destroyed or not player_ship.is_inside_tree():
			continue
		if global_position.distance_to(player_ship.global_position) > pickup_radius:
			continue

		if pickup_type == PickupType.CURRENCY:
			player_ship.add_credits(currency_amount)
			queue_free()
			return
		if item_data != null and player_ship.add_cargo_item(item_data, 1, true):
			queue_free()
			return


func _update_visual() -> void:
	if _visual == null:
		return
	if pickup_type == PickupType.CURRENCY:
		_visual.color = Color(1.0, 0.78, 0.18, 1.0)
		_visual.polygon = PackedVector2Array([
			Vector2(0, -7), Vector2(7, 0), Vector2(0, 7), Vector2(-7, 0)
		])
		return

	var rarity_color: Color = Color(0.72, 0.78, 0.85, 1.0)
	if item_data != null:
		match item_data.rarity:
			SalvageItemData.Rarity.UNCOMMON:
				rarity_color = Color(0.25, 0.9, 0.45, 1.0)
			SalvageItemData.Rarity.RARE:
				rarity_color = Color(0.25, 0.6, 1.0, 1.0)
			SalvageItemData.Rarity.EPIC:
				rarity_color = Color(0.72, 0.35, 1.0, 1.0)
			SalvageItemData.Rarity.LEGENDARY:
				rarity_color = Color(1.0, 0.55, 0.12, 1.0)
	_visual.color = rarity_color
	_visual.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(6, -4), Vector2(6, 4),
		Vector2(0, 8), Vector2(-6, 4), Vector2(-6, -4)
	])
