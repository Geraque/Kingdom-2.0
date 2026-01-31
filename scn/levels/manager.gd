extends Node

@onready var pause_menu: Control = $"../CanvasLayer/PauseMenu"
@onready var player: CharacterBody2D = $"../Player/Player"
@onready var level: Node2D = $".."

# Статы игрока (CanvasLayer со скриптом stats.gd)
@onready var player_stats: Node = player.get_node_or_null("stats")


var game_paused: bool = false
var _pause_reasons: Dictionary = {} # reason -> true
var save_path: String = "user://savegame.save"

const SHOP_PATH: String = "Buildings/Shop"
const SPAWNER_PATHS: Array[String] = [
	"Mobs/Spawner",
	"Mobs/Spawner2",
]

func _extract_upgrade_levels(src: Dictionary) -> Dictionary:
	# Возвращает компактный формат: category -> key -> level
	var out: Dictionary = {}
	for cat in src.keys():
		var cat_v: Variant = src[cat]
		if typeof(cat_v) != TYPE_DICTIONARY:
			continue
		var cat_d: Dictionary = cat_v
		var out_cat: Dictionary = {}
		for key in cat_d.keys():
			var kv: Variant = cat_d[key]
			if typeof(kv) == TYPE_DICTIONARY and kv.has("level"):
				out_cat[key] = int(kv["level"])
			elif typeof(kv) == TYPE_INT or typeof(kv) == TYPE_FLOAT:
				out_cat[key] = int(kv)
		if not out_cat.is_empty():
			out[cat] = out_cat
	return out

func _apply_saved_upgrade_levels(saved_any: Dictionary) -> void:
	# Поддержка двух форматов:
	# 1) сохранённый shop_upgrades (полная структура с dict'ами)
	# 2) сохранённый shop_levels (category->key->int)
	for cat in saved_any.keys():
		if not Global.shop_upgrades.has(cat):
			continue
		var cat_v: Variant = saved_any[cat]
		if typeof(cat_v) != TYPE_DICTIONARY:
			continue
		var cat_d: Dictionary = cat_v
		for key in cat_d.keys():
			if not Global.shop_upgrades[cat].has(key):
				continue
			var kv: Variant = cat_d[key]
			var lvl := -1
			if typeof(kv) == TYPE_DICTIONARY and kv.has("level"):
				lvl = int(kv["level"])
			elif typeof(kv) == TYPE_INT or typeof(kv) == TYPE_FLOAT:
				lvl = int(kv)
			if lvl >= 0:
				Global.shop_upgrades[cat][key]["level"] = lvl

func _get_mob_health(node: Node) -> Node:
	if node == null:
		return null
	var mh: Node = node.get_node_or_null("MobHealth")
	return mh

func _read_health(node: Node) -> int:
	var mh: Node = _get_mob_health(node)
	if mh == null:
		return -1
	var v: Variant = mh.get("health")
	if typeof(v) == TYPE_NIL:
		return -1
	return int(v)

