@tool
class_name EeriPit
extends EeriSpanMarker
## A hole. Falling in respawns near `back_x` — the near lip — not at the
## level start (DESIGN §4). Represented as a GAP in the GridMap terrain (just
## leave those cells empty); this marker only carries the respawn metadata
## the empty cells cannot.
@export var back_x := 0.0
func _init() -> void:
	marker_color = Color(0.15, 0.15, 0.18)
func _label_text() -> String:
	return "PIT (back x=%.0f)" % back_x
