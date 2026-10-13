extends Node
class_name PlayerController

## Reads movement and targeting input. Ship handles movement and durability.

signal movement_mode_changed(mode: MovementMode)
signal target_changed(target: Ship)

enum MovementMode {
	KEYBOARD,
	MOUSE
}

@export var ship: Ship
@export var target_reticle_scene: PackedScene
@export var target_hud_scene: PackedScene

@export_group("Input")
@export var turn_left_action: StringName = &"left"
@export var turn_right_action: StringName = &"right"
@export var thrust_forward_action: StringName = &"up"
@export var thrust_reverse_action: StringName = &"down"

@export_group("Mouse Movement")
@export_range(0.0, 800.0, 1.0) var mouse_stop_distance: float = 140.0
@export_range(1.0, 10.0, 0.1) var mouse_turn_rate_multiplier: float = 4.0
@export_range(0.1, 2.0, 0.05) var mouse_velocity_response_time: float = 0.4
@export_range(1.0, 100.0, 1.0) var mouse_target_radius: float = 22.0
@export_range(10.0, 100.0, 1.0) var keyboard_reticle_radius: float = 32.0

var movement_mode: MovementMode = MovementMode.KEYBOARD
var current_target: Ship
var _reticle: TargetReticle
var _cycled_target: Ship


func _ready() -> void:
	add_to_group("player_controller")
	if ship == null:
		ship = get_parent() as Ship

	if target_reticle_scene != null and get_tree().current_scene != null:
		_reticle = target_reticle_scene.instantiate() as TargetReticle
		if _reticle != null:
			get_tree().current_scene.add_child.call_deferred(_reticle)
			_reticle.player_ship = ship
			_reticle.target_radius = mouse_target_radius

	if target_hud_scene != null and get_tree().current_scene != null:
		var target_hud: Node = target_hud_scene.instantiate()
		get_tree().current_scene.add_child.call_deferred(target_hud)


func _process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return
	_update_targeting()
	if movement_mode == MovementMode.MOUSE and Input.is_key_pressed(KEY_TAB):
		if not _tab_was_pressed:
			_cycle_target()
		_tab_was_pressed = true
	else:
		_tab_was_pressed = false


var _tab_was_pressed: bool = false


func _physics_process(_delta: float) -> void:
	if ship == null or ship.is_destroyed:
		return

	match movement_mode:
		MovementMode.KEYBOARD:
			_process_keyboard_movement()
		MovementMode.MOUSE:
			_process_mouse_movement()


func _update_targeting() -> void:
	var new_target: Ship = null
	if movement_mode == MovementMode.MOUSE:
		if is_instance_valid(_cycled_target) and not _cycled_target.is_destroyed and _cycled_target.is_inside_tree():
			if ship.global_position.distance_to(_cycled_target.global_position) <= _get_player_weapon_range():
				new_target = _cycled_target
			else:
				_cycled_target = null
		if new_target == null:
			new_target = _find_nearest_enemy_in_range()
	else:
		new_target = _find_enemy_under_mouse()

	if not is_instance_valid(new_target) or new_target.is_destroyed or not new_target.is_inside_tree():
		new_target = null

	# The keyboard-mode weapon target is only active while the cursor is over an
	# enemy, but the HUD keeps the last selected enemy until it dies or changes.
	if new_target != null:
		if new_target != current_target:
			current_target = new_target
			target_changed.emit(current_target)
	elif movement_mode == MovementMode.MOUSE:
		if is_instance_valid(current_target) or current_target != null:
			current_target = null
			target_changed.emit(null)
	else:
		current_target = null

	if current_target != null and not is_instance_valid(current_target):
		current_target = null
		if movement_mode == MovementMode.MOUSE:
			target_changed.emit(null)
	elif is_instance_valid(current_target) and (current_target.is_destroyed or not current_target.is_inside_tree()):
		current_target = null
		if movement_mode == MovementMode.MOUSE:
			target_changed.emit(null)

	if is_instance_valid(_reticle):
		_reticle.follow_mouse = movement_mode == MovementMode.KEYBOARD
		_reticle.target = current_target if movement_mode == MovementMode.MOUSE and is_instance_valid(current_target) else null
		_reticle.ring_radius = keyboard_reticle_radius if movement_mode == MovementMode.KEYBOARD else 18.0

