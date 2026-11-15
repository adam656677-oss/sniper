extends Label

# Mission HUD text. Content is written by the mission each physics frame.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(20, 20)
