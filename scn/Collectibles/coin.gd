extends CharacterBody2D

func _ready():
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(self, "velocity", Vector2(randi_range(-50, 50), -150), 0.3)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.x = 0
	
	move_and_slide()


func _on_detector_body_entered(_body: Node2D) -> void:
	if is_on_floor():
		Global.gold += 1
		var tween = get_tree().create_tween()
		tween.parallel().tween_property(self, "velocity", Vector2(0, -150), 0.3)
		tween.parallel().tween_property(self, "modulate:a", 0, 0.5)
		await get_tree().create_timer(0.5).timeout
		queue_free()
