@tool
class_name EeriLogTunnel
extends EeriArtCutout
## One log tunnel. scenery.json already lists this prop (`logTunnel`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "logTunnel"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "LOG TUNNEL"
	marker_color = Color(0.36, 0.24, 0.14)
	set_meta("eeri_prop", PROP)
