extends Node3D
## THE BISECT, FROM THE WORKING END — v26, 2026-08-27.
##
## Twenty-five builds of theorising found nothing: on the owner's PowerVR
## phone this project's 3D target clears correctly, submits draw calls,
## rasterises NOTHING, errors NOWHERE — direct to screen (v1–v24) and
## composited through a SubViewport exactly as piritori-eden does (v25).
## Meanwhile both sibling ports render 3D on the same device.
##
## So this stops asking "why does the full scene fail" and asks the question
## from the other side: WHAT IS THE SIMPLEST THING THAT FAILS? It boots into
## a bare scene and adds one system at a time, judging each stage by reading
## the viewport's own pixels back, and prints a verdict table on the 2D layer
## (which has never failed anywhere). One visit, one screenshot, the whole
## ladder — instead of one deploy per rung.
##
##   0 cube-unshaded   one camera, one cube, unshaded material. Nothing else.
##   1 cube-lit        the same cube, shaded, plus one DirectionalLight
##   2 environment     a WorldEnvironment with a sky-blue clear
##   3 texture         a quad textured with a real diorama layer (this also
##                     exercises the ETC2/S3TC compressed-texture path)
##   4 multimesh       the cube drawn via MultiMesh, play.gd-style
##   5 skinned-kid     eeri_v5.glb instantiated — skin, clips, the lot
##
## The first stage whose pixel does NOT match its expectation is the answer.
## If even stage 0 fails, the fault is project configuration rather than any
## content, and the next move is a line-by-line project.godot diff against
## toko-drop-godot.

const BUILD := "v26-bisect"
const STAGE_SECONDS := 4.0

var _label: Label
var _stage := -1
var _results: Array[String] = []
var _holder: Node3D
var _cam: Camera3D
var _timer := 0.0
var _settle := 0   # frames to wait before sampling, so the stage has drawn

## name, builder method, expected-colour test (a description + a matcher).
var _stages := [
	["cube-unshaded", "_s_cube_unshaded", "red"],
	["cube-lit", "_s_cube_lit", "reddish"],
	["environment", "_s_environment", "sky-blue"],
	["texture", "_s_texture", "not-black"],
	["multimesh", "_s_multimesh", "red"],
	["skinned-kid", "_s_kid", "not-black"],
]


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.offset_left = 12
	_label.offset_top = 12
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.5
	_cam.far = 100.0
	_cam.position = Vector3(0, 0, 5)
	add_child(_cam)

	_holder = Node3D.new()
	add_child(_holder)
	_next_stage()


func _process(delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_judge()
		return
	_timer += delta
	if _timer >= STAGE_SECONDS:
		_timer = 0.0
		_next_stage()


func _next_stage() -> void:
	_stage += 1
	for c in _holder.get_children():
		c.queue_free()
	if _stage >= _stages.size():
		_label.text = "[%s] DONE — screenshot this\n%s" % [BUILD, "\n".join(_results)]
		set_process(false)
		return
	call(_stages[_stage][1])
	_settle = 30   # ~half a second of frames before sampling
	_label.text = "[%s] stage %d/%d: %s ...\n%s" % [BUILD, _stage + 1,
		_stages.size(), _stages[_stage][0], "\n".join(_results)]


func _judge() -> void:
	var verdict := "SKIP"
	var hex := "??????"
	var img: Image = null
	var tex := get_viewport().get_texture()
	if tex:
		img = tex.get_image()
	if img and img.get_width() > 0:
		var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		hex = "%02X%02X%02X" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
		var expect := String(_stages[_stage][2])
		var ok := false
		match expect:
			"red": ok = c.r > 0.5 and c.g < 0.3 and c.b < 0.3
			"reddish": ok = c.r > 0.25 and c.r > c.g and c.r > c.b
			"sky-blue": ok = c.b > 0.5 and c.b > c.r
			"not-black": ok = (c.r + c.g + c.b) > 0.15
		verdict = "PASS" if ok else "FAIL"
	else:
		verdict = "NOREAD"
	_results.append("%d %s: %s %s" % [_stage + 1, _stages[_stage][0], verdict, hex])
	_label.text = "[%s] stage %d/%d: %s\n%s" % [BUILD, _stage + 1,
		_stages.size(), _stages[_stage][0], "\n".join(_results)]


# ---- the rungs -------------------------------------------------------------

func _cube(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(2, 2, 2)
	mi.mesh = m
	mi.material_override = mat
	return mi


func _s_cube_unshaded() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0, 0)
	_holder.add_child(_cube(mat))


func _s_cube_lit() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0)
	_holder.add_child(_cube(mat))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = false
	_holder.add_child(sun)


func _s_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)
	env.environment = e
	_holder.add_child(env)


func _s_texture() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var t := load("res://data/2d/day_sky_v2.webp") as Texture2D
	if t:
		mat.albedo_texture = t
	else:
		mat.albedo_color = Color(1, 0, 1)   # magenta = asset missing, not GPU
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4, 4)
	mi.mesh = q
	mi.material_override = mat
	_holder.add_child(mi)


func _s_multimesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var m := BoxMesh.new()
	m.size = Vector3(2, 2, 2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0, 0)
	m.material = mat
	mm.mesh = m
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D())
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_holder.add_child(mmi)


func _s_kid() -> void:
	if not ResourceLoader.exists("res://data/3d/eeri_v5.glb"):
		return
	var scene := load("res://data/3d/eeri_v5.glb") as PackedScene
	if scene == null:
		return
	var kid := scene.instantiate()
	kid.position = Vector3(0, -1.5, 2.2)
	_holder.add_child(kid)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = false
	_holder.add_child(sun)
