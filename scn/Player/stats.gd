extends CanvasLayer

signal no_stamina()

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var stamina_bar: TextureProgressBar = $Stamina
@onready var health_text: Label = $"../HealthText"
@onready var health_anim: AnimationPlayer = $"../HealthAnim"


var stamina_cost
var attack_cost = 10
var block_cost = 0.5
var slide_cost = 20
var run_cost = 0.3

# Базовые значения (без магазина)
const BASE_MAX_HEALTH := 120.0
const BASE_MAX_STAMINA := 100.0
const BASE_STAMINA_REGEN := 10.0
const BASE_REGEN_AMOUNT := 1.0

var max_health: float = BASE_MAX_HEALTH
var max_stamina: float = BASE_MAX_STAMINA
var stamina_regen: float = BASE_STAMINA_REGEN
var regen_amount: float = BASE_REGEN_AMOUNT

var old_health: float = BASE_MAX_HEALTH

var _stamina: float = 80.0
var stamina: float:
	get:
		return _stamina
	set(value):
		_stamina = clamp(value, 0.0, max_stamina)
		if _stamina < 1.0:
			emit_signal("no_stamina")

var _health: float = BASE_MAX_HEALTH
var health: float:
	get:
		return _health
	set(value):
		_health = clamp(value, 0.0, max_health)
		health_bar.max_value = max_health
		health_bar.value = _health
		var difference = _health - old_health
		health_text.text = str(difference)
		old_health = _health
		if difference < 0:
			health_anim.play("damage_received")
		elif difference > 0:
			health_anim.play("health_received")

func _ready() -> void:
	health_text.modulate.a = 0
	if Global.has_signal("upgrade_changed"):
		Global.upgrade_changed.connect(Callable(self, "_on_upgrade_changed"))
	_apply_shop_upgrades(true)
	old_health = max_health
	health = max_health

func _process(delta):
	stamina_bar.value = stamina
	if stamina < max_stamina:
		stamina += stamina_regen * delta
	
func stamina_consumprion():
	stamina -= stamina_cost


func _on_health_regen_timeout() -> void:
	health += regen_amount

func _on_upgrade_changed(category: String, _key: String) -> void:
	# Применяются только апгрейды персонажа
	if category != "char":
		return
	_apply_shop_upgrades(false)

func _apply_shop_upgrades(reset_health: bool) -> void:
	var was_full_health := is_equal_approx(health, max_health)
	var was_full_stamina := is_equal_approx(stamina, max_stamina)

	max_health = BASE_MAX_HEALTH + float(Global.char_hp_bonus())
	max_stamina = BASE_MAX_STAMINA + float(Global.char_stamina_bonus())
	stamina_regen = BASE_STAMINA_REGEN + float(Global.char_stamina_regen_bonus())
	regen_amount = BASE_REGEN_AMOUNT + float(Global.char_regen_bonus())

	# Обновление прогрессбаров
	health_bar.max_value = max_health
	stamina_bar.max_value = max_stamina

	if reset_health:
		health = max_health
		stamina = min(stamina, max_stamina)
		return

	# Если здоровье/стамина были полными — оставлять полными после апгрейда
	if was_full_health:
		health = max_health
	else:
		health = min(health, max_health)

	if was_full_stamina:
		stamina = max_stamina
	else:
		stamina = min(stamina, max_stamina)


#func _input(_event):
	#if Input.is_action_pressed("attack") and stamina > 10:
		#stamina -= attack_cost 
