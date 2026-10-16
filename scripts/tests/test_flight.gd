extends Node2D

## Sandbox opened by HQ's Test Flight button. Flies the active build against a few hostiles.
## No contract is running, so nothing here affects credits or mission state.

const HQ_SCENE_PATH: String = "res://scenes/hq.tscn"

@onready var player_ship: Ship = $PlayerShip
@onready var spawner: EncounterSpawner = $EncounterSpawner

var _banner: Label
var _hostiles_spawned: bool = false
var _player_destroyed: bool = false


func _ready() -> void:
	_build_overlay()
	player_ship.destroyed.connect(_on_player_destroyed, CONNECT_ONE_SHOT)
	_spawn_hostiles.call_deferred()


func _process(_delta: float) -> void:
	if _player_destroyed or not _hostiles_spawned:
		return
	if get_tree().get_nodes_in_group("enemy").is_empty():
		_banner.text = "TEST AREA CLEAR  /  RESTART TO FIGHT AGAIN"


func _spawn_hostiles() -> void:
	spawner.spawn_encounter()
	_hostiles_spawned = true


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_banner = Label.new()
	_banner.text = "TEST FLIGHT  /  NO CONTRACT ACTIVE  /  NOTHING IS SAVED"
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 18.0
	_banner.offset_bottom = 48.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color(0.78, 0.9, 0.98))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.anchor_top = 1.0
	buttons.anchor_bottom = 1.0
	buttons.offset_left = 24.0
	buttons.offset_top = -66.0
	buttons.offset_bottom = -18.0
	buttons.add_theme_constant_override("separation", 10)
	layer.add_child(buttons)

	var return_button: Button = Button.new()
	return_button.text = "RETURN TO HQ"
	return_button.custom_minimum_size = Vector2(190, 48)
	return_button.pressed.connect(_return_to_hq)
	buttons.add_child(return_button)

	var restart_button: Button = Button.new()
	restart_button.text = "RESTART TEST"
	restart_button.custom_minimum_size = Vector2(190, 48)
	restart_button.pressed.connect(_restart)
	buttons.add_child(restart_button)


func _on_player_destroyed() -> void:
	_player_destroyed = true
	_banner.text = "SHIP DESTROYED  /  RESTART OR RETURN TO HQ"


func _restart() -> void:
	get_tree().reload_current_scene()


func _return_to_hq() -> void:
	get_tree().change_scene_to_file(HQ_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_hq()
