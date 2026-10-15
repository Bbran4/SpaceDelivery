extends PanelContainer
class_name FocusPanel

## A console panel that rests visibly inside a layout slot at reduced scale.
## Clicking it animates it to the centre of the screen, dims everything behind
## it, and lets the player interact with it. Esc, the dim backdrop, or
## unfocus() sends it back to its slot.
##
## The panel is authored at `focus_size` and simply scaled down at rest, so the
## animation only tweens position and scale (no layout work mid-animation).
## It must be a child of a plain Control, not a Container.

signal focused
signal unfocused

const GROUP: StringName = &"hq_focus_panels"

## Empty Control in the HQ layout that defines where this panel rests.
@export var slot: Control
## Shared full-screen ColorRect behind focused panels.
@export var dim: ColorRect
## The size the panel is authored at, and shown at when focused.
@export var focus_size: Vector2 = Vector2(460.0, 600.0)
@export_range(0.2, 1.0, 0.01) var min_home_scale: float = 0.4
@export_range(0.2, 1.0, 0.01) var max_home_scale: float = 0.8
@export_range(0.3, 1.0, 0.01) var screen_fill: float = 0.94
@export_range(0.05, 2.0, 0.05) var animation_time: float = 0.35

var is_focused: bool = false
var _tween: Tween
var _click_catcher: Control


func _ready() -> void:
	if slot == null:
		push_warning("FocusPanel '%s' has no slot assigned; it cannot rest in the layout." % name)
	if dim == null:
		push_warning("FocusPanel '%s' has no dim backdrop assigned." % name)

	add_to_group(GROUP)
	custom_minimum_size = focus_size
	size = focus_size
	# Scale from the top-left corner so global_position is simply the visual
	# top-left. (With a centred pivot, global_position shifts as scale changes.)
	pivot_offset = Vector2.ZERO
	z_index = 1
	clip_contents = true
	# Autowrap labels report a huge minimum height while they are still
	# unwrapped, which can inflate this container on the first layout pass.
	# Containers never shrink back on their own, so restore the authored size.
	minimum_size_changed.connect(_restore_authored_size)

	# Covers the content while resting so inner buttons cannot be pressed
	# through the shrunken panel. Any left click focuses the panel.
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

	if slot != null:
		# item_rect_changed fires on position changes as well as resizes.
		slot.item_rect_changed.connect(_refresh_layout)
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout.call_deferred()


func focus() -> void:
	if is_focused:
		return
	for other: Node in get_tree().get_nodes_in_group(GROUP):
		if other != self and other is FocusPanel:
			(other as FocusPanel).unfocus(true)
	is_focused = true
	z_index = 10
	modulate = Color.WHITE
	_click_catcher.visible = false
	if dim != null:
		dim.visible = true
	_animate_to(_focus_position(), _focus_scale(), 1.0)
	focused.emit()


## keep_dim is used when another panel is taking over, so the backdrop stays.
func unfocus(keep_dim: bool = false) -> void:
	if not is_focused:
		return
	is_focused = false
	var tween: Tween = _animate_to(_home_position(), _home_scale(), -1.0 if keep_dim else 0.0)
	tween.chain().tween_callback(_on_unfocus_finished)
	unfocused.emit()


func _on_unfocus_finished() -> void:
	if is_focused:
		return
	z_index = 1
	_click_catcher.visible = true
	if dim != null and not _any_panel_focused():
		dim.visible = false


func _any_panel_focused() -> bool:
	for other: Node in get_tree().get_nodes_in_group(GROUP):
		if other is FocusPanel and (other as FocusPanel).is_focused:
			return true
	return false


## A negative dim_alpha leaves the backdrop untouched.
func _animate_to(target_position: Vector2, target_scale: float, dim_alpha: float) -> Tween:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_position, animation_time)
	_tween.tween_property(self, "scale", Vector2.ONE * target_scale, animation_time)
	if dim != null and dim_alpha >= 0.0:
		_tween.tween_property(dim, "modulate:a", dim_alpha, animation_time)
	return _tween


func _restore_authored_size() -> void:
	if not size.is_equal_approx(focus_size):
		set_deferred("size", focus_size)


func _refresh_layout() -> void:
	if _tween != null and _tween.is_running():
		return
	if is_focused:
		scale = Vector2.ONE * _focus_scale()
		global_position = _focus_position()
	else:
		scale = Vector2.ONE * _home_scale()
		global_position = _home_position()


func _home_scale() -> float:
	if slot == null or focus_size.x <= 0.0 or focus_size.y <= 0.0:
		return min_home_scale
	return clampf(minf(slot.size.x / focus_size.x, slot.size.y / focus_size.y), min_home_scale, max_home_scale)


func _home_position() -> Vector2:
	if slot == null:
		return global_position
	return slot.global_position + slot.size * 0.5 - focus_size * _home_scale() * 0.5


func _focus_scale() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	return minf(1.0, minf(viewport_size.x * screen_fill / focus_size.x, viewport_size.y * screen_fill / focus_size.y))


func _focus_position() -> Vector2:
	return get_viewport_rect().size * 0.5 - focus_size * _focus_scale() * 0.5


func _set_hover(hovered: bool) -> void:
	if is_focused:
		return
	modulate = Color(1.18, 1.18, 1.18) if hovered else Color.WHITE


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
