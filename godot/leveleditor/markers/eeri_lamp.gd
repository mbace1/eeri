@tool
class_name EeriLamp
extends EeriMarker
## A shared scenery lamp. Its point is the center of the light card.
@export_range(0.1, 32.0, 0.1) var radius := 6.0
@export_range(0.0, 2.0, 0.05) var intensity := 1.0
@export var light_colour := Color("ffd9a0")
@export_range(0.0, 0.2, 0.01) var flicker := 0.0

func _init() -> void:
	marker_color = Color("ffd08a")

func _label_text() -> String:
	return "SCENERY LAMP"

func scenery_row() -> Dictionary:
	return {"prop": "lamp", "x": position.x, "y": position.y, "z": position.z,
		"layer": String(get_meta("eeri_layer", "play")).to_lower(),
		"r": radius, "i": intensity, "colour": "#" + light_colour.to_html(false), "flicker": flicker}
