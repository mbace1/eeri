@tool
class_name EeriFDrum
extends EeriArtCutout
## One buried drum. scenery.json already lists this prop (`fDrum`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fDrum"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "DRUM"
	marker_color = Color(0.42, 0.28, 0.22)
	set_meta("eeri_prop", PROP)
