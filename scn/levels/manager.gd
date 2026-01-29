extends Node

@onready var pause_menu: Control = $"../CanvasLayer/PauseMenu"
@onready var player: CharacterBody2D = $"../Player/Player"

var game_paused: bool = false
var _pause_reasons: Dictionary = {} # reason -> true
var save_path = "user://savegame.save"

func _ready() -> void:
	# чтобы менеджер продолжал работать при паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_manager")
	_apply_pause_state()

func _unhandled_input(event: InputEvent) -> void:
	# ESC (ui_cancel) открывает/закрывает меню паузы,
	# но не должен срабатывать, пока открыт магазин.
	if event.is_action_pressed("ui_cancel"):
		if _pause_reasons.has("shop"):
			return
		game_paused = !game_paused
		_apply_pause_state()
		get_viewport().set_input_as_handled()

func request_pause(reason: String = "external") -> void:
	_pause_reasons[reason] = true
	_apply_pause_state()

func release_pause(reason: String = "external") -> void:
	_pause_reasons.erase(reason)
	_apply_pause_state()

func _apply_pause_state() -> void:
	var should_pause := game_paused or (not _pause_reasons.is_empty())
	get_tree().paused = should_pause
	if game_paused:
		pause_menu.show()
	else:
		pause_menu.hide()

# поддержка старых вызовов: кнопки в меню меняют game_paused
# и затем применяется итоговое состояние


func _on_resume_pressed() -> void:
	game_paused = !game_paused
	_apply_pause_state()


func _on_quit_pressed() -> void:
	game_paused = false
	_pause_reasons.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scn/menu/menu.tscn")


func _on_menu_button_pressed() -> void:
	game_paused = !game_paused
	_apply_pause_state()
	
func save_game():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(Global.gold)
	file.store_var(player.position.x)
	file.store_var(player.position.y)
	
func load_game():
	var file = FileAccess.open(save_path, FileAccess.READ)
	Global.gold = file.get_var(Global.gold)
	player.position.x = file.get_var(player.position.x)
	player.position.y = file.get_var(player.position.y)


func _on_save_pressed() -> void:
	save_game()
	game_paused = !game_paused
	_apply_pause_state()


func _on_load_pressed() -> void:
	load_game()
	game_paused = !game_paused
	_apply_pause_state()
