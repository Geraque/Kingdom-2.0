extends StaticBody2D


@onready var interact_area: Area2D = $InteractArea
@onready var label: Label = $InteractArea/Text
@onready var video_stream_player: VideoStreamPlayer = $Video/VideoStreamPlayer

@export_multiline var text = "AS"
@export var video = false

var player_in_range := false

func _ready() -> void:
	label.modulate.a = 0
	label.text = text
	# Детект персонажа рядом
	if interact_area != null:
		interact_area.body_entered.connect(Callable(self, "_on_interact_body_entered"))
		interact_area.body_exited.connect(Callable(self, "_on_interact_body_exited"))
		# Важно: персонаж на layer=2, значит mask должен видеть 2
		interact_area.collision_mask = 2

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if event.is_action_pressed("interact"):
		if video:
			video_stream_player.modulate.a = 255
			video_stream_player.play()
			await video_stream_player.finished
			var tween = get_tree().create_tween()
			tween.tween_property(video_stream_player, "modulate:a", 0, 0.5)
		else: 
			label.modulate.a = 255
			await get_tree().create_timer(6).timeout
			var tween = get_tree().create_tween()
			tween.tween_property(label, "modulate:a", 0, 0.5)

func _on_interact_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true

func _on_interact_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false
