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

const BUILD := "v31-subviewport"
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
## v29 ON THE PHONE, and it is the clearest result of the hunt:
##
##   env-only      BOTH-OK    in=4AA8E8 out=4AA8E8
##   cube-standard CUBE-BLACK in=000000 out=4AA8E8
##   cube-shader   CUBE-BLACK in=000000 out=4AA8E8
##   cube-emission CUBE-BLACK in=000000 out=4AA8E8
##
## The sky renders, the cube DRAWS, and it comes out black -- through a stock
## material, a four-line hand-written shader, and emission alike. 2D has
## rendered perfectly throughout (this very label). So SPATIAL fragment output
## is being zeroed on this device while canvas output is not.
##
## v30 asks the only two questions that matter now:
##
##   CAN 3D BE FIXED?  Godot's compatibility renderer applies exposure and
##     tonemapping to spatial fragments from the scene uniform buffer. If that
##     buffer is not reaching the shader, every 3D fragment is multiplied by
##     zero while the clear -- which never enters the shader -- survives. Rungs
##     2 and 3 set exposure and tonemap explicitly instead of by default.
##
##   IF NOT, IS 2D VIABLE?  Rungs 4 and 5 draw a real diorama layer as a
##     Sprite2D on a CanvasLayer, and the same texture as a Sprite3D. Eeri's
##     art is FLAT PAINTED LANES -- the browser build renders them unlit on
##     plain planes -- so if 2D can draw them, this port has a real route home
##     that does not depend on spatial shaders at all.
## v30 ON THE PHONE:
##
##   env-only      BOTH-OK    in=4AA8E8   the clear works
##   cube-exposure CUBE-BLACK in=000000   explicit exposure does not help
##   cube-tonemap  CUBE-BLACK in=000000   nor does ACES
##   sprite2d      BOTH-OK    in=75BCEA   THE REAL DIORAMA TEXTURE DRAWS
##   sprite3d      CUBE-BLACK in=000000   Sprite3D is spatial, so black
##
## Two facts now stand: every spatial shader outputs black, and the 2D
## pipeline draws this game's own painted art correctly.
##
## THE GAP I LEFT. piritori-eden renders its 3D inside a SubViewport with
## own_world_3d = true, and it renders on this phone. v25 tried that shape on
## the FULL GAME and failed -- but the full game has a hundred other things
## that could have been wrong, and every bare-cube rung since has rendered
## DIRECT to the screen. A bare cube inside a Piritori-shaped SubViewport has
## never actually been tested here. If that draws, the difference between this
## port and the one that works is architectural and fixable, and the 2D
## rebuild is unnecessary.
##
##   3 cube-subviewport  the same red cube, inside SubViewport +
##                       own_world_3d + its own camera and environment,
##                       composited by SubViewportContainer -- Piritori's
##                       exact arrangement.
var _stages := [
	["env-only", "_s_env_only", ""],
	["cube-direct", "_s_cube_direct", ""],
	["cube-subviewport", "_s_cube_subviewport", ""],
	["sprite2d-layer", "_s_sprite2d", ""],
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
	## TWO POINTS, and this is the whole point of v29.
	##
	## v27 stage 4 put a cube in front of a SKY-BLUE environment and read
	## 000000. If the cube were not drawing we would have read 4AA8E8. So the
	## geometry IS drawing -- it is drawing BLACK -- and every build before
	## this was chasing "nothing rasterises" when the truth is "everything
	## rasterises black". Those need opposite fixes.
	##
	## But one sample cannot tell "black cube over blue sky" from "the whole
	## frame was destroyed", because the centre is black either way. So each
	## rung now uses a SMALL cube and samples the centre (inside it) and a
	## corner (outside it):
	##
	##   IN=000000 OUT=4AA8E8 -> the cube draws black. A shader-output bug,
	##                           and a tractable one.
	##   IN=000000 OUT=000000 -> the draw call destroys the whole frame. A
	##                           tile-based-renderer failure, and a much
	##                           harder one.
	var verdict := "SKIP"
	var inhex := "??????"
	var outhex := "??????"
	var img: Image = null
	var tex := get_viewport().get_texture()
	if tex:
		img = tex.get_image()
	if img and img.get_width() > 0:
		var w := img.get_width()
		var h := img.get_height()
		var ci := img.get_pixel(w / 2, h / 2)
		var co := img.get_pixel(int(w * 0.04), int(h * 0.10))
		inhex = "%02X%02X%02X" % [int(ci.r * 255.0), int(ci.g * 255.0), int(ci.b * 255.0)]
		outhex = "%02X%02X%02X" % [int(co.r * 255.0), int(co.g * 255.0), int(co.b * 255.0)]
		var lit_in := (ci.r + ci.g + ci.b) > 0.15
		var lit_out := (co.r + co.g + co.b) > 0.15
		if lit_in and lit_out:
			verdict = "BOTH-OK"
		elif not lit_in and lit_out:
			verdict = "CUBE-BLACK"
		elif not lit_in and not lit_out:
			verdict = "FRAME-DEAD"
		else:
			verdict = "ODD"
	else:
		verdict = "NOREAD"
	_results.append("%d %s: %s in=%s out=%s" % [_stage + 1,
		_stages[_stage][0], verdict, inhex, outhex])
	_label.text = "[%s] %d/%d
%s" % [BUILD, _stage + 1, _stages.size(),
		"
".join(_results)]


# ---- the rungs -------------------------------------------------------------

func _sky() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)
	env.environment = e
	_holder.add_child(env)


