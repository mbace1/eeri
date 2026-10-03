@tool
class_name EeriCableReel
extends EeriArtCutout
## One cable reel. scenery.json already lists this prop (`cableReel`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "cableReel"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "REEL"
	marker_color = Color(0.55, 0.36, 0.24)
	set_meta("eeri_prop", PROP)
