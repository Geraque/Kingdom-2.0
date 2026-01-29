extends Node2D

signal no_health()
signal damage_received()

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var damage_text: Label = $DamageText
@onready var animPlayer: AnimationPlayer = $AnimationPlayer

@export var max_health = 10

var health = 100:
	set(value):
		health = value
		health_bar.value = health
		if health <= 0:
			health_bar.visible = false
			damage_text.visible = false
		else:
			health_bar.visible = true

func _ready():
	damage_text.modulate.a = 0
	health_bar.max_value = max_health
	health = max_health
	health_bar.visible = false

func apply_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	damage_text.text = str(amount)
	animPlayer.stop()
	animPlayer.play("damage_text")
	if health <= 0:
		emit_signal("no_health")
	else:
		emit_signal("damage_received")

func _on_hurt_box_area_entered(_area: Area2D) -> void:
	apply_damage(Global.player_damage)
