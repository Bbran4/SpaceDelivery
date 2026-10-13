extends Control
class_name HQScreen

@onready var ship_builder: ShipBuilder = %ShipBuilder
@onready var upgrades_overlay: Control = %UpgradesOverlay


func _on_shipyard_pressed() -> void:
	ship_builder.show_builder()


func _on_test_flight_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/hud_test.tscn")


func _on_upgrades_pressed() -> void:
	upgrades_overlay.visible = true


func _on_upgrades_close_pressed() -> void:
	upgrades_overlay.visible = false
