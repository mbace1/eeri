@tool
class_name EeriArtCutout
extends EeriMarker
## Shared mount for a scenery.json art row that already has a texture file.
## This is not a prefab. Each piece is its own subclass, so the FileSystem
## dock has one scene to drag, and a drop still goes through EeriLayerRail.place
## while a later drag still goes through snap_xy. Nothing here draws new art.

@export var prop_key := "" : set = _set_prop
## Zero keeps the catalog's height. These are authored properties, so they
## survive saving/reopening the scene and are also read by the exporter.
@export_range(0.0, 32.0, 0.1) var art_height := 0.0 : set = _set_height
@export var art_flip := false : set = _set_flip
@export_range(0.0, 1.0, 0.01) var art_opacity := 1.0 : set = _set_opacity
var gizmo_label := ""


func _label_text() -> String:
	if gizmo_label != "":
		return gizmo_label
	return super._label_text()


func _build_gizmo() -> void:
	super._build_gizmo()
	_mount_cutout()


## Same quad SceneryData.mount_art builds: the row's height, standing on the
## marker so the snap point is where the piece meets the ground.
func _mount_cutout() -> void:
	if get_node_or_null("Cutout") != null:
		return
	if prop_key == "":
		return
	var data := SceneryData.load_data()
	if not data.art.has(prop_key):
		push_warning("%s is not in scenery art" % prop_key)
		return
	var spec: Dictionary = data.art[prop_key]
	var tex := load("res://data/" + String(spec.get("file", ""))) as Texture2D
	if tex == null:
		push_warning("%s art missing" % prop_key)
		return
	var sz := tex.get_size()
	if sz.y <= 0.0:
		return
	var h := art_height if art_height > 0.0 else float(spec.get("h", 1.0))
	var mi := MeshInstance3D.new()
	mi.name = "Cutout"
	var q := QuadMesh.new()
	q.size = Vector2(h * (sz.x / sz.y), h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, art_opacity)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, h * 0.5, 0)
	mi.scale.x = -1.0 if art_flip else 1.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func scenery_row() -> Dictionary:
	var data := SceneryData.load_data()
	var spec: Dictionary = data.art.get(prop_key, {})
	return {"prop": prop_key, "x": position.x, "y": position.y,
		"z": position.z, "layer": String(get_meta("eeri_layer", "play")).to_lower(),
		"h": art_height if art_height > 0.0 else float(spec.get("h", 1.0)),
		"flip": art_flip, "o": art_opacity}


func _refresh_art() -> void:
	var cutout := get_node_or_null("Cutout")
	if cutout != null:
		remove_child(cutout)
		cutout.queue_free()
	if is_inside_tree():
		_mount_cutout()


func _set_prop(value: String) -> void:
	prop_key = value
	set_meta("eeri_prop", value)
	_refresh_art()


func _set_height(value: float) -> void:
	art_height = value
	_refresh_art()


func _set_flip(value: bool) -> void:
	art_flip = value
	_refresh_art()


func _set_opacity(value: float) -> void:
	art_opacity = value
	_refresh_art()
