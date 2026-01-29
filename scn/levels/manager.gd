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
	
func save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return

	var data: Dictionary = {
		"gold": Global.gold,
		"rock": Global.rock,
		"wood": Global.wood,
		"food": Global.food,
		"shop_upgrades": Global.shop_upgrades, # если требуется сохранять апгрейды
		"player_pos": player.global_position
	}

	file.store_var(data)


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return

	var first: Variant = file.get_var(false)

	if typeof(first) == TYPE_DICTIONARY:
		var data: Dictionary = first

		Global.gold = int(data.get("gold", Global.gold))
		Global.rock = int(data.get("rock", Global.rock))
		Global.wood = int(data.get("wood", Global.wood))
		Global.food = int(data.get("food", Global.food))

		var upgrades: Variant = data.get("shop_upgrades", null)
		if typeof(upgrades) == TYPE_DICTIONARY:
			Global.shop_upgrades = upgrades

		var pos: Variant = data.get("player_pos", null)
		if typeof(pos) == TYPE_VECTOR2:
			player.global_position = pos

		return

	# Старый формат (если раньше сохранялось по одному значению)
	Global.gold = int(first)
	player.position.x = float(file.get_var(false))
	player.position.y = float(file.get_var(false))


func _on_save_pressed() -> void:
	save_game()
	game_paused = !game_paused
	_apply_pause_state()


func _on_load_pressed() -> void:
	load_game()
	game_paused = !game_paused
	_apply_pause_state()
