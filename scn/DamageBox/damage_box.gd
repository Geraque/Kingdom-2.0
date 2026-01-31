extends Node2D

func _ready() -> void:
	var shape: CollisionShape2D = $HitBox/CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", true)
