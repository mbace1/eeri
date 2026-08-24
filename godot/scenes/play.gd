extends Node3D
## The playable room: tile geometry, the kid, a camera.
##
## Phase 1 of the port — the ON FOOT 80% (DESIGN.md §1). No rides, no
## enemies, no HUD yet. What it proves is that the ported kinematics
## (scripts/kid.gd) actually drive a body through a real authored room.
##
## The kid's BODY is scripts/kid.gd and is engine-independent; this file only
## draws where that body already is. Keeping those apart is what lets
## tests/test_kid.tscn simulate a jump with no scene, no camera and no GPU.

const DT := 1.0 / 60.0

## `?level=` equivalent — CLAUDE.md §5, "debug affordances are features".
## A level you cannot reach in under 30 seconds is not finished.
@export var start_slug := "eeri-1-1"

var level: LevelData
var kid: Kid

var _model: Node3D
var _anim: AnimationPlayer
var _clip := ""
var _accum := 0.0
var _cam: Camera3D
var _cam_x := 0.0
var _label: Label


func _ready() -> void:
	var slug := start_slug
	# A deep link beats a rebuild. Accepts --level=eeri-1-2 or ?level= on web.
	for a in OS.get_cmdline_args():
		if a.begins_with("--level="):
			slug = a.substr(8)
	if OS.has_feature("web"):
		var q := _web_query_level()
		if q != "":
			slug = q

	level = LevelData.load_slug(slug)
	if level == null:
		push_error("could not load level %s" % slug)
		return

	_build_tiles()
	_build_kid()
	_build_camera()
	_build_hud()


func _web_query_level() -> String:
	if not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var js := Engine.get_singleton("JavaScriptBridge")
	var v = js.eval("new URLSearchParams(location.search).get('level') || ''", true)
	return String(v) if v != null else ""


# ---- the room ------------------------------------------------------------
# One MultiMesh for every solid tile. A room is 96x18 and mostly empty, so
# this is a few hundred instances in a single draw call rather than a few
# hundred nodes — and it rebuilds instantly when the level changes.
func _build_tiles() -> void:
	var boxes: Array[Transform3D] = []
	for r in level.h:
		for c in level.w:
			if level.solid_cell(c, r):
				boxes.append(Transform3D(Basis(), Vector3(c + 0.5, r + 0.5, 0.0)))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	# Craft-diorama palette placeholder. ART_BRIEF's real materials are the Art
	# lane's; this is greybox so the geometry can be READ, and it says so.
	mat.albedo_color = Color(0.55, 0.42, 0.30)
	mat.roughness = 0.95
	box.material = mat
	mm.mesh = box
	mm.instance_count = boxes.size()
	for i in boxes.size():
		mm.set_instance_transform(i, boxes[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Tiles"
	add_child(mmi)

	# A soft key light from upper-left. This is the one thing the browser
	# build fundamentally cannot do (it renders unlit) and the 80% reference
	# — Crafted World's "soft friendly light" — explicitly asks for.
	# GODOT_PORT_ANALYSIS.md §3.1: design it deliberately rather than
	# reproducing flatness we no longer have to accept.
	var sun := DirectionalLight3D.new()
	sun.name = "Key"
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)   # the intro's sky blue
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.68, 0.85)
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)


# ---- the kid -------------------------------------------------------------
func _build_kid() -> void:
	var k = level.spawn.get("kid", {})
	kid = Kid.new(level, float(k.get("x", 4.5)), float(k.get("y", 4)))

	var packed := load("res://data/3d/eeri_v5.glb") as PackedScene
	if packed == null:
		push_warning("eeri_v5.glb missing — falling back to a box")
		var ph := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, Kid.BH, 0.6)
		ph.mesh = bm
		_model = ph
		add_child(_model)
		return

	_model = packed.instantiate()
	add_child(_model)
	# Meshy rigs to real-world metres; the manifest carries the height in
	# TILES and the seam rescales on load (assets/README.md).
	var entry := AssetRegistry.get_model("eeri")
	var want_h := float(entry.get("height", 1.62))
	var measured := _rig_height(_model)
	if measured > 0.01:
		var s := want_h / measured
		_model.scale = Vector3(s, s, s)
	print("kid rig: skeleton span %.3f units -> scaled to %.3f tiles" % [measured, want_h])
	_anim = _find_anim(_model)


