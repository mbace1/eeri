@tool
class_name EeriHoist
extends EeriSpanMarker
## A lift platform — the one floor that is not a tile (scripts/hoist.gd). It
## travels the vertical shaft from cy0 (this marker's y) to cy1 on a
## `period`-second triangle wave, never a sine ("you WAIT for it, and waiting
## is only fair if the arrival is predictable").
@export var cy1 := 9.0
@export var period := 4.0
func _init() -> void:
	marker_color = Color(0.72, 0.72, 0.74)
func _label_text() -> String:
	return "HOIST %.0fs" % period
