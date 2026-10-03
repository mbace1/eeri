@tool
class_name EeriTreeBirch
extends EeriMarker
## One birch. scenery.json already lists this prop (`treeBirch`) and
## SceneryData.mount_art already mounts its cutout. This prefab is that
## piece, so a drop uses EeriLayerRail.place and a later drag uses snap_xy.
## The texture is the file the art row already names. Nothing new is drawn.

const PROP := "treeBirch"

func _init() -> void:
	marker_color = Color(0.72, 0.78, 0.70)
	set_meta("eeri_prop", PROP)

func _label_text() -> String:
	return "BIRCH"

func _build_gizmo() -> void:
	super._build_gizmo()
	_mount_cutout()

## Same quad the runtime mount builds: the row's height, standing on the
## marker so the snap point is where the tree meets the ground.
func _mount_cutout() -> void:
	if get_node_or_null("Cutout") != null:
		return
	var data := SceneryData.load_data()
	if not data.art.has(PROP):
		push_warning("treeBirch is not in scenery art")
		return
	var spec: Dictionary = data.art[PROP]
	var tex := load("res://data/" + String(spec.get("file", ""))) as Texture2D
	if tex == null:
		push_warning("treeBirch art missing")
		return
	var sz := tex.get_size()
	if sz.y <= 0.0:
		return
	var h := float(spec.get("h", 1.0))
	var mi := MeshInstance3D.new()
	mi.name = "Cutout"
	var q := QuadMesh.new()
	q.size = Vector2(h * (sz.x / sz.y), h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, h * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
