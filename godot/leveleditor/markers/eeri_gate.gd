@tool
class_name EeriGate
extends EeriMarker
## A world's clock-out gate, placed after its big flag.
func _init() -> void:
	marker_color = Color(0.25, 0.70, 0.35)

func _label_text() -> String:
	return "CLOCK-OUT GATE"
