@tool
class_name EeriBlueprint
extends EeriMarker
## One per world — unlocks concept art (deferred: no gallery yet, DESIGN
## §6.3's owner note, 2026-08-21).
func _init() -> void:
	marker_color = Color(0.7, 0.85, 1.0)
func _label_text() -> String:
	return "BLUEPRINT"
