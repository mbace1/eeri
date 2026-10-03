@tool
class_name EeriBarrierLamps
extends EeriArtCutout
## One lit barrier. scenery.json already lists this prop (`barrierLamps`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "barrierLamps"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "BARRIER"
	marker_color = Color(0.62, 0.48, 0.12)
	set_meta("eeri_prop", PROP)
