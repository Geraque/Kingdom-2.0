extends Node2D

var coint_preload = preload("res://scn/Collectibles/coin.tscn")

func _ready() -> void:
	Signals.connect("enemy_died", Callable(self, "_on_enemy_died"))


func _on_enemy_died(enemy_position, state):
	if state != 4:
		for i in randi_range(2,4):
			coin_spawn(enemy_position)
			await get_tree().create_timer(0.05).timeout

func coin_spawn(pos):
	var coin = coint_preload.instantiate()
	coin.position = pos
	call_deferred("add_child",coin)
