@tool
class_name EeriHazardVent
extends EeriMarker
## A steam vent. Telegraphs >=1.0s before it is lethal (DESIGN §4.1) — the
## timing is fixed in scripts/hazard.gd and is not authored per-instance.
func _init() -> void:
	marker_color = Color(0.86, 0.62, 0.14)
func _label_text() -> String:
	return "VENT"
