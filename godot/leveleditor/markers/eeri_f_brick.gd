@tool
class_name EeriFBrick
extends EeriArtCutout
## One brickwork chunk. scenery.json already lists this prop (`fBrick`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fBrick"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "BRICK"
	marker_color = Color(0.55, 0.28, 0.22)
	set_meta("eeri_prop", PROP)
