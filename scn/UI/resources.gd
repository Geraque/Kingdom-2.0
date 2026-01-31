extends CanvasLayer

@onready var gold_text: Label = $Control/PanelContainer/HBoxContainer/goldText
@onready var wood_text: Label = $Control/PanelContainer/HBoxContainer/woodText
@onready var rock_text: Label = $Control/PanelContainer/HBoxContainer/rockText

func _process(_delta: float) -> void:
	gold_text.text = str(Global.gold)
	wood_text.text = str(Global.wood)
	rock_text.text = str(Global.rock)
