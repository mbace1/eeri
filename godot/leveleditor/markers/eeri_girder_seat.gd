@tool
class_name EeriGirderSeat
extends EeriSpanMarker
## THE WINDOW THE MACHINE MUST STAND IN to lower the girder — not where the
## girder ends up. Reading this as a destination rather than a standing
## window was a real bug in the first port; the field names here match the
## JSON schema (x0/x1) so it cannot happen again by accident.
func _init() -> void:
	marker_color = Color(0.4, 0.8, 0.9)
func _label_text() -> String:
	return "GIRDER SEAT WINDOW"
