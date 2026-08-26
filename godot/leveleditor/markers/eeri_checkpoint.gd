@tool
class_name EeriCheckpoint
extends EeriMarker
## Mario World's gate. Running past it lights it; a fall then returns here,
## never to the start (DESIGN §4). At most one per level.
func _init() -> void:
	marker_color = Color(0.3, 0.9, 0.9)
func _label_text() -> String:
	return "CHECKPOINT"
