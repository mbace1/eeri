@tool
class_name EeriTreeSpruce
extends EeriArtCutout
## The existing spruce cutout uses the shared saved-art property contract.
const PROP := "treeSpruce"

func _init() -> void:
	prop_key = PROP
	gizmo_label = "SPRUCE"
	marker_color = Color(0.25, 0.45, 0.28)
	set_meta("eeri_prop", PROP)
