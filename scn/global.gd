extends Node

signal upgrade_changed(category: String, key: String)

var player_pos
var player_damage
var damage_basic := 10
var gold := 150

# Ресурсы
var rock := 200
var wood := 300
var food := 15

# Апгрейды магазина (лимит 7; для бесконечности поставить max = -1)
var shop_upgrades := {
	"char": {
		"damage":  {"title": "+Урон",       "level": 0, "max": 7, "base_cost": 25, "cost_mult": 1.45, "base_buff": 2,  "buff_step": 2},
		"stamina": {"title": "+Стамина",    "level": 0, "max": 7, "base_cost": 20, "cost_mult": 1.40, "base_buff": 5,  "buff_step": 5},
		"hp":      {"title": "+HP",         "level": 0, "max": 7, "base_cost": 30, "cost_mult": 1.50, "base_buff": 10, "buff_step": 10},
		"regen":   {"title": "+HP реген",   "level": 0, "max": 7, "base_cost": 18, "cost_mult": 1.35, "base_buff": 1,  "buff_step": 1},
	},
	"farm": {
		"rock":    {"title": "+Добыча камня",    "level": 0, "max": 7, "base_cost": 15, "cost_mult": 1.35, "base_buff": 5,  "buff_step": 5},
		"wood":    {"title": "+Добыча дерева",   "level": 0, "max": 7, "base_cost": 15, "cost_mult": 1.35, "base_buff": 5,  "buff_step": 5},
		"mobs":    {"title": "+Добыча монстров", "level": 0, "max": 7, "base_cost": 25, "cost_mult": 1.40, "base_buff": 5,  "buff_step": 5},
	},
}

var sell_prices := {
	"rock": 1,
	"wood": 1,
	"food": 2,
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

# Удобные геттеры для персонажа
func char_damage_bonus() -> float:
	return upgrade_value_current("char", "damage")

func char_stamina_bonus() -> float:
	return upgrade_value_current("char", "stamina")

func char_hp_bonus() -> float:
	return upgrade_value_current("char", "hp")

func char_regen_bonus() -> float:
	return upgrade_value_current("char", "regen")

func resource_amount(key: String) -> int:
	match key:
		"rock": return rock
		"wood": return wood
		"food": return food
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
		"food":
			if food < amount: return false
			food -= amount
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