## Measure the rig so the manifest's `height` (in TILES) can be applied.
##
## THIS TOOK THREE WRONG ANSWERS, so the reasoning is written down. Probing
## eeri_v5 gives:
##
##   Armature      scale 0.010            <- the cm->m export scale
##     Skeleton3D  24 bones, rest Y 2.116..87.009  (span 84.893, in cm)
##       char1     mesh aabb Y 2.000, skin=true    <- BIND space, unrelated units
##
## So neither AABB is usable. `mesh.get_aabb()` is bind-space (measured 0.020
## once the parent scale was applied — a kid a twentieth of the right size),
## and `MeshInstance3D.get_aabb()` on a skinned mesh is inflated to cover the
## skeleton's possible motion (measured 1.77 against a true ~0.95, leaving him
## 0.87 tiles tall). Both render perfectly at the wrong size, which is the
## exact failure js/assets.js records for rollerbot and token_bolt.
##
## What IS reliable is the skeleton's own rest pose, scaled by the transforms
## above it: 84.893 * 0.01 = 0.849 units. That is foot-bone to head-bone, so
## it under-reads the silhouette slightly (hair sits above the top bone) — an
## honest ~10%, and far better than being out by 2x or 47x.
func _rig_height(root: Node3D) -> float:
	var found := _find_skeleton(root, Transform3D())
	if found.is_empty():
		return 0.0
	var sk: Skeleton3D = found[0]
	var xform: Transform3D = found[1]
	if sk.get_bone_count() == 0:
		return 0.0
	var lo := INF
	var hi := -INF
	for i in sk.get_bone_count():
		var y: float = sk.get_bone_global_rest(i).origin.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	# only the SCALE of the accumulated transform matters for a span
	return (hi - lo) * xform.basis.get_scale().y


func _find_skeleton(n: Node, xform: Transform3D) -> Array:
	var here := xform
	if n is Node3D:
		here = xform * (n as Node3D).transform
	if n is Skeleton3D:
		return [n, here]
	for c in n.get_children():
		var r := _find_skeleton(c, here)
		if not r.is_empty():
			return r
	return []


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f != null:
			return f
	return null


func _play(clip: String) -> void:
	if _anim == null or clip == _clip:
		return
	for lib in _anim.get_animation_library_list():
		var full := clip if String(lib) == "" else "%s/%s" % [lib, clip]
		if _anim.has_animation(full):
			_anim.play(full)
			_clip = clip
			return


# ---- the camera ----------------------------------------------------------
func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Cam"
	# js/camera.js DEFAULT dollies to z 34. The FOV has to be derived from
	# that, not guessed: the browser build shows the play plane at about 57px
	# per world unit, so a 1280-wide frame sees ~22.5 units across and ~12.6
	# down. At z=34 that is 2*atan(6.3/34) ~ 21 degrees. Guessing 32 put the
	# kid at the size of a thumbnail.
	_cam.fov = 21.0
	add_child(_cam)
	_cam_x = kid.x
	_place_camera(true)


func _place_camera(snap: bool) -> void:
	var target := kid.x + kid.facing * 1.6      # the lead, js/camera.js
	if snap:
		_cam_x = target
	else:
		_cam_x = lerpf(_cam_x, target, 0.08)
	var y := maxf(kid.y + 2.6, 5.8)             # DEFAULT.y / DEFAULT.floor
	_cam.position = Vector3(_cam_x, y, 34.0)
	# AXIS-ALIGNED, deliberately. A side-view platformer whose camera is tipped
	# even slightly renders the ground as a receding plane, which costs the
	# player the horizon — js/camera.js says the same thing about roll ("a
	# rolling camera on a side-view platformer costs the player the horizon").
	_cam.rotation = Vector3.ZERO


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(18, 14)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)


# ---- the loop ------------------------------------------------------------
# FIXED TIMESTEP, and it is not a preference. scripts/kid.gd reproduces the
# browser build's semi-implicit Euler frame for frame, and the reach budget
# tests/test_kid.tscn proves is a function of that step. Running it on a
# variable delta makes the jump height depend on the frame rate — which is
# exactly the "a jump a six-year-old cannot make in a room the prover called
# fine" failure the whole port is arranged to avoid.
func _process(delta: float) -> void:
	if kid == null:
		return
	_accum += minf(delta, 0.25)     # never spiral after a stall
	while _accum >= DT:
		_accum -= DT
		kid.step(DT, _read_input())
	_sync_visual()
	_place_camera(false)


func _read_input() -> Dictionary:
	var ax := Input.get_axis("move_left", "move_right")
	return {
		"ax": ax,
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"up_held": Input.is_action_pressed("move_up"),
		"down_held": Input.is_action_pressed("move_down"),
	}


func _sync_visual() -> void:
	if _model == null:
		return
	_model.position = Vector3(kid.x, kid.y, 0.0)
	# The rig is modelled facing +x, so facing -x is a half turn. VERSIONS.md
	# records the trap on the other side of this: the browser build's rig
	# already turns +z->+x, so any EXTRA yaw points him at the camera.
	_model.rotation.y = 0.0 if kid.facing > 0 else PI
	_play(_clip_for(kid.visual_state()))
	if _label:
		_label.text = "%s   %s\n%s     x %.1f  y %.1f" % [
			level.slug, level.display_name, kid.visual_state(), kid.x, kid.y
		]


## js/kid.js CLIP_FOR — the body names a state, the model picks a clip.
func _clip_for(state: String) -> String:
	match state:
		"air": return "jump"
		"climb": return "climb"
		"run": return "run"
		"walk": return "walk"
		_: return "idle"
