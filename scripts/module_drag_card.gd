extends PanelContainer
class_name ModuleDragCard

var module_path: String = ""
var module_data: ShipModule
var builder: Control


func _get_drag_data(_at_position: Vector2) -> Variant:
	if module_data == null:
		return null
	var preview: Label = Label.new()
	preview.text = module_data.display_name
	preview.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	set_drag_preview(preview)
	return {"module_path": module_path, "category": module_data.category}


func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false
