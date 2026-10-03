@tool
class_name EeriFBottle
extends EeriArtCutout
## One bottle. scenery.json already lists this prop (`fBottle`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fBottle"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "BOTTLE"
	marker_color = Color(0.35, 0.48, 0.42)
	set_meta("eeri_prop", PROP)
