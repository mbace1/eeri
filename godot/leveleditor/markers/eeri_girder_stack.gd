@tool
class_name EeriGirderStack
extends EeriMarker
## Where the girder starts, stacked. The bucket takes it from here — DESIGN's
## "same gesture as the dig, the other way round". Pair with one
## EeriGirderGap and one EeriGirderSeat per girder.
func _init() -> void:
	marker_color = Color(0.86, 0.62, 0.14)
func _label_text() -> String:
	return "GIRDER STACK"
