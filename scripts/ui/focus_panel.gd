extends Control
class_name FocusPanel

## A docked HQ panel that sits against the screen edge in perspective and
## flattens into the foreground when clicked.
##
## Scene setup (plain Control + one hosted Control child):
##   Dock            <- this script
##     Panel         <- any Control (e.g. a PanelContainer). Hosted in a SubViewport at runtime.
##
## The hosted panel is rendered to a texture. While docked, the texture is drawn on a
## subdivided mesh whose far edge (toward the screen centre) is shorter than its near edge
## (against the screen edge). Focusing tweens the warp to zero, so the panel arrives flat,
## full-size and fully interactive. Unfocusing tweens it back.

signal focused
signal unfocused

enum NearEdge { AUTO, LEFT, RIGHT }

@export var slot: Control
@export var dim: ColorRect
@export var focus_size: Vector2 = Vector2(760.0, 700.0)
@export_range(0.3, 1.0, 0.01) var screen_fill: float = 0.9
@export_range(0.05, 2.0, 0.05) var animation_time: float = 0.38

@export_group("Perspective")
## Which side is closest to the viewer. AUTO picks the screen edge the slot is nearest to.
@export var near_edge: NearEdge = NearEdge.AUTO
## Height of the far (screen-centre) edge relative to the near (screen) edge. Lower = stronger.
@export_range(0.4, 1.0, 0.01) var far_edge_height: float = 0.84
## Horizontal foreshortening of the whole panel while docked. Lower = narrower.
@export_range(0.5, 1.0, 0.01) var docked_width: float = 0.94
## How much the far edge is darkened while docked (0 = no shading).
@export_range(0.0, 0.8, 0.01) var far_edge_darkening: float = 0.3
## Horizontal subdivisions of the warp mesh. More = smoother perspective.
@export_range(4, 64, 1) var mesh_columns: int = 28

## 1.0 = fully docked (perspective), 0.0 = flat.
var warp: float = 1.0:
	set(value):
		warp = clampf(value, 0.0, 1.0)
		_update_mesh()

var is_focused: bool = false

var _tween: Tween
var _content: Control
var _container: SubViewportContainer
var _viewport: SubViewport
var _mesh_instance: MeshInstance2D
var _array_mesh: ArrayMesh
var _outline: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	add_to_group("hq_focus_panels")
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_render_chain()

	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(_update_mesh)
	if dim != null and not dim.gui_input.is_connected(_on_dim_input):
		dim.gui_input.connect(_on_dim_input)
	if slot != null:
		slot.resized.connect(_refresh_layout)
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout.call_deferred()


func _build_render_chain() -> void:
	for child: Node in get_children():
		if child is Control:
			_content = child as Control
			break
	if _content == null:
		push_warning("FocusPanel needs a Control child to host.")
		return

	# Input is forwarded into the SubViewport by the container (only while focused).
	_container = SubViewportContainer.new()
	_container.name = "RenderContainer"
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The container still renders/forwards input, but the mesh is what the player sees.
	_container.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_container)
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_viewport = SubViewport.new()
	_viewport.name = "RenderViewport"
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_viewport)

	# SubViewports do not inherit the parent Control theme, so hand it over explicitly.
	var inherited_theme: Theme = _find_inherited_theme()
	_content.reparent(_viewport, false)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if inherited_theme != null and _content.theme == null:
		_content.theme = inherited_theme

	_array_mesh = ArrayMesh.new()
	_mesh_instance = MeshInstance2D.new()
	_mesh_instance.name = "PerspectiveMesh"
	_mesh_instance.mesh = _array_mesh
	_mesh_instance.texture = _viewport.get_texture()
	_mesh_instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_mesh_instance)


func _find_inherited_theme() -> Theme:
	var node: Node = get_parent()
	while node != null:
		var control: Control = node as Control
		if control != null and control.theme != null:
			return control.theme
		node = node.get_parent()
	return null


# ------------------------------------------------------------------ perspective

func _is_near_left() -> bool:
	match near_edge:
		NearEdge.LEFT:
			return true
		NearEdge.RIGHT:
			return false
	if slot == null:
		return true
	var slot_center_x: float = slot.global_position.x + slot.size.x * 0.5
	return slot_center_x < get_viewport_rect().size.x * 0.5


func _update_mesh() -> void:
	if _array_mesh == null:
		return
	_array_mesh.clear_surfaces()
	var w: float = size.x
	var h: float = size.y
	if w < 2.0 or h < 2.0:
		_outline = PackedVector2Array()
		return

	var near_left: bool = _is_near_left()
	var far_height: float = lerpf(1.0, far_edge_height, warp)
	var width_factor: float = lerpf(1.0, docked_width, warp)
	# depth(t) grows linearly from 1 (near edge) to 1 / far_height (far edge).
	var depth_rate: float = 1.0 / far_height - 1.0
	var darkening: float = far_edge_darkening * warp

	var points: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	for i: int in range(mesh_columns + 1):
		var t: float = float(i) / float(mesh_columns) # 0 = near edge, 1 = far edge
		var depth: float = 1.0 + depth_rate * t
		# Projected x: spacing shrinks toward the far edge, like a receding plane.
		var x: float = w * width_factor * t * (1.0 + depth_rate) / depth
		var half_height: float = h * 0.5 / depth
		var u: float = t
		if not near_left:
			x = w - x
			u = 1.0 - t
		var shade: float = 1.0 - darkening * t
		points.append(Vector2(x, h * 0.5 - half_height))
		points.append(Vector2(x, h * 0.5 + half_height))
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		colors.append(Color(shade, shade, shade, 1.0))
		colors.append(Color(shade, shade, shade, 1.0))

	for i: int in range(mesh_columns):
		var a: int = i * 2 # top_i; a + 1 = bottom_i; a + 2 = top_i+1; a + 3 = bottom_i+1
		indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var last: int = mesh_columns * 2
	_outline = PackedVector2Array([points[0], points[last], points[last + 1], points[1]])


