@tool
class_name EeriGirderGap
extends EeriSpanMarker
## The gap the girder bridges once seated — a hole (leave the GridMap cells
## here empty) that becomes a real walked-on floor at this marker's y when
## the girder is placed. THE SPAN IS WALKED ON, so seating it edits the grid,
## exactly as the wall does when the ball brings it down.
func _init() -> void:
	marker_color = Color(0.55, 0.55, 0.58)
func _label_text() -> String:
	return "GIRDER GAP"
