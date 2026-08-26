@tool
class_name EeriFlag
extends EeriMarker
## Ends the level, building itself in three phases as you approach and
## raising on being run past — no button (DESIGN §4.2). Exactly one per
## level. `big` marks a world-ending flag (bigger, different colour).
@export var big := false
func _init() -> void:
	marker_color = Color(0.95, 0.25, 0.2)
func _label_text() -> String:
	return "FLAG (big)" if big else "FLAG"
