@tool
class_name EeriFStones
extends EeriArtCutout
## One cluster of stones. scenery.json already lists this prop (`fStones`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "fStones"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "STONES"
	marker_color = Color(0.42, 0.42, 0.40)
	set_meta("eeri_prop", PROP)
