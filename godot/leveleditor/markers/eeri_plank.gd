@tool
class_name EeriPlank
extends EeriSpanMarker
## The existing tipping-plank mechanic; position.y is its starting deck.
func _init() -> void:
	marker_color = Color(0.70, 0.48, 0.22)

func _label_text() -> String:
	return "TIPPING PLANK"
