extends Button
class_name MovementModeButton

## HUD control for switching the active player movement mode.


func _ready() -> void:
	var controller_node: Node = get_tree().get_first_node_in_group("player_controller")
	var controller: PlayerController = controller_node as PlayerController
	if controller == null:
		push_warning("MovementModeButton could not find a PlayerController.")
		return

	pressed.connect(controller.toggle_movement_mode)
	controller.movement_mode_changed.connect(_on_movement_mode_changed)
	_on_movement_mode_changed(controller.movement_mode)


func _on_movement_mode_changed(mode: int) -> void:
	match mode:
		PlayerController.MovementMode.KEYBOARD:
			text = "Movement: Keyboard"
		PlayerController.MovementMode.MOUSE:
			text = "Movement: Mouse"
