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

const BUILD := "v28-noautoload"
const STAGE_SECONDS := 4.0

var _label: Label
var _stage := -1
var _results: Array[String] = []
var _holder: Node3D
var _cam: Camera3D
var _timer := 0.0
var _settle := 0

## v26 ON THE PHONE gave the first differential result of the whole hunt:
## a scene with NO geometry renders its clear colour perfectly (stage 3
## PASS 4AA8E8), and a scene with ANY geometry reads pure 000000 -- not
## the geometry's colour, not the clear behind it, black. One draw call
## takes the whole output with it. PowerVR is a tile-based renderer, so
## "one bad draw blackens the tile" is a known shape of failure -- but
## piritori-eden draws equivalent geometry on the same phone, so the
## fault is something THIS project feeds the draw, not the draw itself.
##
## v27 narrows what: the material's generated shader, the environment's
## presence, and the autoloads are the three differences left standing.
##
##   1 empty          nothing at all -- expect Godot's default grey. The
##                    baseline that proves the readback and the clear.
##   2 cube-standard  StandardMaterial3D unshaded (v26 stage 1, FAIL)
##   3 cube-shader    a FOUR-LINE hand-written spatial shader. If this
##                    passes where 2 fails, StandardMaterial's generated
##                    shader is the fault and materials can be replaced.
##   4 cube-env       the standard cube WITH a WorldEnvironment -- v26
##                    never combined geometry with an environment.
##   5 quad-shader    the minimal shader on a QuadMesh -- mesh shape.
##   6 cube-no-autoload  the standard cube after freeing all four
##                    autoloads (Audio, Loc, AssetRegistry, GameState).
var _stages := [
	["empty", "_s_empty", "grey"],
	["cube-standard", "_s_cube_unshaded", "red"],
	["cube-shader", "_s_cube_shader", "red"],
	["quad-shader", "_s_quad_shader", "red"],
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
			"grey": ok = (c.r + c.g + c.b) > 0.15 				and absf(c.r - c.g) < 0.1 and absf(c.g - c.b) < 0.1
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


func _s_empty() -> void:
	pass


func _s_cube_unshaded() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0, 0)
	_holder.add_child(_cube(mat))


func _min_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;
render_mode unshaded;
void fragment() { ALBEDO = vec3(1.0, 0.0, 0.0); }
"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _s_cube_shader() -> void:
	_holder.add_child(_cube(_min_shader()))


func _s_cube_env() -> void:
	_s_cube_unshaded()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)
	env.environment = e
	_holder.add_child(env)


func _s_quad_shader() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3, 3)
	mi.mesh = q
	mi.material_override = _min_shader()
	_holder.add_child(mi)


func _s_cube_no_autoload() -> void:
	for n in ["Audio", "Loc", "AssetRegistry", "GameState"]:
		var a := get_node_or_null("/root/" + n)
		if a:
			a.queue_free()
	_s_cube_unshaded()
