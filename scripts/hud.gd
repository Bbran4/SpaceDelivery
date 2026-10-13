extends Control
class_name ShipHUD

## Displays ship durability without putting UI logic in the Ship class.

@export var ship: Ship

@onready var hull_label: Label = %HullLabel
@onready var hull_bar: ProgressBar = %HullBar
@onready var shield_label: Label = %ShieldLabel
@onready var shield_bar: ProgressBar = %ShieldBar


func _ready() -> void:
	if ship == null:
		var controller: PlayerController = get_tree().get_first_node_in_group("player_controller") as PlayerController
		if controller != null:
			ship = controller.ship

	if ship == null:
		push_warning("ShipHUD could not find a Ship. Assign the Ship property in the Inspector.")
		return

	ship.hull_changed.connect(_on_hull_changed)
	ship.shield_changed.connect(_on_shield_changed)

	# Signals may have fired before the HUD entered the scene tree.
	_on_hull_changed(ship.current_hull, ship.max_hull)
	_on_shield_changed(ship.current_shield, ship.max_shield)


func _on_hull_changed(current_hull: float, maximum_hull: float) -> void:
	hull_bar.max_value = maximum_hull
	hull_bar.value = current_hull
	hull_label.text = "HULL  %s / %s" % [_format_value(current_hull), _format_value(maximum_hull)]


func _on_shield_changed(current_shield: float, maximum_shield: float) -> void:
	shield_bar.max_value = maximum_shield
	shield_bar.value = current_shield
	shield_label.text = "SHIELD  %s / %s" % [_format_value(current_shield), _format_value(maximum_shield)]


func _format_value(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value
