extends PanelContainer
class_name FocusPanel
signal focused
signal unfocused
@export var slot: Control
@export var dim: ColorRect
@export var focus_size := Vector2(680.0, 620.0)
@export_range(0.2, 1.0, 0.01) var min_home_scale := 0.3
@export_range(0.2, 1.0, 0.01) var max_home_scale := 0.7
@export_range(0.3, 1.0, 0.01) var screen_fill := 0.92
@export_range(0.05, 2.0, 0.05) var animation_time := 0.35
var is_focused := false
var _tween: Tween
var _click_catcher: Control
func _ready() -> void:
	add_to_group("hq_focus_panels")
	custom_minimum_size = focus_size
	size = focus_size
	pivot_offset = size * 0.5
	z_index = 1
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_click_catcher = Control.new()
	_click_catcher.name = "ClickCatcher"
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_click_catcher.gui_input.connect(_on_catcher_input)
	_click_catcher.mouse_entered.connect(_set_hover.bind(true))
	_click_catcher.mouse_exited.connect(_set_hover.bind(false))
	add_child(_click_catcher)
	if dim != null:
		dim.visible = false
		dim.modulate.a = 0.0
		dim.gui_input.connect(_on_dim_input)
	if slot != null: slot.resized.connect(_refresh_layout)
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout.call_deferred()
func focus() -> void:
	if is_focused: return
	for panel in get_tree().get_nodes_in_group("hq_focus_panels"):
		if panel != self and panel is FocusPanel: panel.unfocus()
	is_focused = true
	z_index = 10
	modulate = Color.WHITE
	_click_catcher.visible = false
	if dim != null: dim.visible = true
	_animate_to(_focus_position(), _focus_scale(), 1.0)
	focused.emit()
func unfocus() -> void:
	if not is_focused: return
	is_focused = false
	var tween := _animate_to(_home_position(), _home_scale(), 0.0)
	tween.chain().tween_callback(_on_unfocus_finished)
	unfocused.emit()
func _on_unfocus_finished() -> void:
	if is_focused: return
	z_index = 1
	_click_catcher.visible = true
	if dim != null: dim.visible = false
func _animate_to(target_position: Vector2, target_scale: float, dim_alpha: float) -> Tween:
	if _tween != null: _tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_position, animation_time)
	_tween.tween_property(self, "scale", Vector2.ONE * target_scale, animation_time)
	if dim != null: _tween.tween_property(dim, "modulate:a", dim_alpha, animation_time)
	return _tween
func _refresh_layout() -> void:
	if _tween != null and _tween.is_running(): return
	if is_focused:
		global_position = _focus_position()
		scale = Vector2.ONE * _focus_scale()
	else:
		global_position = _home_position()
		scale = Vector2.ONE * _home_scale()
func _home_scale() -> float:
	if slot == null or size.x <= 0.0 or size.y <= 0.0: return min_home_scale
	return clampf(minf(slot.size.x / size.x, slot.size.y / size.y), min_home_scale, max_home_scale)
func _home_position() -> Vector2:
	if slot == null: return global_position
	return slot.global_position + slot.size * 0.5 - size * 0.5
func _focus_scale() -> float:
	var v := get_viewport_rect().size
	return minf(1.0, minf(v.x * screen_fill / size.x, v.y * screen_fill / size.y))
func _focus_position() -> Vector2:
	return get_viewport_rect().size * 0.5 - size * 0.5
func _set_hover(hovered: bool) -> void:
	if is_focused: return
	modulate = Color(1.18, 1.18, 1.18) if hovered else Color.WHITE
func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		focus()
		_click_catcher.accept_event()
func _on_dim_input(event: InputEvent) -> void:
	if is_focused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: unfocus()
func _unhandled_input(event: InputEvent) -> void:
	if is_focused and event.is_action_pressed("ui_cancel"):
		unfocus()
		get_viewport().set_input_as_handled()
