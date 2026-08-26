@tool
class_name EeriBoltRun
extends EeriMarker
## A convenience the JSON schema does not have: a straight run of ordinary
## bolts from this marker's position to (position.x + length), one per tile,
## at this marker's height. The exporter expands it into plain bolt entries —
## a hundred hand-placed EeriBolt nodes is not a reasonable way to spend an
## afternoon. For anything that is not a straight line, place EeriBolt nodes
## directly.
@export var length := 10.0
func _init() -> void:
	marker_color = Color(0.90, 0.78, 0.25)
func _label_text() -> String:
	return "BOLT RUN x%d" % int(length)
