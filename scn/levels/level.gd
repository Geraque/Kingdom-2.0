extends Node2D

@onready var light: DirectionalLight2D = $Light/DirectionalLight2D
@onready var day_text: Label = $CanvasLayer/DayText
@onready var animationPlayer: AnimationPlayer = $CanvasLayer/AnimationPlayer
@onready var player: CharacterBody2D = $Player/Player


enum {
	MORNING,
	DAY,
	EVENING,
	NIGHT
}

var state = MORNING
var day_count: int
func _ready():
	light.enabled = true
	day_count = 1
	set_day_text()
	day_text_fade()
			
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
			
	
	Signals.emit_signal("day_time", state, day_count)

func day_text_fade():
	animationPlayer.play("day_text_fade_in")
	await get_tree().create_timer(3).timeout
	animationPlayer.play("day_text_fade_out")

func set_day_text ():
	day_text.text = "DAY "+ str(day_count)
