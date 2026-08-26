@tool
class_name EeriPipeMouth
extends EeriMarker
## One end of a pipe. Set `linked_to` to the OTHER mouth's node path — the
## exporter reads pairs by following the link, so a level with several pipes
## does not have to keep them in list order. DESIGN: you must be STANDING at
## a mouth to enter (a pipe you fall into by accident takes the level away
## from you), and there is a cooldown so the far mouth does not read as a
## fresh entrance the instant you arrive.
@export var linked_to: NodePath
func _init() -> void:
	marker_color = Color(0.55, 0.65, 0.75)
func _label_text() -> String:
	return "PIPE MOUTH"
