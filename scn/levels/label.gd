extends Label


func _ready() -> void:
	await get_tree().create_timer(30).timeout
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.5)
