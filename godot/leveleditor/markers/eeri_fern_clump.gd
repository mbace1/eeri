@tool
class_name EeriFernClump
extends EeriArtCutout
## One fern clump. World 3 forest clearing. scenery.json lists this prop (`fernClump`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fernClump"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "FERNS"
	marker_color = Color(0.28, 0.48, 0.26)
	set_meta("eeri_prop", PROP)
