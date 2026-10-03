@tool
class_name EeriFStone
extends EeriArtCutout
## One stone. scenery.json already lists this prop (`fStone`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fStone"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "STONE"
	marker_color = Color(0.50, 0.48, 0.44)
	set_meta("eeri_prop", PROP)
