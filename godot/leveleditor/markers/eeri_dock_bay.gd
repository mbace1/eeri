@tool
class_name EeriDockBay
extends EeriArtCutout
## One dock bay. scenery.json already lists this prop (`dockBay`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "dockBay"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "DOCK"
	marker_color = Color(0.32, 0.38, 0.44)
	set_meta("eeri_prop", PROP)
