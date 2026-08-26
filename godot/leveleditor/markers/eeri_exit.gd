@tool
class_name EeriExit
extends EeriMarker
## The far end of the room — where a fall respawn falls back to if there is
## no closer checkpoint or pit. Exactly one per level.
func _init() -> void:
	marker_color = Color(0.9, 0.2, 0.8)
func _label_text() -> String:
	return "EXIT"
