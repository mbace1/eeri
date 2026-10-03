@tool
class_name EeriWorklamp
extends EeriArtCutout
## One work lamp. scenery.json already lists this prop (`worklamp`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "worklamp"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "WORK LAMP"
	marker_color = Color(0.72, 0.55, 0.22)
	set_meta("eeri_prop", PROP)
