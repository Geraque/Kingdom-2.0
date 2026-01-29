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

var _hits_done: int = 0
var _broken: bool = false

@onready var hurt_box: Area2D = $HurtBox
@onready var audio_stream_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

func _ready() -> void:
	if Global.has_signal("upgrade_changed"):
		Global.upgrade_changed.connect(Callable(self, "_on_upgrade_changed"))

	if hurt_box != null:
		hurt_box.area_entered.connect(Callable(self, "_on_hurt_box_area_entered"))

func _required_hits() -> int:
	return Global.gather_hits_required(resource_key)

func _play_hit_sfx() -> void:
	# Решение: one-shot AudioStreamPlayer2D добавляется в текущую сцену,
	# поэтому звук доигрывает даже если ресурс удаляется в этот же кадр.
	if audio_stream_player == null:
		return
	if audio_stream_player.stream == null:
		return

	var one_shot := audio_stream_player.duplicate() as AudioStreamPlayer2D
	if one_shot == null:
		return

	one_shot.global_position = audio_stream_player.global_position
	get_tree().current_scene.add_child(one_shot)
	one_shot.finished.connect(Callable(one_shot, "queue_free"), CONNECT_ONE_SHOT)
	one_shot.play()

func _on_hurt_box_area_entered(_area: Area2D) -> void:
	if _broken:
		return

	_play_hit_sfx()

	_hits_done += 1

	if _hits_done >= _required_hits():
		_break()

func _on_upgrade_changed(category: String, key: String) -> void:
	if _broken:
		return
	if category != "farm":
		return
	if key != resource_key:
		return

	if _hits_done >= _required_hits():
		_break()

func _break() -> void:
	if _broken:
		return
	_broken = true
	_drop_once()
	queue_free()

func _drop_once() -> void:
	if drop_scene == null:
		Global.resource_add(resource_key, 1)
		return

	var drop = drop_scene.instantiate()
	if drop is Node2D:
		(drop as Node2D).position = global_position + drop_offset
	get_tree().current_scene.call_deferred("add_child", drop)
