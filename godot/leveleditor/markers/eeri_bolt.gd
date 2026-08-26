@tool
class_name EeriBolt
extends EeriMarker
## One bolt. A hundred of these is the level's completion figure (DESIGN
## §4.2) — tedious to place a hundred by hand, so EeriBoltRun (below) is the
## practical way to lay a trail; this is the single-bolt primitive it uses.
func _init() -> void:
	marker_color = Color(0.90, 0.78, 0.25)
func _label_text() -> String:
	return ""   # a hundred labels on screen at once is not useful
