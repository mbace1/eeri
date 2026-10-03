@tool
class_name EeriStumpClearing
extends EeriArtCutout
## One stump clearing. scenery.json already lists this prop (`stumpClearing`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "stumpClearing"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "STUMP"
	marker_color = Color(0.30, 0.46, 0.30)
	set_meta("eeri_prop", PROP)
