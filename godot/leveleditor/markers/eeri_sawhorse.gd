@tool
class_name EeriSawhorse
extends EeriArtCutout
## One sawhorse. World 1 groundworks. scenery.json lists this prop (`sawhorse`) and
## SceneryData.mount_art already mounts its cutout.
## This prefab is that piece, so a drop uses EeriLayerRail.place and a later
## drag uses snap_xy. The texture is the file the art row already names.
## Nothing new is drawn.

const PROP := "sawhorse"


func _init() -> void:
	prop_key = PROP
	gizmo_label = "SAWHORSE"
	marker_color = Color(0.86, 0.48, 0.28)
	set_meta("eeri_prop", PROP)
