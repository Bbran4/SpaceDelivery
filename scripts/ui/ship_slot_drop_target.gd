extends PanelContainer
class_name ShipSlotDropTarget

var slot_index: int = -1
var accepted_category: int = -1
var builder: Control
var slot_title: Label
var module_title: Label
var module_path: String = ""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("module_path"):
		return false
	var incoming_category: int = int(data.get("category", -2))
	return accepted_category == -1 or incoming_category == accepted_category


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	builder.call("equip_module", slot_index, str(data.get("module_path", "")))


func set_slot_content(title: String, module: ShipModule, path: String) -> void:
	module_path = path
	if slot_title != null:
		slot_title.text = title
	if module_title != null:
		module_title.text = "Empty" if module == null else module.display_name



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if builder != null:
				builder.call("open_module_picker", slot_index)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if builder != null:
				builder.call("equip_module", slot_index, "")
			accept_event()
