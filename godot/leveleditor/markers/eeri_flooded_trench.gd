@tool
class_name EeriFloodedTrench
extends EeriSpanMarker
## Position.y is the row the pump restores. The span is an inclusive c0/c1
## range, matching js/parts.js flooded().
func _init() -> void:
	marker_color = Color(0.16, 0.50, 0.62)
	position.y = 3.0

func _label_text() -> String:
	return "FLOODED TRENCH"
