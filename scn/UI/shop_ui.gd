extends CanvasLayer

@onready var root: Control = $Root
@onready var gold_label: Label = $Root/Panel/VBox/Header/Gold
@onready var close_btn: Button = $Root/Panel/VBox/Header/Close
@onready var tabs: TabContainer = $Root/Panel/VBox/Tabs

# Пути к иконкам (при необходимости заменить под фактические пути в проекте)
const ICONS := {
	"gold": "res://assets/shop/Gold.png",

	# Персонаж
	"char_damage": "res://assets/shop/Attack_Icon.png",
	"char_stamina": "res://assets/shop/Move_speed_Icon.png",
	"char_stamina_regen": "res://assets/shop/Move_speed_regen_Icon.png",
	"char_cd": "res://assets/shop/Health_Icon.png",
	"char_regen": "res://assets/shop/Regen_Icon.png",

	# Фарм
	"farm_rock": "res://assets/shop/Rock_Icon.png",
	"farm_wood": "res://assets/shop/Wood_Icon.png",
	"farm_mobs": "res://assets/shop/Attack_Icon.png",

	# Продажа
	"sell_rock": "res://assets/shop/Rock_Icon.png",
	"sell_wood": "res://assets/shop/Wood_Icon.png",
	"sell_food": "res://assets/shop/Food_Icon.png",
}

var tex := {} # кэш Texture2D

var rows_buy := {}   # rows_buy[category][key] = {level, next, cost, btn}
var rows_sell := {}  # rows_sell[key] = {qty, price, btn1, btnall}

func _display_resource_name(key: String) -> String:
	if key == "rock":
		return "Камень"
	if key == "wood":
		return "Дерево"
	return key


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	close_btn.pressed.connect(Callable(self, "close"))

	# Названия вкладок (если нужно)
	if tabs.get_tab_count() >= 3:
		tabs.set_tab_title(0, "Персонаж")
		tabs.set_tab_title(1, "Фарм")
		tabs.set_tab_title(2, "Продажа")

	_build_buy_tab("char", 0, ["damage", "stamina", "stamina_regen", "hp", "regen"])
	_build_buy_tab("farm", 1, ["rock", "wood", "mobs"])
	_build_sell_tab(2, ["rock", "wood", "food"])

	visible = false

func open() -> void:
	visible = true
	_request_pause(true)
	refresh()
	# чтобы клавиатура сразу работала в UI
	close_btn.grab_focus()

func close() -> void:
	visible = false
	# освобождение паузы откладывается, чтобы ESC не успел открыть PauseMenu
	call_deferred("_request_pause", false)

func _request_pause(enable: bool) -> void:
	var mgr := get_tree().get_first_node_in_group("pause_manager")
	if mgr != null and mgr.has_method("request_pause") and mgr.has_method("release_pause"):
		if enable:
			mgr.call("request_pause", "shop")
		else:
			mgr.call("release_pause", "shop")
		return
	# fallback, если менеджера нет
	get_tree().paused = enable

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	gold_label.text = "Gold: " + str(Global.gold)

	# Покупки
	for category in rows_buy.keys():
		for key in rows_buy[category].keys():
			var n = rows_buy[category][key]
			var u: Dictionary = Global.shop_upgrades[category][key]

			var level := int(u["level"])
			var is_max := Global.upgrade_is_max(category, key)
			var cost := Global.upgrade_cost(category, key)

			var display_level := level
			if category == "farm" and (key == "wood" or key == "rock"):
				display_level = level + 1
			n["level"].text = "Lvl: " + str(display_level) + (" (MAX)" if is_max else "")
			if category == "farm" and (key == "wood" or key == "rock"):
				var cur_lvl := level + 1
				var next_lvl = min(cur_lvl + 1, Global.MAX_GATHER_LEVEL)
				n["next"].text = "Hits: " + str(Global.gather_hits_required(key, cur_lvl)) + " -> " + str(Global.gather_hits_required(key, next_lvl))
			else:
				n["next"].text = "Next: " + str(Global.upgrade_value_next(category, key))
			n["cost"].text = "Cost: " + ("-" if is_max else str(cost))

			var enough_gold := Global.gold >= cost
			n["btn"].disabled = is_max or (not enough_gold)

	# Продажа
	for key in rows_sell.keys():
		var n2 = rows_sell[key]
		n2["qty"].text = "Qty: " + str(Global.resource_amount(key))
		n2["price"].text = "Price: " + str(Global.sell_prices[key])

		var has_any := Global.resource_amount(key) > 0
		n2["btn1"].disabled = not has_any
		n2["btnall"].disabled = not has_any

