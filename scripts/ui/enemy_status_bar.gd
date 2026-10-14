extends Node2D
class_name EnemyStatusBar

## Two compact bars above a ship. Appears when either resource is below full
## and hides only after both hull and shield are fully restored.

@export var ship: Ship
@export var vertical_offset: float = 30.0

@onready var hull_bar: ProgressBar = %HullBar
@onready var shield_bar: ProgressBar = %ShieldBar
@onready var bars: Control = %Bars


func _ready() -> void:
	top_level = true
	if ship == null:
		ship = get_parent() as Ship
	if ship == null:
		push_warning("EnemyStatusBar requires a Ship.")
		return

	ship.hull_changed.connect(_on_hull_changed)
	ship.shield_changed.connect(_on_shield_changed)
	_update_hull(ship.current_hull, ship.max_hull)
	_update_shield(ship.current_shield, ship.max_shield)
	_update_visibility()
	_update_position()


func _process(_delta: float) -> void:
	if is_instance_valid(ship):
		_update_position()


func _update_position() -> void:
	global_position = ship.global_position + Vector2(0.0, -vertical_offset)
	global_rotation = 0.0


func _on_hull_changed(current: float, maximum: float) -> void:
	hull_bar.max_value = maximum
	hull_bar.value = current
	_update_visibility()


func _on_shield_changed(current: float, maximum: float) -> void:
	shield_bar.max_value = maximum
	shield_bar.value = current
	_update_visibility()


func _update_hull(current: float, maximum: float) -> void:
	hull_bar.max_value = maximum
	hull_bar.value = current


func _update_shield(current: float, maximum: float) -> void:
	shield_bar.max_value = maximum
	shield_bar.value = current


func _update_visibility() -> void:
	if ship == null:
		bars.visible = false
		return
	var hull_full: bool = is_equal_approx(ship.current_hull, ship.max_hull)
	var shield_full: bool = is_equal_approx(ship.current_shield, ship.max_shield)
	bars.visible = not (hull_full and shield_full)