## SIZED AGAINST THE FRUSTUM, not by eye. At fov 40 and z=5 the visible
## half-height is 5*tan(20deg)=1.82 and the portrait half-width only
## 1.82*(420/900)=0.85. A 1.4 cube therefore spanned ~82% of the WIDTH and
## the first "outside" sample at x=6% sat on its edge, reading FF0000 on
## desktop -- an instrument that would have reported BOTH-OK on the phone no
## matter what happened. 0.8 spans ~47% of width; the sample moved to the
## x=4%,y=10% corner, well clear of it.
func _small_cube(mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.8, 0.8, 0.8)
	mi.mesh = m
	mi.material_override = mat
	_holder.add_child(mi)


func _s_env_only() -> void:
	_sky()


func _s_cube_direct() -> void:
	_sky()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0, 0)
	_small_cube(mat)


## PIRITORI'S EXACT ARRANGEMENT, down to the ordering trap its own comment
## records: own_world_3d must be set BEFORE anything is added to the viewport,
## "or they are added to a world this viewport is about to stop using".
func _s_cube_subviewport() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	_holder.add_child(layer)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)
	env.environment = e
	vp.add_child(env)

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.5
	cam.far = 100.0
	cam.position = Vector3(0, 0, 5)
	cam.current = true
	vp.add_child(cam)

	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.8, 0.8, 0.8)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0, 0)
	mi.material_override = mat
	vp.add_child(mi)


## THE ESCAPE ROUTE. A real diorama layer drawn by the 2D pipeline, which has
## worked on this device in every single build. If this shows, the port can be
## rebuilt on CanvasItems and never touch a spatial shader again.
func _s_sprite2d() -> void:
	_sky()
	var t := load("res://data/2d/day_sky_v2.webp") as Texture2D
	var layer := CanvasLayer.new()
	layer.layer = 5
	var sp := Sprite2D.new()
	if t:
		sp.texture = t
	sp.centered = true
	sp.position = get_viewport().get_visible_rect().size * 0.5
	sp.scale = Vector2(0.25, 0.25)
	layer.add_child(sp)
	_holder.add_child(layer)


func _s_sprite3d() -> void:
	_sky()
	var t := load("res://data/2d/day_sky_v2.webp") as Texture2D
	var sp := Sprite3D.new()
	if t:
		sp.texture = t
	sp.pixel_size = 0.0015
	sp.position = Vector3(0, 0, 0)
	_holder.add_child(sp)


func _s_cube_emission() -> void:
	_sky()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0)
	mat.emission_enabled = true
	mat.emission = Color(1, 0, 0)
	mat.emission_energy_multiplier = 2.0
	_small_cube(mat)
