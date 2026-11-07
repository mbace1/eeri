@tool
class_name EeriTreeOak
extends EeriArtCutout
## The existing oak cutout uses the shared saved-art property contract.
const PROP := "treeOak"

func _init() -> void:
	prop_key = PROP
	gizmo_label = "OAK"
	marker_color = Color(0.45, 0.38, 0.18)
	set_meta("eeri_prop", PROP)
