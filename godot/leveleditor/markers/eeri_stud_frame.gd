@tool
class_name EeriStudFrame
extends EeriArtCutout
## One stud frame. World 1 groundworks. scenery.json lists this prop (`studFrame`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "studFrame"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "FRAME"
	marker_color = Color(0.82, 0.74, 0.55)
	set_meta("eeri_prop", PROP)
