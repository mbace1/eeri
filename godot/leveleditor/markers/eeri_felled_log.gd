@tool
class_name EeriFelledLog
extends EeriArtCutout
## One felled log. World 3 forest clearing. scenery.json lists this prop (`felledLog`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "felledLog"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "LOG"
	marker_color = Color(0.42, 0.48, 0.28)
	set_meta("eeri_prop", PROP)
