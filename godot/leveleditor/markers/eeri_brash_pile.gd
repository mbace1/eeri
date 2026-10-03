@tool
class_name EeriBrashPile
extends EeriArtCutout
## One brash pile. World 3 forest clearing. scenery.json lists this prop (`brashPile`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "brashPile"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "BRASH"
	marker_color = Color(0.34, 0.50, 0.22)
	set_meta("eeri_prop", PROP)
