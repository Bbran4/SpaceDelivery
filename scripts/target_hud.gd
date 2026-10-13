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
	visible = is_instance_valid(target) and not target.is_destroyed
	if visible:
		_update_target_readout()
		if not target.hull_changed.is_connected(_on_hull_changed):
			target.hull_changed.connect(_on_hull_changed)
		if not target.shield_changed.is_connected(_on_shield_changed):
			target.shield_changed.connect(_on_shield_changed)


func _process(_delta: float) -> void:
	if not is_instance_valid(target) or target.is_destroyed:
		visible = false
		return
	_update_target_readout()


func _update_target_readout() -> void:
	target_name_label.text = target.ship_name if not target.ship_name.is_empty() else "Enemy"
	status_label.text = "HULL %d / %d     SHIELD %d / %d" % [
		roundi(target.current_hull), roundi(target.max_hull),
		roundi(target.current_shield), roundi(target.max_shield)
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