func _ensure_list(tab_index: int) -> VBoxContainer:
	var tab_control: Control = tabs.get_tab_control(tab_index)

	if tab_control.has_node("Scroll/List"):
		return tab_control.get_node("Scroll/List") as VBoxContainer

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"

	# ВАЖНО: растяжение на всю вкладку
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 0.0
	scroll.offset_top = 0.0
	scroll.offset_right = 0.0
	scroll.offset_bottom = 0.0
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)

	scroll.add_child(list)
	tab_control.add_child(scroll)

	return list

func _get_tex(key: String) -> Texture2D:
	if tex.has(key):
		return tex[key]
	if not ICONS.has(key):
		return null
	var t: Texture2D = load(ICONS[key])
	tex[key] = t
	return t

func _make_icon(key: String, size := 24) -> TextureRect:
	var textTect := TextureRect.new()
	textTect.texture = _get_tex(key)
	textTect.custom_minimum_size = Vector2(size, size)
	textTect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	textTect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return textTect

func _make_gold_cost(cost_label: Label) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_child(_make_icon("gold", 18))
	box.add_child(cost_label)
	box.add_theme_constant_override("separation", 6)
	return box

func _build_buy_tab(category: String, tab_index: int, ordered_keys: Array) -> void:
	rows_buy[category] = {}

	var list := _ensure_list(tab_index)

	for key in ordered_keys:
		if not Global.shop_upgrades[category].has(key):
			continue

		var u: Dictionary = Global.shop_upgrades[category][key]
		var title: String = str(u["title"])

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		# Иконка
		var icon_key := ""
		if category == "char":
			if key == "damage": icon_key = "char_damage"
			elif key == "stamina": icon_key = "char_stamina"
			elif key == "stamina_regen": icon_key = "char_stamina_regen"
			elif key == "hp": icon_key = "char_cd" # иконка остаётся прежней
			elif key == "regen": icon_key = "char_regen"
		elif category == "farm":
			if key == "rock": icon_key = "farm_rock"
			elif key == "wood": icon_key = "farm_wood"
			elif key == "mobs": icon_key = "farm_mobs"

		if icon_key != "":
			row.add_child(_make_icon(icon_key, 26))

		# Название
		var name_l := Label.new()
		name_l.text = title
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Уровень / Next / Cost
		var level_l := Label.new()
		level_l.text = "Lvl: 0"

		var next_l := Label.new()
		next_l.text = "Next: " + str(Global.upgrade_value_next(category, key))

		var cost_l := Label.new()
		cost_l.text = str(Global.upgrade_cost(category, key))

		var cost_box := _make_gold_cost(cost_l)

		# Кнопка
		var btn := Button.new()
		btn.text = "Buy"
		btn.pressed.connect(Callable(self, "_on_buy_pressed").bind(category, key))

		row.add_child(name_l)
		row.add_child(level_l)
		row.add_child(next_l)
		row.add_child(cost_box)
		row.add_child(btn)

		list.add_child(row)

		rows_buy[category][key] = {
			"level": level_l,
			"next": next_l,
			"cost": cost_l,
			"btn": btn
		}
func _on_buy_pressed(category: String, key: String) -> void:
	if Global.buy_upgrade(category, key):
		refresh()

func _build_sell_tab(tab_index: int, ordered_keys: Array) -> void:
	var list := _ensure_list(tab_index)

	for key in ordered_keys:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		# Иконка
		var icon_key := ""
		if key == "rock": icon_key = "sell_rock"
		elif key == "wood": icon_key = "sell_wood"
		elif key == "food": icon_key = "sell_food"
		if icon_key != "":
			row.add_child(_make_icon(icon_key, 26))

		# Название
		var name_l := Label.new()
		name_l.text = _display_resource_name(key)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var qty_l := Label.new()
		qty_l.text = "Qty: 0"

		var price_l := Label.new()
		price_l.text = str(Global.sell_prices[key])

		var price_box := _make_gold_cost(price_l)

		var sell1 := Button.new()
		sell1.text = "Sell 1"
		sell1.pressed.connect(Callable(self, "_on_sell_pressed").bind(key, 1))

		var sellall := Button.new()
		sellall.text = "Sell all"
		sellall.pressed.connect(Callable(self, "_on_sell_all_pressed").bind(key))

		row.add_child(name_l)
		row.add_child(qty_l)
		row.add_child(price_box)
		row.add_child(sell1)
		row.add_child(sellall)

		list.add_child(row)

		rows_sell[key] = {
			"qty": qty_l,
			"price": price_l,
			"btn1": sell1,
			"btnall": sellall
		}

func _on_sell_pressed(key: String, amount: int) -> void:
	if Global.sell_resource(key, amount):
		refresh()

func _on_sell_all_pressed(key: String) -> void:
	var amount := Global.resource_amount(key)
	if amount <= 0:
		return
	if Global.sell_resource(key, amount):
		refresh()
