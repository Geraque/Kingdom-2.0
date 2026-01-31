extends Enemy

func _ready() -> void:
	damage = 15
	state = CHASE

func _on_mob_health_no_health() -> void:
	Signals.emit_signal("enemy_died", position, state)
	state = DEATH

func _on_mob_health_damage_received() -> void:
	state = IDLE
	state = DAMAGE
