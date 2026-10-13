extends PanelContainer
class_name ShipSlotDropTarget

var slot_index: int = -1
var accepted_category: int = -1
var builder: ShipBuilder
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
	builder.equip_module(slot_index, str(data.get("module_path", "")))


func set_slot_content(title: String, module: ShipModule, path: String) -> void:
	module_path = path
	if slot_title != null:
		slot_title.text = title
	if module_title != null:
		module_title.text = "Empty slot · drop module here" if module == null else module.display_name