func _write_health(node: Node, hp: int) -> void:
	if node == null:
		return
	var mh: Node = _get_mob_health(node)
	if mh == null:
		return
	# если в MobHealth нет свойства health — просто пропуск
	if typeof(mh.get("health")) == TYPE_NIL:
		return
	# на всякий случай отложенно, чтобы не попасть на flushing queries
	mh.set_deferred("health", hp)

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

	# HP магазина и спавнеров + текущий день
	var buildings: Dictionary = {}

	var shop_node: Node = level.get_node_or_null(NodePath(SHOP_PATH))
	var shop_state: Dictionary = {
		"alive": shop_node != null,
		"hp": _read_health(shop_node)
	}
	buildings["shop"] = shop_state

	var spawners_state: Dictionary = {}
	for p in SPAWNER_PATHS:
		var sp_node: Node = level.get_node_or_null(NodePath(p))
		var st: Dictionary = {
			"alive": sp_node != null,
			"hp": _read_health(sp_node)
		}
		spawners_state[p] = st
	buildings["spawners"] = spawners_state
	# Текущие значения здоровья/стамины игрока (не максимальные)
	var pstats: Dictionary = {}
	if player_stats != null:
		var hp_v: Variant = player_stats.get("health")
		var st_v: Variant = player_stats.get("stamina")
		if typeof(hp_v) != TYPE_NIL:
			pstats["health"] = float(hp_v)
		if typeof(st_v) != TYPE_NIL:
			pstats["stamina"] = float(st_v)

	var data: Dictionary = {
		"gold": Global.gold,
		"rock": Global.rock,
		"wood": Global.wood,
		"food": Global.food,
		# Сохраняются только уровни апгрейдов, чтобы сейвы не ломались при изменении цен/иконок/текстов
		"shop_levels": _extract_upgrade_levels(Global.shop_upgrades),
		"player_stats": pstats,
		"player_pos": player.global_position,
		"day_count": level.day_count,
		"buildings": buildings
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

		# ВАЖНО: уровни апгрейдов мержатся в текущую структуру,
		# чтобы новые ключи (например, stamina_regen) не терялись при загрузке старых сейвов.
		var upgrades_applied: bool = false
		var levels_v: Variant = data.get("shop_levels", null)
		if typeof(levels_v) == TYPE_DICTIONARY:
			_apply_saved_upgrade_levels(levels_v)
			upgrades_applied = true
		else:
			# Поддержка старых сейвов, где сохранялась полная структура shop_upgrades
			var upgrades_v: Variant = data.get("shop_upgrades", null)
			if typeof(upgrades_v) == TYPE_DICTIONARY:
				_apply_saved_upgrade_levels(upgrades_v)
				upgrades_applied = true

		# обновление кешированных значений (стамина реген, макс. хп/стамина и т.д.)
		# через сигнал (stats.gd уже подписан)
		if upgrades_applied and Global.has_signal("upgrade_changed"):
			Global.emit_signal("upgrade_changed", "char", "load")

		var pos: Variant = data.get("player_pos", null)
		if typeof(pos) == TYPE_VECTOR2:
			player.global_position = pos

		level.day_count = int(data.get("day_count", level.day_count))

		# Восстановление текущих HP/стамины (после применения апгрейдов, чтобы корректно работали clamp'ы)
		var pstats_v: Variant = data.get("player_stats", null)
		if typeof(pstats_v) == TYPE_DICTIONARY and player_stats != null:
			var ps: Dictionary = pstats_v
			var cur_hp_v: Variant = player_stats.get("health")
			var cur_st_v: Variant = player_stats.get("stamina")
			var hp: float = float(cur_hp_v) if typeof(cur_hp_v) != TYPE_NIL else 0.0
			var st: float = float(cur_st_v) if typeof(cur_st_v) != TYPE_NIL else 0.0
			var saved_hp_v: Variant = ps.get("health", null)
			var saved_st_v: Variant = ps.get("stamina", null)
			if typeof(saved_hp_v) != TYPE_NIL:
				hp = float(saved_hp_v)
			if typeof(saved_st_v) != TYPE_NIL:
				st = float(saved_st_v)
			# чтобы не проигрывать анимацию изменения хп при загрузке
			if typeof(player_stats.get("old_health")) != TYPE_NIL:
				player_stats.set("old_health", hp)
			player_stats.set("health", hp)
			player_stats.set("stamina", st)

		# Восстановление HP магазина и спавнеров.
		# Если спавнер был уничтожен (alive=false или hp<=0), он удаляется из сцены.
		var buildings_v: Variant = data.get("buildings", null)
		if typeof(buildings_v) == TYPE_DICTIONARY:
			var buildings: Dictionary = buildings_v

			# Магазин
			var shop_state_v: Variant = buildings.get("shop", null)
			if typeof(shop_state_v) == TYPE_DICTIONARY:
				var shop_state: Dictionary = shop_state_v
				var shop_node: Node = level.get_node_or_null(NodePath(SHOP_PATH))
				var shop_alive: bool = bool(shop_state.get("alive", true))
				var shop_hp: int = int(shop_state.get("hp", -1))
				if shop_node != null:
					if (not shop_alive) or (shop_hp >= 0 and shop_hp <= 0):
						shop_node.call_deferred("queue_free")
					elif shop_hp >= 0:
						_write_health(shop_node, shop_hp)

			# Спавнеры
			var spawners_state_v: Variant = buildings.get("spawners", null)
			if typeof(spawners_state_v) == TYPE_DICTIONARY:
				var spawners_state: Dictionary = spawners_state_v
				for p in SPAWNER_PATHS:
					var st_v: Variant = spawners_state.get(p, null)
					if typeof(st_v) != TYPE_DICTIONARY:
						continue
					var st: Dictionary = st_v
					var sp_node: Node = level.get_node_or_null(NodePath(p))
					var sp_alive: bool = bool(st.get("alive", true))
					var sp_hp: int = int(st.get("hp", -1))
					if sp_node != null:
						if (not sp_alive) or (sp_hp >= 0 and sp_hp <= 0):
							sp_node.call_deferred("queue_free")
						elif sp_hp >= 0:
							_write_health(sp_node, sp_hp)
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
