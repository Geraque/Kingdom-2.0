extends Node2D

@onready var light: DirectionalLight2D = $Light/DirectionalLight2D
@onready var day_text: Label = $CanvasLayer/DayText
@onready var animationPlayer: AnimationPlayer = $CanvasLayer/AnimationPlayer
@onready var player: CharacterBody2D = $Player/Player

# Победа после разрушения двух спавнеров.
# По умолчанию ожидается файл:
#   res://assets/sound/SFX/TEST.mp3
# Если путь другой — заменить в инспекторе или в коде.
@export var victory_sound_path: String = "res://assets/sound/SFX/victory.mp3"

# Пути до двух спавнеров в сцене уровня (поправить, если в проекте отличаются).
const SPAWNER_PATHS := [
	NodePath("Mobs/Spawner"),
	NodePath("Mobs/Spawner2"),
]

var _spawners_left_to_break: int = 2
var _victory_shown: bool = false



enum {
	MORNING,
	DAY,
	EVENING,
	NIGHT
}

var state = MORNING
var day_count: int

func _ready():
	randomize()
	light.enabled = true
	day_count = 1
	set_day_text()
	day_text_fade()
	_setup_victory_tracking()

func morning_state():
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", 0.2, 30)

func evening_state():
	var tween = get_tree().create_tween()
	tween.tween_property(light, "energy", 0.95, 30)

func _on_day_night_timeout() -> void:
	if state < 3:
		state += 1
	else:
		state = MORNING
		day_count += 1
		set_day_text()
		day_text_fade()

	match state:
		MORNING:
			morning_state()
		EVENING:
			evening_state()
		NIGHT:
			_emit_night_wave()

	Signals.emit_signal("day_time", state, day_count)

func _emit_night_wave() -> void:
	# первые 5 дней — только один спавнер (случайно слева или справа)
	# затем — оба спавнера
	var active_mask: int = 3
	if day_count <= 5:
		var chosen_side: int = randi_range(0, 1) # 0 = left, 1 = right
		active_mask = 1 << chosen_side
	Signals.emit_signal("night_wave", day_count, active_mask)

func day_text_fade():
	animationPlayer.play("day_text_fade_in")
	await get_tree().create_timer(3).timeout
	animationPlayer.play("day_text_fade_out")

func set_day_text():
	day_text.text = "DAY " + str(day_count)


# ---------------------------
# Победа
# ---------------------------

func _setup_victory_tracking() -> void:
	var destroyed := 0
	
	for p in SPAWNER_PATHS:
		var sp: Node = get_node_or_null(p)
		if sp == null:
			destroyed += 1
			continue
		
		# Если спавнер будет уничтожен (queue_free), этот сигнал сработает.
		sp.connect("tree_exited", Callable(self, "_on_spawner_gone"), CONNECT_ONE_SHOT)
	
	_spawners_left_to_break = maxi(0, 2 - destroyed)
	
	if _spawners_left_to_break == 0:
		call_deferred("_show_victory")

func _on_spawner_gone() -> void:
	if _victory_shown:
		return
	
	_spawners_left_to_break = maxi(0, _spawners_left_to_break - 1)
	if _spawners_left_to_break == 0:
		call_deferred("_show_victory")

func _show_victory() -> void:
	if _victory_shown:
		return
	_victory_shown = true
	
	# Останавливается геймплей, UI показывается поверх.
	get_tree().paused = true
	
	# UI создаётся кодом, чтобы не требовать правки .tscn.
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	
	var panel := Panel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_top = -90
	panel.offset_right = 220
	panel.offset_bottom = 90
	root.add_child(panel)
	
	var label := Label.new()
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.text = "Ты прошёл! Респект"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	panel.add_child(label)
	
	# Звук победы (если файл существует).
	var sfx := AudioStreamPlayer.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(sfx)
	var stream := load(victory_sound_path)
	if stream is AudioStream:
		sfx.stream = stream
		sfx.play()
