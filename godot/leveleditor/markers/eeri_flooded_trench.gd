@tool
class_name EeriFloodedTrench
extends EeriSpanMarker
## World 2's pump job (js/parts.js `flooded`). A trench full of deep water
## that a run cannot clear, until the pump drains it a pass at a time and the
## last pass hands the floor back.
##
## Leave the GridMap cells EMPTY from the ground row down, the same as a pit:
## the hole is the absence of tiles, and this marker carries what empty cells
## cannot — that the hole is water, that it belongs to a pump, and where a
## fall puts you back (three tiles before the near lip, as parts.js does).
## Pair it with an EeriMachineSpawn set to PUMP or the exporter says so.
func _init() -> void:
	marker_color = Color(0.10, 0.30, 0.40)
func _label_text() -> String:
	return "FLOODED TRENCH (pump)"
