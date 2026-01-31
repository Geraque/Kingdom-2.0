extends Node

signal upgrade_changed(category: String, key: String)

var player_pos
var player_damage
var damage_basic := 10
var gold := 9999

# Казик
var casino_worm_obtained := false

# Ресурсы
var rock := 0
var wood := 0

# Апгрейды магазина (лимит 7; для бесконечности поставить max = -1)
var shop_upgrades := {
	"char": {
		"damage":  {"title": "+Урон",       "level": 0, "max": 7, "base_cost": 25, "cost_mult": 1.45, "base_buff": 2,  "buff_step": 2},
		"stamina": {"title": "+Стамина",    "level": 0, "max": 7, "base_cost": 20, "cost_mult": 1.40, "base_buff": 5,  "buff_step": 5},
		"stamina_regen": {"title": "+Стамина реген",    "level": 0, "max": 7, "base_cost": 20, "cost_mult": 1.40, "base_buff": 5,  "buff_step": 5},
		"hp":      {"title": "+HP",         "level": 0, "max": 7, "base_cost": 30, "cost_mult": 1.50, "base_buff": 10, "buff_step": 10},
		"regen":   {"title": "+HP реген",   "level": 0, "max": 7, "base_cost": 18, "cost_mult": 1.35, "base_buff": 1,  "buff_step": 1},
	},
	"farm": {
		"rock":    {"title": "+Добыча камня",    "level": 0, "max": 4, "base_cost": 15, "cost_mult": 1.35, "base_buff": 5,  "buff_step": 5},
		"wood":    {"title": "+Добыча дерева",   "level": 0, "max": 4, "base_cost": 15, "cost_mult": 1.35, "base_buff": 5,  "buff_step": 5},
	},
}

var sell_prices := {
	"rock": 2,
	"wood": 1,
}

func upgrade_cost(category: String, key: String) -> int:
	var u: Dictionary = shop_upgrades[category][key]
	return int(round(u["base_cost"] * pow(u["cost_mult"], u["level"])))

func upgrade_level(category: String, key: String) -> int:
	return int(shop_upgrades[category][key]["level"])

# Текущее значение бонуса (для применения в игре).
# Уровень 0 -> бонус 0.
func upgrade_value_current(category: String, key: String) -> float:
	var u: Dictionary = shop_upgrades[category][key]
	var lvl := int(u["level"])
	if lvl <= 0:
		return 0.0
	return float(u["base_buff"]) + float(u["buff_step"]) * float(lvl - 1)

func upgrade_value_next(category: String, key: String) -> float:
	var u: Dictionary = shop_upgrades[category][key]
	# Значение бонуса на следующем уровне (lvl + 1)
	return float(u["base_buff"]) + float(u["buff_step"]) * float(int(u["level"]))

func upgrade_is_max(category: String, key: String) -> bool:
	var u: Dictionary = shop_upgrades[category][key]
	var m: int = int(u["max"])
	return m >= 0 and int(u["level"]) >= m

func buy_upgrade(category: String, key: String) -> bool:
	if upgrade_is_max(category, key):
		return false
	var cost := upgrade_cost(category, key)
	if gold < cost:
		return false
	gold -= cost
	shop_upgrades[category][key]["level"] = int(shop_upgrades[category][key]["level"]) + 1
	emit_signal("upgrade_changed", category, key)
	return true

# Выдать апгрейд без оплаты (для казика).
func grant_upgrade(category: String, key: String) -> bool:
	if upgrade_is_max(category, key):
		return false
	shop_upgrades[category][key]["level"] = int(shop_upgrades[category][key]["level"]) + 1
	emit_signal("upgrade_changed", category, key)
	return true

# Удобные геттеры для персонажа
func char_damage_bonus() -> float:
	return upgrade_value_current("char", "damage")

func char_stamina_bonus() -> float:
	return upgrade_value_current("char", "stamina")
	
func char_stamina_regen_bonus() -> float:
	return upgrade_value_current("char", "stamina_regen")

func char_hp_bonus() -> float:
	return upgrade_value_current("char", "hp")

func char_regen_bonus() -> float:
	return upgrade_value_current("char", "regen")

func resource_amount(key: String) -> int:
	match key:
		"rock": return rock
		"wood": return wood
		_: return 0

func resource_take(key: String, amount: int) -> bool:
	if amount <= 0:
		return false
	match key:
		"rock":
			if rock < amount: return false
			rock -= amount
		"wood":
			if wood < amount: return false
			wood -= amount
		_:
			return false
	return true

func sell_resource(key: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if not sell_prices.has(key):
		return false
	if not resource_take(key, amount):
		return false
	gold += int(sell_prices[key]) * amount
	return true


# Добавление ресурса (для дропа)
func resource_add(key: String, amount: int) -> void:
	if amount <= 0:
		return
	match key:
		"rock":
			rock += amount
		"wood":
			wood += amount

# Уровни добычи (1..5) берутся из вкладки "Фарм" магазина.
# В shop_upgrades хранится внутренний уровень 0..4, поэтому +1.
const MAX_GATHER_LEVEL := 5

func gather_level(key: String) -> int:
	match key:
		"wood":
			if shop_upgrades.has("farm") and shop_upgrades["farm"].has("wood"):
				return clamp(int(shop_upgrades["farm"]["wood"]["level"]) + 1, 1, MAX_GATHER_LEVEL)
			return 1
		"rock":
			if shop_upgrades.has("farm") and shop_upgrades["farm"].has("rock"):
				return clamp(int(shop_upgrades["farm"]["rock"]["level"]) + 1, 1, MAX_GATHER_LEVEL)
			return 1
		_:
			return 1

# Сколько ударов нужно для добычи при уровне 1..5 (1 удар = 1 взаимодействие)
# Дерево: 5..1, Камень: 6..2 (на 1 удар больше дерева, минимум 2)
func gather_hits_required(key: String, mining_level: int = -1) -> int:
	var lvl := mining_level
	if lvl < 0:
		lvl = gather_level(key)

	if key == "wood":
		return clamp(6 - lvl, 1, 5)
	if key == "rock":
		return clamp(7 - lvl, 2, 6)
	return 1
