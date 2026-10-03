@tool
class_name EeriFPipe
extends EeriArtCutout
## One buried pipe. scenery.json already lists this prop (`fPipe`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fPipe"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "PIPE"
	marker_color = Color(0.45, 0.48, 0.42)
	set_meta("eeri_prop", PROP)
