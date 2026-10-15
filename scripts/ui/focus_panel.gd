extends PanelContainer
class_name FocusPanel

signal focused
signal unfocused

@export var slot: Control
@export var dim: ColorRect
@export var focus_size: Vector2 = Vector2(760.0, 700.0)
@export_range(0.3, 1.0, 0.01) var screen_fill: float = 0.9
@export_range(0.05, 2.0, 0.05) var animation_time: float = 0.38

var is_focused: bool = false
var _tween: Tween
var _click_catcher: Control


func _ready() -> void:
	add_to_group("hq_focus_panels")
	z_index = 1
	_click_catcher = Control.new()
	_click_catcher.name = "ClickCatcher"
	_click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	if slot != null:
		slot.resized.connect(_refresh_layout)
	get_viewport().size_changed.connect(_refresh_layout)
	resized.connect(_refresh_catcher)
	_refresh_layout.call_deferred()


func focus() -> void:
	if is_focused:
		return
	for panel in get_tree().get_nodes_in_group("hq_focus_panels"):
		if panel != self and panel is FocusPanel:
			panel.unfocus()
	is_focused = true
	z_index = 10
	modulate = Color.WHITE
	_click_catcher.visible = false
	if dim != null:
		dim.visible = true
	_animate_to(_focus_position(), _focus_target_size(), 1.0)
	focused.emit()


func unfocus() -> void:
	if not is_focused:
		return
	is_focused = false
	var tween: Tween = _animate_to(_home_position(), _home_size(), 0.0)
	tween.chain().tween_callback(_on_unfocus_finished)
	unfocused.emit()


func _on_unfocus_finished() -> void:
	if is_focused:
		return
	z_index = 1
	_click_catcher.visible = true
	if dim != null:
		dim.visible = false


func _animate_to(target_position: Vector2, target_size: Vector2, dim_alpha: float) -> Tween:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_position, animation_time)
	_tween.tween_property(self, "size", target_size, animation_time)
	if dim != null:
		_tween.tween_property(dim, "modulate:a", dim_alpha, animation_time)
	return _tween


func _refresh_layout() -> void:
	if _tween != null and _tween.is_running():
		return
	if is_focused:
		size = _focus_target_size()
		global_position = _focus_position()
	else:
		size = _home_size()
		global_position = _home_position()
	_refresh_catcher()


func _refresh_catcher() -> void:
	if _click_catcher != null:
		_click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _home_size() -> Vector2:
	if slot == null:
		return focus_size
	var available: Vector2 = slot.size
	return Vector2(
		maxf(220.0, minf(available.x, focus_size.x)),
		maxf(260.0, minf(available.y, focus_size.y))
	)


func _home_position() -> Vector2:
	if slot == null:
		return global_position
	return slot.global_position + (slot.size - size) * 0.5


func _focus_target_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var limit: Vector2 = viewport_size * screen_fill
	var ratio: float = minf(1.0, minf(limit.x / focus_size.x, limit.y / focus_size.y))
	return focus_size * ratio


func _focus_position() -> Vector2:
	return (get_viewport_rect().size - size) * 0.5


func _set_hover(hovered: bool) -> void:
	if is_focused:
		return
	modulate = Color(1.12, 1.12, 1.12) if hovered else Color.WHITE


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		focus()
		_click_catcher.accept_event()


func _on_dim_input(event: InputEvent) -> void:
	if is_focused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unfocus()


func _unhandled_input(event: InputEvent) -> void:
	if is_focused and event.is_action_pressed("ui_cancel"):
		unfocus()
		get_viewport().set_input_as_handled()
