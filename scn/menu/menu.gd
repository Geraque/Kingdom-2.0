extends Node2D

@onready var buttons: AudioStreamPlayer = $buttons


func _on_quit_pressed() -> void:
	buttons.play()
	await buttons.finished
	get_tree().quit()


func _on_play_pressed() -> void:
	buttons.play()
	#await buttons.finished
	get_tree().change_scene_to_file("res://scn/levels/level.tscn")
