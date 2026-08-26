@tool
class_name EeriRobot
extends EeriSpanMarker
## A small machine — hopper, roller, bucket or skitter (DESIGN §3). Patrols
## between this marker's position and position + span_width. `on_deck` marks
## it as riding a fixed platform (a hoist deck) rather than the ground —
## leave unchecked for ground-standing, which is the common case.
enum Kind {SKITTER, HOPPER, ROLLER, BUCKET}
@export var kind := Kind.SKITTER
@export var on_deck := false
@export var deck_y := 4.0
func _init() -> void:
	marker_color = Color(0.85, 0.35, 0.18)
func _label_text() -> String:
	return "ROBOT: %s" % Kind.keys()[kind].to_lower()
func kind_string() -> String:
	return Kind.keys()[kind].to_lower()
