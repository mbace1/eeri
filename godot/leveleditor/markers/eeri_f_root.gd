@tool
class_name EeriFRoot
extends EeriArtCutout
## One root. scenery.json already lists this prop (`fRoot`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fRoot"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "ROOT"
	marker_color = Color(0.45, 0.32, 0.18)
	set_meta("eeri_prop", PROP)
