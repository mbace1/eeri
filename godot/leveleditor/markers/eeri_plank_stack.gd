@tool
class_name EeriPlankStack
extends EeriArtCutout
## One plank stack. World 1 groundworks. scenery.json lists this prop (`plankStack`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "plankStack"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "PLANKS"
	marker_color = Color(0.78, 0.66, 0.46)
	set_meta("eeri_prop", PROP)
