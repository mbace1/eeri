@tool
class_name EeriCargo
extends EeriArtCutout
## One cargo stack. scenery.json already lists this prop (`cargo`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "cargo"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "CARGO"
	marker_color = Color(0.48, 0.32, 0.22)
	set_meta("eeri_prop", PROP)
