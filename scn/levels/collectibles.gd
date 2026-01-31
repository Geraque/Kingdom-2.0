extends Node2D

var coint_preload = preload("res://scn/Collectibles/coin.tscn")

func _ready() -> void:
	Signals.connect("enemy_died", Callable(self, "_on_enemy_died"))
	Signals.connect("spawner_destroyed", Callable(self, "_on_spawner_destroyed"))


func _on_enemy_died(enemy_position, state):
	if state != 4:
		for i in randi_range(2,4):
			coin_spawn(enemy_position)
			await get_tree().create_timer(0.05).timeout


func _on_spawner_destroyed(spawner_position, multiplier):
	var base := randi_range(2, 4)
	var total := base * int(multiplier)

	for i in range(total):
		coin_spawn(spawner_position)
		await get_tree().create_timer(0.03).timeout


func coin_spawn(pos):
	var coin = coint_preload.instantiate()
	coin.position = pos
	call_deferred("add_child", coin)
