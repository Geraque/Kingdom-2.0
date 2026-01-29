extends Node2D
class_name Harvestable

# "wood" или "rock"
@export var resource_key: String = "wood"

# Сцена выпадающего ресурса (PickUp)
@export var drop_scene: PackedScene

# Смещение дропа относительно позиции объекта
@export var drop_offset: Vector2 = Vector2(0, -10)

# Доп. смещение размещения над землёй при спавне (если нужно)
@export var ground_offset_y: float = 8.0

var _hp: int = 1

@onready var hurt_box: Area2D = $HurtBox
@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	# HP рассчитывается из уровня добычи (в магазине: вкладка "Фарм")
	_hp = Global.gather_hits_required(resource_key)

	if hurt_box != null:
		hurt_box.area_entered.connect(Callable(self, "_on_hurt_box_area_entered"))

func _on_hurt_box_area_entered(_area: Area2D) -> void:
	audio_stream_player.play()
	if _hp <= 0:
		return

	# 1 удар = 1 взаимодействие
	_hp -= 1

	# сюда удобно подключить анимацию/частицы удара

	if _hp <= 0:
		_drop_once()
		queue_free()

func _drop_once() -> void:
	if drop_scene == null:
		# fallback: прямое начисление, если сцена дропа не задана
		Global.resource_add(resource_key, 1)
		return

	var drop = drop_scene.instantiate()
	if drop is Node2D:
		(drop as Node2D).position = global_position + drop_offset
	get_tree().current_scene.call_deferred("add_child", drop)
