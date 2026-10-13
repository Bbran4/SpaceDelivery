extends CanvasLayer
class_name TargetHUD

@onready var target_name_label: Label = %TargetName
@onready var status_label: Label = %TargetStatus
@onready var hull_bar: ProgressBar = %TargetHullBar
@onready var shield_bar: ProgressBar = %TargetShieldBar

var controller: PlayerController
var target: Ship


func _ready() -> void:
	controller = get_tree().get_first_node_in_group("player_controller") as PlayerController
	if controller == null:
		visible = false
		return
	controller.target_changed.connect(_on_target_changed)
	_on_target_changed(controller.current_target)


func _on_target_changed(new_target: Ship) -> void:
	target = new_target
	if not is_instance_valid(target) or target.is_destroyed:
		_show_no_target()
		return
	visible = true
	_update_target_readout()
	if not target.hull_changed.is_connected(_on_hull_changed):
		target.hull_changed.connect(_on_hull_changed)
	if not target.shield_changed.is_connected(_on_shield_changed):
		target.shield_changed.connect(_on_shield_changed)


func _process(_delta: float) -> void:
	if not is_instance_valid(target) or target.is_destroyed:
		return
	_update_target_readout()


func _show_no_target() -> void:
	visible = true
	target_name_label.text = "NO TARGET"
	status_label.text = "Hover over an enemy to target"
	hull_bar.max_value = 1.0
	hull_bar.value = 0.0
	shield_bar.max_value = 1.0
	shield_bar.value = 0.0


func _update_target_readout() -> void:
	target_name_label.text = target.ship_name if not target.ship_name.is_empty() else "Enemy"
	var range_limit: float = 300.0
	for weapon_node: Node in controller.ship.weapon_instances:
		var weapon: ShipWeapon = weapon_node as ShipWeapon
		if weapon != null and weapon.weapon_data != null:
			range_limit = maxf(range_limit, weapon.weapon_data.range)
	var in_range: bool = controller.ship.global_position.distance_to(target.global_position) <= range_limit
	var range_text: String = "" if in_range else "  |  OUT OF RANGE"
	status_label.text = "HULL %d / %d     SHIELD %d / %d%s" % [
		roundi(target.current_hull), roundi(target.max_hull),
		roundi(target.current_shield), roundi(target.max_shield),
		range_text
	]
	hull_bar.max_value = target.max_hull
	hull_bar.value = target.current_hull
	shield_bar.max_value = target.max_shield
	shield_bar.value = target.current_shield


func _on_hull_changed(_current: float, _maximum: float) -> void:
	if is_instance_valid(target):
		_update_target_readout()


func _on_shield_changed(_current: float, _maximum: float) -> void:
	if is_instance_valid(target):
		_update_target_readout()
