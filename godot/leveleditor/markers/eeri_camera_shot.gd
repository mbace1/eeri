@tool
class_name EeriCameraShot
extends EeriMarker
## An authored camera zone (js/camera.js SHOTS). Positioned at its LEFT edge
## (x0); `width` gives x1 = x0 + width. "A lock you cannot see is not a
## lock" — a room whose lock needs room to read pulls the camera back here.
@export var width := 10.0
@export var dolly_z := 34.0
@export var height_offset := 2.6
@export var lead := 1.6
@export var floor_y := 5.8
func _init() -> void:
	marker_color = Color(0.6, 0.6, 1.0)
func _label_text() -> String:
	return "SHOT z=%.0f" % dolly_z
