@tool
class_name EeriGolden
extends EeriMarker
## A golden bolt — three per level, hidden (DESIGN §4.2).
func _init() -> void:
	marker_color = Color(1.0, 0.86, 0.15)
func _label_text() -> String:
	return "GOLDEN"