## Global Y of the top of the far (screen-centre) edge while docked. The lowest point of
## the panel's top edge, so neighbouring UI can line up with it.
func get_docked_inner_top() -> float:
	var home_size: Vector2 = _home_size()
	var home_position: Vector2 = _home_position_for(home_size)
	return home_position.y + home_size.y * 0.5 * (1.0 - far_edge_height)


## Global Y of the bottom of the far (screen-centre) edge while docked.
func get_docked_inner_bottom() -> float:
	var home_size: Vector2 = _home_size()
	var home_position: Vector2 = _home_position_for(home_size)
	return home_position.y + home_size.y - home_size.y * 0.5 * (1.0 - far_edge_height)


## Hit-testing follows the slanted shape while docked, so the empty corners are not clickable.
func _has_point(point: Vector2) -> bool:
	if is_focused or _outline.size() < 3:
		return Rect2(Vector2.ZERO, size).has_point(point)
	return Geometry2D.is_point_in_polygon(point, _outline)


# ----------------------------------------------------------------- focus / dock

func focus() -> void:
	if is_focused:
		return

	# Only one panel may own the shared backdrop at a time.
	for node: Node in get_tree().get_nodes_in_group("hq_focus_panels"):
		var other: FocusPanel = node as FocusPanel
		if other != null and other != self and other.is_focused:
			other._snap_home()

	is_focused = true
	z_index = 10
	modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _container != null:
		_container.mouse_filter = Control.MOUSE_FILTER_STOP
	if dim != null:
		if not dim.visible:
			dim.modulate.a = 0.0
			dim.visible = true
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var target_size: Vector2 = _focus_target_size()
	_animate_to(_focus_position_for(target_size), target_size, 1.0, 0.0)
	focused.emit()


func unfocus() -> void:
	if not is_focused:
		return
	is_focused = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _container != null:
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var home_size: Vector2 = _home_size()
	var tween: Tween = _animate_to(_home_position_for(home_size), home_size, 0.0, 1.0)
	tween.chain().tween_callback(_on_unfocus_finished)
	unfocused.emit()


func _snap_home() -> void:
	if _tween != null:
		_tween.kill()
	is_focused = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _container != null:
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warp = 1.0
	size = _home_size()
	global_position = _home_position_for(size)
	z_index = 1
	modulate = Color.WHITE


func _on_unfocus_finished() -> void:
	if is_focused:
		return
	z_index = 1
	# Another panel may have taken over the backdrop while this one was returning.
	if dim != null and not _any_panel_focused():
		dim.visible = false
		dim.modulate.a = 0.0


func _any_panel_focused() -> bool:
	for node: Node in get_tree().get_nodes_in_group("hq_focus_panels"):
		var panel: FocusPanel = node as FocusPanel
		if panel != null and panel.is_focused:
			return true
	return false


func _animate_to(target_position: Vector2, target_size: Vector2, dim_alpha: float, target_warp: float) -> Tween:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", target_position, animation_time)
	_tween.tween_property(self, "size", target_size, animation_time)
	_tween.tween_property(self, "warp", target_warp, animation_time)
	if dim != null:
		_tween.tween_property(dim, "modulate:a", dim_alpha, animation_time)
	return _tween


func _refresh_layout() -> void:
	if _tween != null and _tween.is_running():
		return
	if is_focused:
		var target_size: Vector2 = _focus_target_size()
		size = target_size
		global_position = _focus_position_for(target_size)
	else:
		size = _home_size()
		global_position = _home_position_for(size)
	_update_mesh()


func _home_size() -> Vector2:
	if slot == null:
		return focus_size
	var available: Vector2 = slot.size
	return Vector2(
		maxf(220.0, minf(available.x, focus_size.x)),
		maxf(260.0, minf(available.y, focus_size.y))
	)


func _home_position_for(target_size: Vector2) -> Vector2:
	if slot == null:
		return global_position
	return slot.global_position + (slot.size - target_size) * 0.5


func _focus_target_size() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var limit: Vector2 = viewport_size * screen_fill
	var ratio: float = minf(1.0, minf(limit.x / focus_size.x, limit.y / focus_size.y))
	return focus_size * ratio


func _focus_position_for(target_size: Vector2) -> Vector2:
	return (get_viewport_rect().size - target_size) * 0.5


func _set_hover(hovered: bool) -> void:
	if is_focused:
		return
	modulate = Color(1.12, 1.12, 1.12) if hovered else Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if is_focused:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		focus()
		accept_event()


func _on_dim_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if is_focused and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		unfocus()
		dim.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_focused and event.is_action_pressed("ui_cancel"):
		unfocus()
		get_viewport().set_input_as_handled()
