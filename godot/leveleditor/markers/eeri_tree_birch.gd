@tool
class_name EeriTreeBirch
extends EeriArtCutout
## The existing birch cutout uses the shared saved-art property contract.
const PROP := "treeBirch"

func _init() -> void:
	prop_key = PROP
	gizmo_label = "BIRCH"
	marker_color = Color(0.62, 0.70, 0.44)
	set_meta("eeri_prop", PROP)
