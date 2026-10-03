@tool
class_name EeriWheelbarrow
extends EeriArtCutout
## One wheelbarrow. World 1 groundworks. scenery.json lists this prop (`wheelbarrow`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "wheelbarrow"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "BARROW"
	marker_color = Color(0.55, 0.40, 0.26)
	set_meta("eeri_prop", PROP)
