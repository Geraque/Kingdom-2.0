extends StaticBody2D

@export var shop_ui_scene: PackedScene

@onready var interact_area: Area2D = $InteractArea
@onready var mob_health := $MobHealth
@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var player_in_range := false
var ui: CanvasLayer

func _ready() -> void:
	# Детект персонажа рядом
	if interact_area != null:
		interact_area.body_entered.connect(Callable(self, "_on_interact_body_entered"))
		interact_area.body_exited.connect(Callable(self, "_on_interact_body_exited"))
		# Важно: персонаж на layer=2, значит mask должен видеть 2
		interact_area.collision_mask = 2

	# HP магазина
	if mob_health != null:
		mob_health.connect("no_health", Callable(self, "_on_no_health"))

	# UI магазина (один инстанс)
	if shop_ui_scene != null:
		ui = shop_ui_scene.instantiate()
		ui.visible = false
		get_tree().current_scene.call_deferred("add_child", ui)

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if event.is_action_pressed("interact"):
		if ui != null:
			ui.call("open")
		get_viewport().set_input_as_handled()

func _on_interact_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true

func _on_interact_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false

func take_damage(amount: int) -> void:
	if mob_health != null and mob_health.has_method("apply_damage"):
		audio_stream_player.play()
		mob_health.call("apply_damage", amount)

func _on_no_health() -> void:
	var mgr := get_tree().get_first_node_in_group("pause_manager")
	if mgr != null and mgr.has_method("reset_run"):
		mgr.call("reset_run", true)
	elif Global.has_method("reset_shop_upgrades"):
		Global.call("reset_shop_upgrades")
	get_tree().change_scene_to_file.bind("res://scn/menu/menu.tscn").call_deferred()
