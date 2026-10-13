extends Control
class_name HQScreen

@onready var ship_builder: ShipBuilder = %ShipBuilder


func _on_shipyard_pressed() -> void:
	ship_builder.show_builder()


func _on_test_flight_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/hud_test.tscn")
