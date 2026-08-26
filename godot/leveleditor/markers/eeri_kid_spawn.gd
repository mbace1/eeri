@tool
class_name EeriKidSpawn
extends EeriMarker
## Where Eeri stands at the start of the level. Exactly one per level.
func _init() -> void:
	marker_color = Color(0.2, 0.9, 0.3)
func _label_text() -> String:
	return "KID SPAWN"
