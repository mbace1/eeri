@tool
class_name EeriOffice
extends EeriArtCutout
## One site office. scenery.json already lists this prop (`office`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "office"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "OFFICE"
	marker_color = Color(0.55, 0.48, 0.38)
	set_meta("eeri_prop", PROP)
