@tool
class_name EeriWaterRegion
extends EeriSpanMarker
## Water metadata layered over the terrain. SHALLOW water is the `~` GridMap
## tile (a floor that wades — js/kid.js WADE); this marker exists for DEEP
## water, which js/parts.js says plainly is "a HOLE, not a wall... a pit
## wearing different paint" — so `deep` water sits over EMPTY GridMap cells,
## the same as EeriPit, and returns you the same way (`respawns`).
@export var deep := false
func _init() -> void:
	marker_color = Color(0.25, 0.55, 0.75)
func _label_text() -> String:
	return "WATER (deep)" if deep else "WATER"
