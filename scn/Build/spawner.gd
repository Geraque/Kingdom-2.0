extends Node2D

signal spawn_cycle_done

@export_enum("left", "right") var spawn_side: int = 0

@export var max_health: int = 150
@export var aggro_duration: float = 10.0
@export var aggro_spawn_interval: float = 1.6
@export var spawn_y: float = 550.0

# Опционально: звук начала волны/агро для этого спавнера.
# Если не назначен — используется stream, заданный у AudioStreamPlayer2D в сцене.
@export var attack_sound: AudioStream

@onready var mobs: Node2D = $".."
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var mob_health: Node2D = $MobHealth
@onready var hurt_box: Area2D = $HurtBox
@onready var aggro_timer: Timer = $AggroTimer
@onready var aggro_spawn_timer: Timer = $AggroSpawnTimer

var _aggro_active: bool = false
var _spawn_locked: bool = false
var _dead: bool = false

var mushroom_preload = preload("res://scn/mobs/mushroom.tscn")
var skeleton_preload = preload("res://scn/mobs/skeleton.tscn")


func _ready() -> void:
	# Смена времени суток — для сброса в idle и т.п.
	Signals.connect("day_time", Callable(self, "_on_time_changed"))

	# Ночной спавн волн — централизованно, чтобы управлять количеством активных спавнеров
	if Signals.has_signal("night_wave"):
		Signals.connect("night_wave", Callable(self, "_on_night_wave"))

	# завершение анимации спавна
	if not animation_player.animation_finished.is_connected(Callable(self, "_on_animation_finished")):
		animation_player.animation_finished.connect(Callable(self, "_on_animation_finished"))

	# Таймеры
	if aggro_timer != null:
		aggro_timer.one_shot = true
		aggro_timer.wait_time = aggro_duration
		if not aggro_timer.timeout.is_connected(Callable(self, "_on_aggro_timer_timeout")):
			aggro_timer.timeout.connect(Callable(self, "_on_aggro_timer_timeout"))

	if aggro_spawn_timer != null:
		aggro_spawn_timer.one_shot = false
		aggro_spawn_timer.wait_time = aggro_spawn_interval
		if not aggro_spawn_timer.timeout.is_connected(Callable(self, "_on_aggro_spawn_timer_timeout")):
			aggro_spawn_timer.timeout.connect(Callable(self, "_on_aggro_spawn_timer_timeout"))

	# HP
	if mob_health != null:
		mob_health.max_health = max_health
		var bar := mob_health.get_node_or_null("HealthBar")
		if bar != null:
			bar.max_value = max_health
		mob_health.health = max_health

		if mob_health.has_signal("no_health"):
			if not mob_health.no_health.is_connected(Callable(self, "_on_mob_health_no_health")):
				mob_health.no_health.connect(Callable(self, "_on_mob_health_no_health"))

	# Вход удара игрока
	if hurt_box != null:
		if not hurt_box.area_entered.is_connected(Callable(self, "_on_hurt_box_area_entered")):
			hurt_box.area_entered.connect(Callable(self, "_on_hurt_box_area_entered"))


func _on_time_changed(state, _day_count) -> void:
	if _dead:
		return

	# В не-ночное время просто гарантируется idle (если не идёт спавн/агро)
	if state != 3:
		if not _spawn_locked and not _aggro_active:
			animation_player.play("idle")


func _on_night_wave(day_count: int, active_mask: int) -> void:
	if _dead:
		return

	var my_mask: int = 1 << spawn_side
	if (active_mask & my_mask) == 0:
		return

	await _spawn_night_wave(day_count)


func _spawn_night_wave(day_count: int) -> void:
	if _dead:
		return

	var rng: int = randi_range(0, 2)
	var count: int = day_count + rng

	_play_attack_sound()

	for i in range(count):
		# гарантированный последовательный спавн
		while not _spawn_anim_once():
			await get_tree().process_frame
			if _dead:
				return
		await spawn_cycle_done

	if not _dead:
		animation_player.play("idle")


func _on_hurt_box_area_entered(_area: Area2D) -> void:
	if _dead:
		return

	# запуск защитного спавна (не чаще, чем раз в aggro_duration секунд)
	_start_aggro_if_needed()

	# урон от удара
	if mob_health != null and mob_health.has_method("apply_damage"):
		mob_health.call("apply_damage", int(Global.player_damage))


func _start_aggro_if_needed() -> void:
	if _aggro_active:
		return

	_aggro_active = true

	# особый моб — только в режиме атаки спавнера (не в обычных волнах)
	spawn_dark()

	_play_attack_sound()

	if aggro_timer != null:
		aggro_timer.start(aggro_duration)

	# первый моб — сразу, затем по таймеру
	_spawn_anim_once()
	if aggro_spawn_timer != null:
		aggro_spawn_timer.start(aggro_spawn_interval)


func _on_aggro_spawn_timer_timeout() -> void:
	if _dead or not _aggro_active:
		return
	_spawn_anim_once()


func _on_aggro_timer_timeout() -> void:
	_aggro_active = false
	if aggro_spawn_timer != null:
		aggro_spawn_timer.stop()


func _spawn_anim_once() -> bool:
	if _dead:
		return false
	if _spawn_locked:
		return false

	_spawn_locked = true
	animation_player.play("spawn")
	return true


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"spawn":
		return

	_spawn_locked = false

	if not _dead:
		animation_player.play("idle")

	emit_signal("spawn_cycle_done")


func _play_attack_sound() -> void:
	if audio_stream_player == null:
		return

	#if attack_sound != null:
		#audio_stream_player.stream = attack_sound

	audio_stream_player.play()
	await audio_stream_player.finished
	var audio_stream_player2 = audio_stream_player
	audio_stream_player2.stream = attack_sound
	audio_stream_player2.play()
	


func enemy_spawn() -> void:
	if _dead:
		return

	var rng := randi_range(1, 2)
	if rng == 1:
		mushroom_spawn()
	else:
		skeleton_spawn()


func skeleton_spawn() -> void:
	var skeleton = skeleton_preload.instantiate()
	skeleton.position = Vector2(self.position.x, spawn_y)
	mobs.add_child(skeleton)


func mushroom_spawn() -> void:
	var mushroom = mushroom_preload.instantiate()
	mushroom.position = Vector2(self.position.x, spawn_y)
	mobs.add_child(mushroom)


# Заглушка под особого моба. В обычных волнах не вызывается.
# При добавлении логики рекомендуется делать спавн через call_deferred(),
# чтобы не ловить ошибки flushing queries в колбэках физики.
func spawn_dark() -> void:
	pass


func _on_mob_health_no_health() -> void:
	if _dead:
		return

	_dead = true
	_aggro_active = false

	if aggro_timer != null:
		aggro_timer.stop()
	if aggro_spawn_timer != null:
		aggro_spawn_timer.stop()

	animation_player.stop()

	# x10 золота относительно обычного моба
	Signals.emit_signal("spawner_destroyed", global_position, 10)

	queue_free()
