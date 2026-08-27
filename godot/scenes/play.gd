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

## THE BUILD STAMP, printed first in the debug line so every screenshot says
## which build produced it.
##
## Added 2026-08-27 after reading a stale build as a result: v20's viewport
## readback was correctly deployed (byte sizes matched) but the phone served a
## cached v19, so the line I needed simply was not there and I nearly took
## that as a finding. GitHub Pages sends Cache-Control: max-age=600 and
## Godot's index.pck / index.wasm carry no ?v= token, which is the exact trap
## the hub's own CLAUDE.md records ("new file paths need ?v= cache tokens from
## day one... the Pages CDN caches responses for ~10 min").
##
## Until the export gains real cache-busting this is the cheap guard: BUMP IT
## WITH EVERY DEPLOY. A screenshot that does not show the expected number is a
## cache, not a result, and must never be reasoned from.
const BUILD := "v39-ipad"

## `?level=` equivalent — CLAUDE.md §5, "debug affordances are features".
## A level you cannot reach in under 30 seconds is not finished.
@export var start_slug := "eeri-1-1"

## Levels run 1 -> 12 in order and one runs into the next (DESIGN §4.1: "No
## world map"). Kept here rather than in LevelRun because advancing is a
## scene concern, not a run-state one.
var _roster: Array = []
var _index := 0
var _advance_t := 0.0

var level: LevelData
var kid: Kid
var robots: Array[Robot] = []
var stomps := 0
var hits := 0

var _robot_nodes: Array[Node3D] = []
var _robot_tells: Array[Node3D] = []
var _robot_legs: Array = []

## foot | mounting | riding | dismounting — js/main.js's four modes.
var mode := "foot"
var machine: Machine
var _machine_node: Node3D
var _seat_node: Node3D
## The seat as an OFFSET from the machine's origin, measured once from the
## model. See _seat_world() for why this is not read live.
var _seat_offset := Vector2(-0.1, 1.25)
var run: LevelRun
var bank: Bank
var wall: Pieces.Wall
var girder: Pieces.Girder
var _wall_node: MultiMeshInstance3D
var _girder_node: MeshInstance3D
var _diorama: Diorama
var _dressing: Dressing
var vents: Array[SteamVent] = []
var _vent_nodes: Array[Node3D] = []
var hoists: Array[Hoist] = []
var _hoist_nodes: Array[Node3D] = []
var _pickup_node: MultiMeshInstance3D
var _golden_node: MultiMeshInstance3D
var _blueprint_node: Node3D
var _bank_node: MultiMeshInstance3D
var _boom_node: Node3D
var _stick_node: Node3D
var _bucket_node: Node3D
var _move_t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _mid := Vector2.ZERO
const MOUNT_TIME := 0.42
## The trip down a pipe, and the cooldown that stops the FAR mouth reading as
## a fresh entrance the instant you arrive and sending you straight back.
const PIPE_T := 0.55
var _piping = null
var _pipe_t := 0.0
var _pipe_cool := 0.0

var _model: Node3D
var _anim: AnimationPlayer
var _clip := ""
var _accum := 0.0
var _cam: Camera3D
var _cam_x := 0.0
var _shell: Shell
var _running := false


## THE STAGE — the SubViewport all 3D goes into, 2026-08-27 ("Fable 5").
##
## THE PATTERN IS PIRITORI'S, AND PIRITORI RENDERS ON THE OWNER'S PHONE.
## Twelve direct-render suspects died with measurements (handoff §14): the
## phone clears Eeri's 3D target to exactly the Environment colour, submits
## 38 draw calls, rasterises nothing, and errors nowhere — while its 2D
## pipeline works perfectly, on this project and both sibling ports.
##
## piritori-eden draws every 3D thing it has inside a SubViewport under a
## SubViewportContainer (presenter_3d.gd, battle_stage_3d.gd): the 3D pass
## renders offscreen and the 2D pipeline — the one path proven good on this
## device — composites the result. Eeri now does the same. Toko Drop renders
## direct and happens to survive; between "direct, broken here" and
## "offscreen, proven here", the port takes the proven one.
##
## Piritori's own load-bearing trap, copied with its comment: own_world_3d
## must be set BEFORE anything is added, "or they are added to a world this
## viewport is about to stop using".
var _stage: SubViewport


func _build_stage() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StageLayer"
	layer.layer = 0   # under the Shell (layer 10)
	add_child(layer)
	var svc := SubViewportContainer.new()
	svc.name = "StageContainer"
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(svc)
	_stage = SubViewport.new()
	_stage.name = "Stage"
	_stage.own_world_3d = true
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_stage)


func _ready() -> void:
	# FIRST, before any scene building: a shader that fails to compile does so
	# while the tiles/diorama/kid are being built below, and the hook has to
	# already be listening to catch it.
	if OS.has_feature("web"):
		_install_js_log_hook()

	_build_stage()

	var slug := start_slug
	# A deep link beats a rebuild. Accepts --level=eeri-1-2 or ?level= on web.
	for a in OS.get_cmdline_args():
		if a.begins_with("--level="):
			slug = a.substr(8)
	if OS.has_feature("web"):
		var q := _web_query_level()
		if q != "":
			slug = q

	var idx := LevelData.load_index()
	_roster = idx.get("levels", [])
	for i in _roster.size():
		if String(_roster[i].get("slug", "")) == slug:
			_index = i
			break

	level = LevelData.load_slug(slug)
	if level == null:
		push_error("could not load level %s" % slug)
		return

	_build_tiles()
	_build_diorama()
	_build_kid()
	_build_robots()
	_build_machine()
	_build_bank()
	_build_pieces()
	_build_pickups()
	_build_hoists()
	_build_vents()
	_build_camera()
	_build_shell()


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
## THE GROUND, ported properly from js/level.js buildMeshes().
##
## THIS WAS THE "dirty pile" the owner reported on the iPad. The port drew
## every solid tile as ONE flat brown box, which reads as slabs pasted over
## the painted set. The browser build has never done that: it bands the earth
## by DEPTH, caps every standable edge with a GRASS LIP, and lays deep earth
## below the playable band so the eye has somewhere to go.
##
## Three things ported here, all from js/level.js:
##
##   STRATA -- four colours per world (EARTH_FOR), "darker and cooler with
##     depth... cy 0 is the deepest of the band and cy 3 the topsoil". Carried
##     per instance rather than per material so it is still one draw call.
##   THE GRASS LIP -- js/level.js line 440 exactly: a 0.14-tall strip 1.66
##     deep, sat at cy + 0.94. ART_BRIEF SS3.2 is blunt about why it matters:
##     without it "the gameplay lane is a hairline" -- it is what says STAND
##     HERE, not decoration.
##   DEEP EARTH -- three darkening bands under the playfield, so the cut has
##     a bottom instead of ending in nothing.
##
## Per-world tinting is real: the same brown at night is wrong, which is why
## nightshift mixes its earth and its lip toward INK.
const PAL_EARTH := [Color("#6e4c32"), Color("#8a6242"), Color("#a87c52"), Color("#c49a66")]
const PAL_GREEN := Color("#3cc85a")
const PAL_INK := Color("#17130f")
const PAL_STEEL := [Color("#5f7080"), Color("#7a8a9a"), Color("#9fb0bd")]
const PAL_GREEN_DK := Color("#2a8f40")


static func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## EARTH_FOR from js/level.js -- four bands, deepest first.
func _strata_for(world: String) -> Array:
	var E := PAL_EARTH
	var mid := _mix(E[1], E[0], 0.5)
	match world:
		"pipeworks":
			return [_mix(E[0], PAL_STEEL[0], 0.22), _mix(mid, PAL_STEEL[0], 0.2),
				_mix(E[1], PAL_STEEL[1], 0.16), _mix(E[2], PAL_STEEL[2], 0.14)]
		"grove":
			return [_mix(E[0], PAL_INK, 0.22), _mix(mid, PAL_INK, 0.16),
				_mix(E[1], PAL_GREEN_DK, 0.12), _mix(E[2], PAL_GREEN_DK, 0.28)]
		"nightshift":
			return [_mix(E[0], PAL_INK, 0.55), _mix(mid, PAL_INK, 0.48),
				_mix(E[1], PAL_INK, 0.42), _mix(E[2], PAL_INK, 0.36)]
		_:
			return [E[0], mid, E[1], E[2]]


## LIP_FOR from js/level.js -- a daylight green strip is wrong at night.
func _lip_for(world: String) -> Color:
	match world:
		"pipeworks": return _mix(PAL_GREEN, PAL_STEEL[2], 0.2)
		"grove": return _mix(PAL_GREEN, PAL_GREEN_DK, 0.45)
		"nightshift": return _mix(PAL_GREEN, PAL_INK, 0.45)
		_: return PAL_GREEN


## A DETAIL MAP MULTIPLIED ONTO A PALETTE COLOUR, never a colour source --
## assets/manifest.json is explicit about this: "Greyscale detail maps, each
## MULTIPLIED onto a palette colour... Crafted World is a KIT of materials, not
## one material: card is the ground, felt is the grass, painted balsa is
## everything the cast is built from."
func _craft_material(tint: Color, tex_name: String, per_instance := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var e: Dictionary = AssetRegistry.manifest.get("textures", {}).get(tex_name, {})
	if String(e.get("status", "")) == "live":
		var tex := load("res://data/" + String(e.get("file", ""))) as Texture2D
		if tex != null:
			mat.albedo_texture = tex
			mat.uv1_scale = Vector3.ONE
	mat.albedo_color = tint
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# The strata arrive as MultiMesh instance colours, and a StandardMaterial3D
	# ignores those unless told to read them -- without this the cut renders in
	# bare white, one flat pale slab, the exact fault being fixed.
	if per_instance:
		mat.vertex_color_use_as_albedo = true
	return mat


func _build_tiles() -> void:
	var world := Diorama.world_for(level.index)
	var strata := _strata_for(world)

	# EACH BAND NAMES ITS OWN SECTION. js/level.js: "a cut through card also
	# shows that the layers are not all the same card." Indexed by WORLD Y, not
	# by depth below the surface -- "cy 0 is the deepest of the band and cy 3
	# the topsoil" -- so a raised platform is topsoil, which is what it is.
	var section := ["packed", "gritty", "strata", "topsoil"]
	var by_band := [[], [], [], []]
	var lips := []          # [row, x0, x1] runs of standable top
	for r in level.h:
		var run_start := -1
		for c in level.w:
			var solid: bool = level.solid_cell(c, r)
			if solid:
				by_band[clampi(r, 0, 3)].append(Vector2i(c, r))
			# A LIP ONLY WHERE YOU COULD STAND -- the cell above must be open.
			# Merged into RUNS rather than emitted per tile, because the fringe
			# tiles at its own aspect along the run: per-tile would compress the
			# tufts, and "a fringe reads as grass only while its tufts are the
			# size grass tufts are."
			var top: bool = solid and not level.solid_cell(c, r + 1)
			if top and run_start < 0:
				run_start = c
			elif not top and run_start >= 0:
				lips.append([r, run_start, c])
				run_start = -1
		if run_start >= 0:
			lips.append([r, run_start, level.w])

	for band in 4:
		var cols: Array = by_band[band]
		if cols.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		box.material = _craft_material(strata[band], section[band])
		mm.mesh = box
		mm.instance_count = cols.size()
		var i := 0
		for cell in cols:
			# The BAND picks the material; the CELL keeps its own world y, so a
			# platform at y 8 still stands at y 8 while wearing topsoil.
			mm.set_instance_transform(i, Transform3D(Basis(),
				Vector3(float(cell.x) + 0.5, float(cell.y) + 0.5, 0.0)))
			i += 1
		var bi := MultiMeshInstance3D.new()
		bi.multimesh = mm
		bi.name = "Earth_" + section[band]
		_stage.add_child(bi)

	# THE DEEP EARTH, js/level.js DEEP -- three darkening bands under the
	# playfield so the cut has a bottom instead of stopping at the last tile.
	for b in [[-1.6, 0.0, 0.12], [-4.2, -1.6, 0.26], [-10.0, -4.2, 0.40]]:
		var y0: float = b[0]
		var y1: float = b[1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(136.0, y1 - y0, 1.6)
		mi.mesh = bm
		var dm := _craft_material(_mix(strata[0], PAL_INK, float(b[2])), "packed")
		# One card tile per four world units; a single sheet stretched across
		# 136 units smears the grain into a haze.
		dm.uv1_scale = Vector3(34.0, (y1 - y0) / 4.0, 1.0)
		mi.material_override = dm
		mi.position = Vector3(48.0, (y0 + y1) * 0.5, 0.0)
		mi.name = "Deep"
		_stage.add_child(mi)

	# THE GRASS LIP, and it is THREE things, not a green bar. js/level.js:
	# "the lip is where the game is played; without the shadow it was a 0.14
	# hairline on a flat wall." So: the felt strip, a hard shadow under it, and
	# the felt's own cut edge -- "a flat green bar with a hard straight top is
	# the last machine-perfect thing in the lane, and it is the line the
	# player's feet are on."
	var lip_c := _lip_for(world)
	var shade_c := _mix(strata[0], PAL_INK, 0.45)
	const FH := 0.42
	for run in lips:
		var r0: float = float(run[0])
		var w: float = float(run[2]) - float(run[1])
		var cx: float = float(run[1]) + w * 0.5

		var lip := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(w, 0.14, 1.66)
		lip.mesh = lb
		lip.material_override = _craft_material(lip_c, "felt")   # grass is felt
		lip.position = Vector3(cx, r0 + 0.94, 0.0)
		lip.name = "Lip"
		_stage.add_child(lip)

		var sh := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(w, 0.22, 1.68)
		sh.mesh = sb
		sh.material_override = _craft_material(shade_c, "flute")
		sh.position = Vector3(cx, r0 + 0.76, 0.0)
		sh.name = "LipShade"
		_stage.add_child(sh)

		# The fringe tiles at the strip's OWN aspect, never at a round number
		# of repeats per run -- that is what compressed the tufts into a
		# regular scalloped chain.
		var fr := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w, FH)
		fr.mesh = q
		var fm := _craft_material(Color.WHITE, "fringe")
		# cutMat in js/craft.js: white, alphaTest 0.5, DoubleSide. The cutout
		# carries its own colour, so it is not tinted.
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.alpha_scissor_threshold = 0.5
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.uv1_scale = Vector3(maxf(1.0, roundf(w / (FH * 5.6))), 1.0, 1.0)
		fr.material_override = fm
		fr.position = Vector3(cx, r0 + 1.12, 0.85)
		fr.name = "Fringe"
		_stage.add_child(fr)


	# A soft key light from upper-left. This is the one thing the browser
	# build fundamentally cannot do (it renders unlit) and the 80% reference
	# — Crafted World's "soft friendly light" — explicitly asks for.
	# GODOT_PORT_ANALYSIS.md §3.1: design it deliberately rather than
	# reproducing flatness we no longer have to accept.
	var sun := DirectionalLight3D.new()
	sun.name = "Key"
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	# Tuned against the PAINTED set, not in isolation: the lanes are unshaded
	# and carry their own light, so the actors only need enough to sit in the
	# scene and throw a contact shadow.
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.96, 0.88)
	# NO CAST SHADOW MAPS. ART_BRIEF.md SS3.4 says it outright -- "one soft rig,
	# no drama: a hemisphere fill + one directional key (upper-left), NO CAST
	# SHADOW MAPS" -- and its own 2D/3D table repeats it: "Drop shadows | 2D
	# blob under each character | the landing aid; no shadow maps".
	#
	# This port had shadow_enabled = true from the first lighting pass, which
	# was a canon violation nobody had caught: GODOT_PORT_ANALYSIS SS3.1 argued
	# for contact shadows as the thing Godot could finally add, but that
	# document creates no canon and ART_BRIEF outranks it.
	#
	# It is also, on the evidence, the black screen. The owner's phone reports
	# maxVary=15 (a PowerVR D-Series; desktop reports 30) while submitting 37
	# draw calls a frame and displaying nothing -- the signature of a spatial
	# shader that will not LINK because it exceeds the varying limit, with 2D
	# surviving because canvas shaders use far fewer. Shadow mapping is the
	# largest varying consumer in Godot's compatibility spatial shader.
	#
	# Both reasons point the same way, so this is not a mobile-only workaround
	# hidden behind a feature check: the shadows should never have been on.
	sun.shadow_enabled = false
	_stage.add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)   # the intro's sky blue
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.68, 0.85)
	e.ambient_light_energy = 0.30
	env.environment = e
	_stage.add_child(env)


# ---- the diorama ---------------------------------------------------------
func _build_diorama() -> void:
	if _diorama != null:
		_diorama.queue_free()
	_diorama = Diorama.new()
	_diorama.name = "Diorama"
	_stage.add_child(_diorama)
	var world := Diorama.world_for(level.index)
	var n := _diorama.build(world)
	if n == 0:
		push_warning("no layer art mounted for '%s' — the room will be greybox" % world)

	# The PLAYFIELD DRESSING: the layer between the painted backdrop and the
	# play lane. It is what stops worlds 2-4 reading as world 1 with different
	# wallpaper. Visual only — collision never comes from artwork.
	if _dressing != null:
		_dressing.queue_free()
	_dressing = Dressing.new()
	_dressing.name = "Dressing"
	_stage.add_child(_dressing)
	_dressing.build(world, level.index)


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
		_stage.add_child(_model)
		return

	_model = packed.instantiate()
	_stage.add_child(_model)
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


# ---- the small machines --------------------------------------------------
# Greybox bodies for now: the real models are boltbot/hopper/bucket/rollerbot
# in the manifest and all four are still "placeholder" there, so there is
# nothing to load yet. Sized from the ported hitboxes so what you SEE is what
# you can stomp — a body drawn bigger than its hitbox is the cheapest way to
# make a fair game feel unfair.
func _build_robots() -> void:
	for span in level.robots:
		var r := Robot.new(level, span)
		robots.append(r)

		# The code-drawn body, ported shape-for-shape from js/robots.js. These
		# are "placeholder" in the manifest, which means the browser build
		# draws them in code too — so parity is the CODE, not the unapproved
		# .glb sitting beside it.
		var built := Craft.robot(r.kind)
		var node: Node3D = built["root"]
		_stage.add_child(node)
		_robot_nodes.append(node)
		_robot_tells.append(built["tell"])
		_robot_legs.append(built["legs"])


func _step_robots(dt: float) -> void:
	var target := {"x": kid.x, "y": kid.y, "grounded": kid.grounded}
	for r in robots:
		r.step(dt, target)

	# ---- resolving a touch, in js/main.js's order -----------------------
	# THE STOMP BEATS THE LUNGE. If he is coming down on it, it does not get
	# to have hit him — otherwise a skitter caught mid-lunge both kills you
	# and dies, in the same frame, and which one you saw is a coin flip.
	for r in robots:
		if r.dead:
			continue
		if r.stomped_by(kid.x, kid.y, Kid.HW, kid.vy):
			kid.bounce()
			stomps += 1
			Audio.play("stomp")
			punch(0.4)
		elif not r.stompable and r.landed_on(kid.x, kid.y, Kid.HW, kid.vy):
			# too flat to stomp: it shrugs you off without dying, and cannot
			# also hit you for it this frame
			kid.bounce()
			r.shrug()
		elif r.hits(kid.x, kid.y, Kid.HW, Kid.BH) and kid.mercy_t <= 0.0:
			if mode == "riding":
				# THE YOSHI RULE (DESIGN §3): a hit ends the RIDE early and
				# drops him back on foot. It costs the ride, never the run.
				_begin_dismount(true)
				hits += 1
			else:
				# DESIGN §4.1: knockback and mercy frames are the WHOLE damage
				# model. He is never hurt, never dies, has no health bar.
				kid.struck(r.x)
				hits += 1


func _sync_machine() -> void:
	if machine == null or _machine_node == null:
		return
	_machine_node.position = Vector3(machine.x, machine.y, 0.0)
	_machine_node.rotation.y = 0.0 if machine.face > 0 else PI


func _sync_robots() -> void:
	for i in robots.size():
		var r := robots[i]
		var n := _robot_nodes[i]
		n.visible = not r.dead
		if r.dead:
			continue
		n.position = Vector3(r.x, r.y, 0.0)
		n.rotation.y = 0.0 if r.face > 0 else PI
		# the crouch is the hopper's tell, and it is drawn
		n.scale.y = 0.78 if r.state == "crouch" else 1.0
		# THE TELL BRIGHTENS through notice and wind. A telegraph you cannot
		# see is not a telegraph.
		# THE LEGS SCUTTLE. js/robots.js animates the code-built parts directly —
		# there are no clips, because these models are `placeholder`. A robot
		# that slides rather than walks reads as a decal, and the patrol is the
		# state you see most of.
		if i < _robot_legs.size():
			var legs: Array = _robot_legs[i]
			match r.kind:
				"roller":
					# the drum ROLLS, it does not step
					for leg in legs:
						(leg as Node3D).rotation.y += float(r.face) * 6.0 * DT
				"bucket":
					if r.state == "chase":
						for li in legs.size():
							(legs[li] as Node3D).position.y = 0.09 + sin(r.t * 18.0 + float(li) * PI) * 0.04
				_:
					if r.state == "patrol":
						for li in legs.size():
							(legs[li] as Node3D).position.y = 0.12 + sin(r.t * 14.0 + float(li) * 1.6) * 0.03
		if i < _robot_tells.size():
			var hot: bool = r.state in ["notice", "wind", "wake", "crouch"]
			var m := (_robot_tells[i] as MeshInstance3D).mesh.material as StandardMaterial3D
			if m:
				var k: float = (sin(r.t * 26.0) * 0.5 + 0.5) if hot else 0.0
				m.albedo_color = Craft.HAZARD.lerp(Color.WHITE, k * 0.7)


# ---- the ride ------------------------------------------------------------
func _build_machine() -> void:
	# WHICH MACHINE THIS ROOM PARKS IS DATA, NOT A GUESS, and the spawn key IS
	# THE TYPE — `spawn.excavator`, `spawn.crane`, `spawn.skidder`,
	# `spawn.loader`. Reading `spawn.excavator` unconditionally therefore did
	# two wrong things at once: worlds 3 and 4 got a yellow digger instead of
	# their own skidder and loader, and every CRANE level got no machine at
	# all, because there is no `spawn.excavator` in one. Four of the twelve
	# rooms had nothing to ride and nothing said so.
	var mkind := "excavator"
	if level.machines.size() > 0:
		mkind = String(level.machines[0].get("type", "excavator"))
	elif level.wall != null:
		mkind = "crane"

	var spawns = level.spawn.get(mkind, null)
	if spawns == null:
		push_warning("level %s declares a %s but has no spawn for one" % [level.slug, mkind])
		return
	machine = Machine.new(level, float(spawns.get("x", 0)), float(spawns.get("y", 0)), mkind)

	# Skidder and loader have NO live .glb — they are code-drawn in js/rigs.js
	# and ported to scripts/rigs.gd against the SAME node contract, so nothing
	# downstream can tell which kind of body it got.
	var built := Rigs.build(mkind)
	if not built.is_empty():
		_machine_node = built["root"]
		_stage.add_child(_machine_node)
		_boom_node = built["boom"]
		_stick_node = built["stick"]
		_bucket_node = built["bucket"]
		_seat_node = _find_named(_machine_node, "seat")
		_measure_seat()
		return

	var packed := load("res://data/3d/excavator_v1.glb") as PackedScene
	if packed != null:
		_machine_node = packed.instantiate()
		_stage.add_child(_machine_node)
		# THE SEAT IS A DECLARED NODE, not a guess. assets/README.md contracts
		# `seat` on every ride machine precisely so the rider is placed by the
		# ART rather than by a number in game code — and it is what keeps Eeri
		# visible in an open cab (the Yoshi rule, ART_BRIEF §3.6) when the
		# model is replaced by one with different proportions. The fallback
		# offset in machine.gd is only for the greybox.
		_seat_node = _find_named(_machine_node, "seat")
		# The arm is a rigid NODE hierarchy the game rotates — house/boom/
		# stick/bucket (assets/README.md). Driving named nodes is the whole
		# reason compress-models.mjs refuses `gltf-transform optimize`: its
		# join/flatten would merge them and leave one welded lump.
		_boom_node = _find_named(_machine_node, "boom")
		_stick_node = _find_named(_machine_node, "stick")
		_bucket_node = _find_named(_machine_node, "bucket")
		if _seat_node == null:
			push_warning("%s has no `seat` node — falling back to the offset" % mkind)
		else:
			_measure_seat()
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(machine.hw * 2.0, machine.h, 1.4)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.72, 0.12)      # MACHINE yellow
		bm.material = mat
		mi.mesh = bm
		_machine_node = mi
		_stage.add_child(_machine_node)


## Measure the seat ONCE, walking the transform chain rather than reading
## global_position — which is not flushed on the frame a node is added, the
## same trap the rig-scale measurement paid for. The model decides where the
## seat is; only the per-frame lookup is gone.
func _measure_seat() -> void:
	if _seat_node == null or _machine_node == null:
		return
	var t := Transform3D()
	var n: Node = _seat_node
	var chain: Array[Node] = []
	while n != null and n != _machine_node:
		chain.push_front(n)
		n = n.get_parent()
	for c in chain:
		if c is Node3D:
			t = t * (c as Node3D).transform
	_seat_offset = Vector2(t.origin.x, t.origin.y)


func _find_named(n: Node, want: String) -> Node3D:
	if n.name == want and n is Node3D:
		return n
	for c in n.get_children():
		var f := _find_named(c, want)
		if f != null:
			return f
	return null


## Where the rider actually sits.
##
## COMPUTED FROM THE MACHINE'S LOGICAL POSITION, never read off the rendered
## node — and that distinction is a bug this already paid for. The logic runs
## on a fixed timestep inside _process's accumulator loop; the scene graph is
## only synced ONCE per frame afterwards. Reading _seat_node.global_position
## during the loop therefore returns last frame's place, so while the machine
## drove away the rider stayed pinned where it used to be, the camera followed
## the rider, and the excavator silently left the screen.
##
## The model still decides WHERE the seat is — the offset is measured from its
## declared `seat` node at build time (assets/README.md contracts it). Only
## the per-frame lookup is gone.
func _seat_world() -> Vector2:
	if machine == null:
		return Vector2.ZERO
	return Vector2(machine.x + _seat_offset.x * machine.face, machine.y + _seat_offset.y)


func _step_ride(dt: float, input: Dictionary) -> void:
	if machine == null:
		return
	var act: bool = input.get("action_pressed", false)

	match mode:
		"foot":
			# Board at a MARKED POINT only, never merely near a machine
			# (DESIGN §2). The action press is consumed by the transition.
			if act and machine.can_mount(kid.x, kid.y, kid.grounded):
				_begin_mount()
			machine.step(dt, 0.0)
		"mounting":
			_move_t += dt
			machine.step(dt, 0.0)
			if _move_t >= MOUNT_TIME:
				mode = "riding"
		"riding":
			var drive := float(input.get("ax", 0.0))
			machine.step(dt, drive)
			var seat := _seat_world()
			kid.x = seat.x
			kid.y = seat.y
			kid.vx = 0.0
			kid.vy = 0.0
			if act:
				_begin_dismount(false)
		"dismounting":
			_move_t += dt
			machine.step(dt, 0.0)
			var k: float = clampf(_move_t / MOUNT_TIME, 0.0, 1.0)
			var p := _bezier(k)
			kid.x = p.x
			kid.y = p.y
			if k >= 1.0:
				kid.vx = 0.0
				kid.vy = 0.0
				mode = "foot"


func _begin_mount() -> void:
	mode = "mounting"
	_move_t = 0.0
	_from = Vector2(kid.x, kid.y)
	machine.tame()          # the threat becomes the tool (ART_BRIEF §1.2)
	Audio.play("mount")


## thrown = struck out of the cab. THE YOSHI RULE (DESIGN §3): a hazard takes
## the RIDE, not the run — so it is the same move, thrown further and higher,
## and a ride becomes a thing you can LOSE rather than fail.
func _begin_dismount(thrown: bool) -> void:
	mode = "dismounting"
	_move_t = 0.0
	_from = _seat_world()
	var gx: float = machine.x - machine.face * (4.2 if thrown else 2.6)
	var gy: float = maxf(level.ground_top(gx, machine.y + 2.0), machine.y)
	_to = Vector2(gx, gy)
	_mid = _from.lerp(_to, 0.5)
	_mid.y = maxf(_from.y, _to.y) + (2.8 if thrown else 1.4)
	Audio.play("dismount")
	if thrown:
		kid.mercy_t = 1.3


func _bezier(k: float) -> Vector2:
	var a := _from.lerp(_mid, k)
	var b := _mid.lerp(_to, k)
	return a.lerp(b, k)


# ---- the bank: the lock the ride opens -----------------------------------
func _build_bank() -> void:
	if level.bank == null:
		return
	bank = Bank.new(level, level.bank)
	_bank_node = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.30, 0.19)     # loose dirt, darker than tile
	mat.roughness = 1.0
	box.material = mat
	mm.mesh = box
	_bank_node.multimesh = mm
	_stage.add_child(_bank_node)
	_sync_bank()
	_sync_pieces()


func _step_bank(dt: float, input: Dictionary) -> void:
	if bank == null:
		return
	# Holding DOWN while riding is the verb. Nothing else to aim.
	var want: bool = mode == "riding" and input.get("down_held", false)
	bank.step(dt, machine.x if machine != null else -999.0, want)
	if bank.bit:
		Audio.play("splat")
		punch(1.5 if bank.cleared else 0.85)


func _sync_bank() -> void:
	if bank == null or _bank_node == null:
		return
	var mm := _bank_node.multimesh
	var cells: Array[Transform3D] = []
	for r in bank.remaining:
		for c in range(int(bank.c0), int(bank.c1) + 1):
			cells.append(Transform3D(Basis(), Vector3(c + 0.5, bank.cy0 + r + 0.5, 0.0)))
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, cells[i])
	# ARMED LOOKS DIFFERENT. A thing you can act on has to read as actable
	# before anything is pressed — the indicator the owner found missing.
	var mat := _bank_node.multimesh.mesh.material as StandardMaterial3D
	if mat:
		if bank.armed:
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			mat.emission_enabled = true
			mat.emission = Color(0.45, 0.32, 0.10)
			mat.emission_energy_multiplier = 0.25 + 0.35 * pulse
		else:
			mat.emission_enabled = false


func _sync_arm() -> void:
	if bank == null:
		return
	# Rotating the DECLARED nodes, about z, exactly as js/excavator.js does.
	if _boom_node:
		_boom_node.rotation.z = bank.boom
	if _stick_node:
		_stick_node.rotation.z = bank.stick
	if _bucket_node:
		_bucket_node.rotation.z = bank.bucket


# ---- what makes it a level ----------------------------------------------
func _build_pickups() -> void:
	run = LevelRun.new(level)
	_pickup_node = _mm_node(Color(0.90, 0.78, 0.25), 0.26)   # bolts
	_golden_node = _mm_node(Color(1.0, 0.86, 0.25), 0.40)    # golden bolts
	_build_blueprint()
	_sync_pickups()
	_sync_hoists()
	_sync_vents()


## THE BLUEPRINT — a ROLLED SHEET, and the shape is the point. DESIGN §6.3
## requires every token to be unmistakable from a bolt at 32px, and this port
## had been drawing it as NOTHING AT ALL: the pickup was collected by walking
## over empty air. A pale roll, a machine-yellow band and one blue end.
func _build_blueprint() -> void:
	if level.blueprint == null or run == null:
		return
	var p := run.cell_to_xy(level.blueprint)
	_blueprint_node = Node3D.new()
	_blueprint_node.position = Vector3(p.x, p.y, 0.0)
	_stage.add_child(_blueprint_node)

	var roll := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.17
	rm.bottom_radius = 0.17
	rm.height = 0.72
	rm.material = Craft.mat(Color("eaf2fb"))
	roll.mesh = rm
	roll.rotation.z = PI / 2
	_blueprint_node.add_child(roll)

	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.14
	bm.outer_radius = 0.24
	bm.material = Craft.mat(Craft.MACHINE)
	band.mesh = bm
	band.rotation.z = PI / 2
	_blueprint_node.add_child(band)

	var edge := MeshInstance3D.new()
	var em := CylinderMesh.new()
	em.top_radius = 0.175
	em.bottom_radius = 0.175
	em.height = 0.08
	em.material = Craft.mat(Color("3f6ea8"))
	edge.mesh = em
	edge.rotation.z = PI / 2
	edge.position.x = 0.34
	_blueprint_node.add_child(edge)


func _mm_node(col: Color, size: float) -> MultiMeshInstance3D:
	var n := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var m := BoxMesh.new()
	m.size = Vector3(size, size, size)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.5
	m.material = mat
	mm.mesh = m
	n.multimesh = mm
	_stage.add_child(n)
	return n


func _sync_pickups() -> void:
	if run == null:
		return
	var spin := Time.get_ticks_msec() * 0.002
	_fill(_pickup_node, level.bolts, func(i): return run.bolt_alive(i), spin)
	_fill(_golden_node, level.golden, func(i): return run.golden_alive(i), spin * 0.7)
	if _blueprint_node != null:
		_blueprint_node.visible = not run.blueprint_got
		_blueprint_node.rotation.y = spin * 0.5


func _fill(node: MultiMeshInstance3D, src: Array, alive: Callable, spin: float) -> void:
	var out: Array[Transform3D] = []
	for i in src.size():
		if not alive.call(i):
			continue
		var p := run.cell_to_xy(src[i])
		var b := Basis(Vector3.UP, spin)
		out.append(Transform3D(b, Vector3(p.x, p.y, 0.0)))
	node.multimesh.instance_count = out.size()
	for i in out.size():
		node.multimesh.set_instance_transform(i, out[i])


# ---- the hoist: a floor that is not a tile --------------------------------
func _build_hoists() -> void:
	for def in level.hoists:
		var h := Hoist.new(def)
		hoists.append(h)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		# The deck is drawn so its EDGE can be read: a platform whose extent is
		# ambiguous is a platform you step off by accident.
		bm.size = Vector3(h.hw * 2.0, 0.28, 1.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.72, 0.74)
		mat.roughness = 0.9
		bm.material = mat
		mi.mesh = bm
		_stage.add_child(mi)
		_hoist_nodes.append(mi)
	kid.platforms = hoists


func _step_hoists(dt: float) -> void:
	for h in hoists:
		h.step(dt)


func _sync_hoists() -> void:
	for i in hoists.size():
		var h := hoists[i]
		# y is the TOP surface, so the deck box hangs half its thickness below
		_hoist_nodes[i].position = Vector3(h.x, h.y - 0.14, 0.0)


# ---- the locks: the wall and the girder ----------------------------------
func _build_pieces() -> void:
	if level.wall != null:
		wall = Pieces.Wall.new(level.wall)
		_wall_node = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.28, 0.22)      # brick
		mat.roughness = 1.0
		box.material = mat
		mm.mesh = box
		_wall_node.multimesh = mm
		_stage.add_child(_wall_node)

	if level.girder != null:
		girder = Pieces.Girder.new(level.girder)
		_girder_node = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(maxf(girder.span_len, 2.0), 0.5, 1.0)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.86, 0.62, 0.14)       # MACHINE yellow steel
		gm.roughness = 0.85
		bm.material = gm
		_girder_node.mesh = bm
		_stage.add_child(_girder_node)
	_sync_pieces()


func _step_pieces(dt: float, input: Dictionary) -> void:
	if machine == null:
		return
	machine.step_swing(dt)

	# ---- the wall: the crane's job ---------------------------------------
	if wall != null and not wall.cleared and mode == "riding":
		# Holding the verb heaves the ball. The WIND-UP is the telegraph and
		# the ball only bites partway into the strike.
		if input.get("down_held", false):
			machine.heave()
		if machine.striking() and not machine.struck_this_swing:
			if wall.in_reach(machine.x):
				machine.struck_this_swing = true
				Audio.play("thunk")
				punch(1.2)
				if wall.strike() and wall.cleared:
					# THE MAP IS A FACT. Clearing it edits the grid, so
					# collision and what is drawn cannot disagree.
					for r in wall.rows:
						level.clear_row(int(wall.c0), int(wall.c1), int(wall.cy0) + r)

	# ---- the girder: the same gesture, the other way round ----------------
	if girder != null and mode == "riding" and input.get("action_held", false):
		if not girder.slung and not girder.seated:
			if girder.sling(machine.x):
				machine.carrying = true
				Audio.play("clank")
		elif girder.can_seat(machine.x):
			if girder.seat(machine.x):
				machine.carrying = false
				Audio.play("thunk")
				# the span is walked on: it becomes real floor
				level.fill_row(int(girder.gap_c0), int(girder.gap_c1), int(girder.gap_cy))
				_rebuild_tiles()


func _sync_pieces() -> void:
	if wall != null and _wall_node != null:
		var cells: Array[Transform3D] = []
		if not wall.cleared:
			for r in wall.rows:
				for c in range(int(wall.c0), int(wall.c1) + 1):
					cells.append(Transform3D(Basis(), Vector3(c + 0.5, wall.cy0 + r + 0.5, 0.0)))
		_wall_node.multimesh.instance_count = cells.size()
		for i in cells.size():
			_wall_node.multimesh.set_instance_transform(i, cells[i])
		# A CRACKED WALL IS STILL A WALL — it blocks exactly as much. The
		# change is drawn, not removed, so the second swing is worth taking.
		var wm := _wall_node.multimesh.mesh.material as StandardMaterial3D
		if wm:
			wm.albedo_color = Color(0.50, 0.24, 0.19) if wall.state() == 1 else Color(0.62, 0.28, 0.22)

	if girder != null and _girder_node != null:
		match girder.state():
			0:
				_girder_node.position = Vector3(girder.stack_x, level.ground_top(girder.stack_x, 8.0) + 0.25, 0.0)
			1:
				# slung from the machine's arm
				_girder_node.position = Vector3(machine.x + machine.face * 1.6, machine.y + 1.4, 0.0)
			2:
				_girder_node.position = Vector3(girder.gap_centre(), girder.gap_cy + 0.75, 0.0)


## The girder seats a real row of floor, so the tile mesh has to be rebuilt.
func _rebuild_tiles() -> void:
	for c in get_children():
		if c is MultiMeshInstance3D and c.name == "Tiles":
			c.queue_free()
	_build_tiles()


# ---- the pipes -----------------------------------------------------------
# A pair of places plus the trip between them. You have to be STANDING at a
# mouth — a pipe you fall into by accident is a pipe that takes the level away
# from you.
func _pipe_here():
	if not kid.grounded or _piping != null or _pipe_cool > 0.0:
		return null
	for q in level.pipes:
		for pair in [[q.get("a"), q.get("b")], [q.get("b"), q.get("a")]]:
			var m = pair[0]
			if m == null:
				continue
			if absf(kid.x - (float(m.get("c", 0)) + 0.5)) < 0.7 					and absf(kid.y - float(m.get("cy", 0))) < 0.6:
				return {"from": m, "to": pair[1]}
	return null


func _step_pipes(dt: float, input: Dictionary) -> void:
	if _pipe_cool > 0.0:
		_pipe_cool -= dt
	if _piping != null:
		_pipe_t += dt
		if _pipe_t >= PIPE_T:
			var to = _piping["to"]
			kid.x = float(to.get("c", 0)) + 0.5
			kid.y = float(to.get("cy", 0))
			kid.vx = 0.0
			kid.vy = 0.0
			_piping = null
			_pipe_cool = 0.5
			Audio.play("thunk", 1.2)
		return
	if mode != "foot" or not input.get("down_held", false):
		return
	var here = _pipe_here()
	if here != null:
		_piping = here
		_pipe_t = 0.0
		Audio.play("dismount", 0.8)


func piping() -> bool:
	return _piping != null


# ---- hazards -------------------------------------------------------------
func _build_vents() -> void:
	var i := 0
	for hz in level.hazards:
		if String(hz.get("type", "")) != "steam":
			continue
		# Staggered phases, so a row of vents does not fire as one wall.
		var v := SteamVent.new(level, float(hz.get("x", 0)), float(i) * 0.83)
		vents.append(v)
		i += 1
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.30
		cm.bottom_radius = 0.36
		cm.height = 0.16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.86, 0.62, 0.14)
		mat.roughness = 0.8
		cm.material = mat
		mi.mesh = cm
		_stage.add_child(mi)
		_vent_nodes.append(mi)


func _step_vents(dt: float) -> void:
	for v in vents:
		v.step(dt)
		if v.hits(kid.x, kid.y, Kid.HW, Kid.BH) and kid.mercy_t <= 0.0:
			if mode == "riding":
				_begin_dismount(true)     # the Yoshi rule again
			else:
				kid.struck(v.x)
			hits += 1
			Audio.play("warn")


func _sync_vents() -> void:
	for i in vents.size():
		var v := vents[i]
		_vent_nodes[i].position = Vector3(v.x, v.y + 0.08, 0.0)
		var m := _vent_nodes[i].mesh.material as StandardMaterial3D
		if m == null:
			continue
		# THE TELL: the collar glows before it blows, steady under reduced
		# motion so it stays readable without strobing.
		if v.warning():
			var k: float = 0.7 if v.reduced_motion else (sin(v.t * 22.0) * 0.5 + 0.5)
			m.albedo_color = Color(0.86, 0.62, 0.14).lerp(Color(0.90, 0.25, 0.16), k)
		elif v.blowing():
			m.albedo_color = Color(0.95, 0.95, 0.98)
		else:
			m.albedo_color = Color(0.86, 0.62, 0.14)


# ---- the camera ----------------------------------------------------------
# NOT a follow function with a spring on it. js/camera.js is a small DIRECTOR:
# a room declares SHOTS — zones with their own dolly distance, height and lead
# — and the camera blends between them as you cross. ART_BRIEF §3.1, the
# Tropical Freeze half: "gameplay stays on one plane; the camera may drift and
# reframe at authored moments, not freely."
#
# A room whose lock is a three-tile bank pulls back when you reach it, because
# A LOCK YOU CANNOT SEE IS NOT A LOCK.

const CAM_DEFAULT := {"z": 34.0, "y": 2.6, "lead": 1.6, "floor": 5.8}
const CAM_FOV := 21.0

var _cam_y := 8.0
var _cam_z := 34.0
var _cam_lead := 1.6
var _cam_t := 0.0
var _punch_t := 0.0
var _punch_amt := 0.0


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Cam"
	# The FOV is DERIVED from the browser build's framing, not guessed: it
	# shows the play plane at about 57px per world unit, so a 1280-wide frame
	# sees ~12.6 units of height, and at z=34 that is 2*atan(6.3/34) ~ 21
	# degrees. Guessing 32 rendered the kid at thumbnail size.
	_cam.fov = CAM_FOV
	# NEAR/FAR SIZED TO THE ACTUAL SCENE, 2026-08-27. The defaults were
	# near=0.05 far=4000 -- an 80,000:1 range for a set that spans about 82
	# units (the camera sits at z=34, the sky lane at z=-48). That is simply
	# wrong regardless of any bug: depth precision is distributed across that
	# whole absurd range, so almost none of it lands where the game actually
	# is, and on a device with a shallower depth buffer than a desktop it can
	# collapse entirely.
	#
	# 0.5 clears the camera-parented canary at z=1.6 comfortably; 150 clears
	# the furthest lane with room to spare. This is a correctness fix on its
	# own merits. It is ALSO the last cheap thing left to try against the
	# black screen, and it is a long shot rather than a theory -- v22 ruled
	# out depth testing outright, so if precision were the whole story the
	# no-depth-test quad would have drawn.
	_cam.near = 0.5
	_cam.far = 150.0
	_stage.add_child(_cam)

	_cam_x = kid.x
	_cam_z = CAM_DEFAULT["z"]
	_cam_y = maxf(kid.y + CAM_DEFAULT["y"], CAM_DEFAULT["floor"])
	_place_camera(true)


## A heavy event: the dolly kicks in and settles. NEVER a rotation — a rolling
## camera on a side-view platformer costs the player the horizon.
func punch(amount := 1.0) -> void:
	_punch_amt = maxf(_punch_amt, amount)
	_punch_t = 1.0


func _place_camera(snap: bool) -> void:
	var dt := 1.0 / 60.0
	_cam_t += dt

	# The focus is the MACHINE while riding: it is three times the kid and the
	# camera has to be looking at what you are driving.
	var fx := kid.x
	var fy := kid.y
	var face := kid.facing
	if machine != null and mode in ["riding", "mounting"]:
		fx = machine.x
		fy = machine.y
		face = machine.face

	# Which shot is in force — the LAST zone containing the focus wins, so a
	# site can lay a special framing over a general one.
	var want := CAM_DEFAULT.duplicate()
	for sh in level.shots:
		if fx >= float(sh.get("x0", 0)) and fx <= float(sh.get("x1", 0)):
			want = CAM_DEFAULT.duplicate()
			for k in sh.keys():
				if k != "x0" and k != "x1":
					want[k] = float(sh[k])

	var z: float = want["z"]
	var y_off: float = want["y"]
	# The mode reframes on top of the room: climbing in is the best beat in
	# the game, so the camera leans in for it; riding pulls back.
	if mode == "mounting":
		z -= 4.5
		y_off -= 0.35
	elif mode == "riding":
		z += 2.6
		y_off += 0.5

	if _punch_t > 0.0:
		_punch_t = maxf(0.0, _punch_t - dt / 0.45)
		z -= _punch_amt * 1.6 * _punch_t * _punch_t
		if _punch_t == 0.0:
			_punch_amt = 0.0

	# The drift: slow, small, and on BOTH axes so it never reads as a wobble
	# on one of them. The frame is never dead still.
	z += sin(_cam_t * 0.23) * 0.5
	y_off += sin(_cam_t * 0.17 + 1.3) * 0.22

	var tx: float = fx + float(face) * _cam_lead
	var ty: float = maxf(fy + y_off, float(want["floor"]))
	if snap:
		_cam_z = z
		_cam_lead = float(want["lead"])
		_cam_x = tx
		_cam_y = ty
	else:
		# Ease the framing ITSELF, so crossing into a shot is a move, not a cut
		_cam_z += (z - _cam_z) * minf(1.0, 1.6 * dt)
		_cam_lead += (float(want["lead"]) - _cam_lead) * minf(1.0, 2.2 * dt)
		_cam_x += (tx - _cam_x) * minf(1.0, 3.2 * dt)
		_cam_y += (ty - _cam_y) * minf(1.0, 2.6 * dt)

	# Never show past the ends of the room.
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.y > 0.0:
			aspect = sz.x / sz.y
	var half_w: float = _cam_z * tan(deg_to_rad(CAM_FOV) * 0.5) * aspect
	var cx: float = clampf(_cam_x, half_w * 0.85, float(level.w) - half_w * 0.85)

	_cam.position = Vector3(cx, _cam_y, _cam_z)
	# AXIS-ALIGNED. Even a slight tilt turns the ground into a receding plane
	# and costs the player the horizon.
	_cam.rotation = Vector3.ZERO


func _build_shell() -> void:
	_shell = Shell.new()
	add_child(_shell)
	_shell.start_pressed.connect(_begin)
	_shell.resume_pressed.connect(func(): _shell.set_paused(false))
	_shell.restart_pressed.connect(func():
		_shell.set_paused(false)
		_load(level.slug))
	# SELECT cycles the render bisect; START is pause. Both are drawn on the
	# plate and were never connected to anything.
	_shell.select_pressed.connect(_cycle_render_mode)
	_shell.start_pressed_pad.connect(func(): _shell.toggle_pause())
	_shell.level_chosen.connect(func(slug: String):
		_shell.set_paused(false)
		var idx := LevelData.load_index()
		var i := 0
		for e in idx.get("levels", []):
			if String(e.get("slug", "")) == slug:
				_index = i
				break
			i += 1
		_load(slug))

	# `?skip` / --skip walks past the title, and EVERY gate uses it. Keeping
	# it a switch rather than something tests click through is what stops the
	# title screen becoming untested scaffolding nobody can change safely.
	var skip := false
	for a in OS.get_cmdline_args():
		if a == "--skip" or a.begins_with("--level="):
			skip = true
	if OS.has_feature("web") and _web_flag("skip"):
		skip = true
	if skip:
		_begin()
	else:
		_shell.show_title(true)

	# `?debug` — CLAUDE.md SS5, "never require a console... a way to test
	# something works" on the device it is actually played on. Added
	# 2026-08-26 chasing a black-screen-on-Android report the desktop
	# browser never showed: this puts the numbers that would normally live
	# in devtools directly on the phone's own screen instead, updated every
	# frame alongside the existing debug HUD line.
	# Flag-gated again. It was forced on while the black screen was being
	# chased; a build meant for judging how the game LOOKS should not open
	# with six lines of GL diagnostics over the art. Still one ?debug away
	# if the device misbehaves.
	if OS.has_feature("web") and _web_flag("debug"):
		_shell.show_debug = true


func _begin() -> void:
	_shell.show_title(false)
	_running = true


## THE ON-DEVICE RENDER BISECT. A phone-only fault cannot be bisected one
## deploy at a time, and the owner's client makes URL flags impractical, so
## the ladder is driven by SELECT on the drawn pad instead. Each press hides
## one more class of thing; the mode is named in the debug line so a single
## screenshot says which rung was reached.
##
##   0 everything          — the normal scene
##   1 no shadows          — the key light stops casting
##   2 no MultiMesh        — tiles, bolts, golden, wall, bank all hidden
##   3 no diorama          — the painted lanes hidden too
##   4 canary only         — nothing but the camera-parented quad and the
##                           Environment's clear colour
##
## Whichever rung first shows something is the answer: the class hidden at
## that step is the one the device cannot draw.
const RENDER_MODES := ["everything", "no-shadow", "no-multimesh", "no-diorama", "canary-only"]
var _render_mode := 0

func _cycle_render_mode() -> void:
	_render_mode = (_render_mode + 1) % RENDER_MODES.size()
	_apply_render_mode()


func _apply_render_mode() -> void:
	var m := _render_mode
	# Rung 1 is kept in the ladder for shape, but shadows are off in every
	# mode now (see _build_lights) -- ART_BRIEF forbids the maps outright.
	var key := _stage.get_node_or_null("Key") as DirectionalLight3D
	if key:
		key.shadow_enabled = false
	# Every MultiMesh in the scene, whatever it is for.
	for n in [_stage.get_node_or_null("Tiles"), _wall_node, _pickup_node,
			_golden_node, _bank_node]:
		if n:
			n.visible = m < 2
	if _diorama:
		_diorama.visible = m < 3
	# The actors are content too -- at canary-only nothing authored survives.
	if _model:
		_model.visible = m < 4
	if _machine_node:
		_machine_node.visible = m < 4
	for r in _robot_nodes:
		if r:
			r.visible = m < 4


func _web_flag(name: String) -> bool:
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var js := Engine.get_singleton("JavaScriptBridge")
	return bool(js.eval("new URLSearchParams(location.search).has('%s')" % name, true))


## THE CONSOLE, ON THE SCREEN. Godot's renderer reports shader-compile and
## framebuffer failures to the BROWSER console -- which is exactly the thing
## a phone does not have, and the owner is testing through a client where
## editing the URL to add ?debug is not practical either. So on web this
## hooks console.error/warn (and window.onerror) into a ring buffer the game
## can read back and draw on itself.
##
## CLAUDE.md SS5 states the rule this satisfies: "never require a console, a
## keyboard, or a desktop browser to verify something works -- this game is
## played on a phone or tablet." A diagnostic that needs devtools to read is
## not a diagnostic for this project.
func _install_js_log_hook() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var js = Engine.get_singleton("JavaScriptBridge")
	js.eval("""
		(function(){
			if (window.__eeriLog) return;
			window.__eeriLog = [];
			// THE FIRST ERRORS ARE THE ONES THAT MATTER and the ring buffer was
			// losing them: Godot reports a shader that will not compile or link
			// while the scene is being BUILT, and the RGBAFloat warning then
			// repeats forever and pushes that first report out of the window.
			// This buffer is append-only and capped, so the earliest failures
			// survive no matter how much noise follows.
			window.__eeriFirst = [];
			var keep = function(tag, args){
				try {
					var s = Array.prototype.map.call(args, function(a){
						if (a instanceof Error) return a.message;
						if (typeof a === 'object') { try { return JSON.stringify(a); } catch(e) { return String(a); } }
						return String(a);
					}).join(' ');
					// Godot repeats some errors every frame; collapse runs so
					// the ring buffer still holds the FIRST distinct failures
					// rather than 200 copies of the newest one.
					if (window.__eeriFirst.length < 8
						&& !/RGBAFloat|not supported by hardware/.test(s)
						&& s.trim().indexOf('at:') !== 0) {
						window.__eeriFirst.push(tag + ' ' + s);
					}
					var last = window.__eeriLog[window.__eeriLog.length - 1];
					if (last && last.msg === s) { last.n++; return; }
					window.__eeriLog.push({ tag: tag, msg: s, n: 1 });
					if (window.__eeriLog.length > 40) window.__eeriLog.shift();
				} catch(e) {}
			};
			window.__eeriCaps = '';
			['error','warn'].forEach(function(k){
				var orig = console[k].bind(console);
				console[k] = function(){ keep(k, arguments); orig.apply(console, arguments); };
			});
			window.addEventListener('error', function(e){ keep('js', [e.message]); });
			var c = document.querySelector('canvas');
			if (c) {
				c.addEventListener('webglcontextlost', function(){ keep('gl', ['WEBGL CONTEXT LOST']); });
				var gl = c.getContext('webgl2') || c.getContext('webgl');
				if (gl) {
					// PINNED, not pushed into the ring buffer: on the owner's
					// phone three repeated RGBAFloat warnings pushed these
					// straight out of the window, and the capability numbers
					// are the one thing that cannot be guessed from here.
					window.__eeriCaps = 'maxTex=' + gl.getParameter(gl.MAX_TEXTURE_SIZE)
						+ ' maxRB=' + gl.getParameter(gl.MAX_RENDERBUFFER_SIZE)
						+ ' maxVary=' + gl.getParameter(gl.MAX_VARYING_VECTORS)
						+ ' maxVertTex=' + gl.getParameter(gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS)
						+ ' maxTexUnits=' + gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS)
						+ ' ubo=' + gl.getParameter(gl.MAX_UNIFORM_BLOCK_SIZE)
						+ ' vsUB=' + gl.getParameter(gl.MAX_VERTEX_UNIFORM_BLOCKS)
						+ ' fsUB=' + gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_BLOCKS)
						+ ' vsVec=' + gl.getParameter(gl.MAX_VERTEX_UNIFORM_VECTORS)
						+ ' fsVec=' + gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_VECTORS)
						+ ' samples=' + gl.getParameter(gl.MAX_SAMPLES);
					var dbg0 = gl.getExtension('WEBGL_debug_renderer_info');
					if (dbg0) window.__eeriCaps += ' gpu=' + gl.getParameter(dbg0.UNMASKED_RENDERER_WEBGL);
					keep('gl', ['maxTex=' + gl.getParameter(gl.MAX_TEXTURE_SIZE)
						+ ' maxRB=' + gl.getParameter(gl.MAX_RENDERBUFFER_SIZE)
						+ ' maxVary=' + gl.getParameter(gl.MAX_VARYING_VECTORS)
						+ ' maxVertTex=' + gl.getParameter(gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS)
						+ ' vendor=' + gl.getParameter(gl.VENDOR)]);
					var dbg = gl.getExtension('WEBGL_debug_renderer_info');
					if (dbg) keep('gl', ['renderer=' + gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL)]);
				}
			}
		})();
	""", true)


## WHAT THE VIEWPORT ACTUALLY CONTAINS, read back from the GPU once.
##
## The decisive question after v19: Godot submits 35 draw calls, reports no
## error at all, and yet not even the Environment's sky-blue CLEAR COLOUR
## reaches the screen. That is two completely different faults wearing the
## same black rectangle:
##
##   sampled pixel is SKY BLUE -> 3D rendered fine and the failure is in
##     PRESENTATION: the 3D framebuffer never reaches the canvas, or
##     something opaque is drawn over it.
##   sampled pixel is BLACK    -> the 3D pass genuinely produced nothing,
##     despite Godot counting the draws and the driver raising no error.
##
## Sampled once and cached -- get_image() is a full GPU readback and must not
## run per frame. Points are chosen where the sky, the wall and the ground
## should each be, so one line distinguishes "all black" from "wrong colour".
var _vp_probe := ""

func _probe_viewport() -> void:
	# EXACTLY ONCE, whatever happens. Every early return below used to leave
	# _vp_probe empty, which re-armed the caller and ran a full GPU readback
	# on EVERY frame -- the run that caught this was still on frame 5 after
	# 26 seconds. A diagnostic that halts the thing it is measuring is worse
	# than none, so the flag is set before anything can fail.
	_vp_probe = "VP readback failed"
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return
	# Sample points computed from the frustum rather than eyeballed: at z=1.6
	# with CAM_FOV 21 the visible half-height is 1.6*tan(10.5deg) = 0.2965, so
	# canary A at y=+0.20 lands at screen 0.5 - (0.20/0.2965)*0.5 = 0.163 and
	# canary B at y=-0.10 lands at 0.5 + (0.10/0.2965)*0.5 = 0.669.
	var pts := {
		"A": Vector2(0.5, 0.163),    # depth-tested quad (magenta FF00FF)
		"mid": Vector2(0.5, 0.42),   # the painted wall
		"B": Vector2(0.5, 0.669),    # NO-DEPTH-TEST quad (green 00FF00)
	}
	var parts: Array[String] = []
	for k in pts.keys():
		var f: Vector2 = pts[k]
		var c := img.get_pixel(int(w * f.x), int(h * f.y))
		parts.append("%s=%02X%02X%02X" % [k,
			int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)])
	_vp_probe = "VP %dx%d " % [w, h] + " ".join(parts)


## The FIRST errors seen, which the ring buffer was losing to repeat spam.
func _js_first_errors(n := 5) -> String:
	if not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var js = Engine.get_singleton("JavaScriptBridge")
	var v = js.eval("(window.__eeriFirst||[]).slice(0,%d).map(function(s){return s.slice(0,200);}).join(String.fromCharCode(10))" % n, true)
	return String(v) if v != null else ""


## The device's GL capability line, kept out of the ring buffer so a flood of
## repeated warnings cannot scroll it away (which is exactly what happened on
## the owner's phone the first time).
func _js_caps() -> String:
	if not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var js = Engine.get_singleton("JavaScriptBridge")
	var v = js.eval("window.__eeriCaps || ''", true)
	return String(v) if v != null else ""


## The most recent captured lines, newest last, shortened to fit a phone.
func _js_log_tail(lines := 6) -> String:
	if not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var js = Engine.get_singleton("JavaScriptBridge")
	# String.fromCharCode(10) rather than a backslash-n escape ON PURPOSE: this
	# JS lives inside a GDScript """...""" string, which processes escape
	# sequences itself -- so a backslash-n written here reaches the browser as a REAL
	# line break inside a JS string literal, which is a SyntaxError and
	# silently returns nothing. Cost a debugging round trip; do not
	# 'tidy' it back into an escape.
	var v = js.eval("""
		(window.__eeriLog || []).slice(-%d).map(function(e){
			return '[' + e.tag + ']' + (e.n > 1 ? 'x' + e.n : '') + ' ' + e.msg.slice(0, 220);
		}).join(String.fromCharCode(10));
	""" % lines, true)
	return String(v) if v != null else ""


# ---- the loop ------------------------------------------------------------
# FIXED TIMESTEP, and it is not a preference. scripts/kid.gd reproduces the
# browser build's semi-implicit Euler frame for frame, and the reach budget
# tests/test_kid.tscn proves is a function of that step. Running it on a
# variable delta makes the jump height depend on the frame rate — which is
# exactly the "a jump a six-year-old cannot make in a room the prover called
# fine" failure the whole port is arranged to avoid.
## PAUSE FROM ANYTHING. The drawn pad's START pill already opened the menu;
## a controller had nothing to press because no pause action existed. Polled
## here rather than in _input so it behaves the same as every other verb in a
## fixed-timestep loop.
func _unhandled_input(_e: InputEvent) -> void:
	if Input.is_action_just_pressed("pause") and _running:
		_shell.toggle_pause()


func _process(delta: float) -> void:
	if kid == null:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_shell.toggle_pause()
	# Touch is shown only once a touch is actually seen — a pad drawn on a
	# desktop screen is clutter.
	if DisplayServer.is_touchscreen_available():
		# THE PAD IS FOR THUMBS ONLY. Owner, 2026-08-27: the iPad is played in
		# landscape with a DualSense, "so no gameboy control screen needed for
		# that" -- a drawn Game Boy face over a game being played on a real
		# controller is a picture of a control nobody is touching, and in
		# landscape it covers most of the screen.
		#
		# So it needs BOTH a touchscreen AND no connected pad. Re-checked every
		# frame rather than at boot because a controller can be paired or drop
		# mid-session, and the browser only learns about it on first input.
		# ...AND IT IS A PORTRAIT AFFORDANCE. The drawn Game Boy plate is the
		# PHONE build's control scheme -- owner direction 2026-08-27: "iPad will
		# be horizontal screen and played with dual sense so no gameboy control
		# screen needed for that". In landscape the plate would eat a third of
		# a wide frame to duplicate a pad that is already in the player's hands,
		# so the tablet build is controller-only and the pad never appears.
		var vp := get_viewport().get_visible_rect().size
		var portrait := vp.y >= vp.x
		var want_touch := (_running and not _shell.paused() and portrait
			and DisplayServer.is_touchscreen_available()
			and Input.get_connected_joypads().is_empty())
		_shell.show_touch(want_touch)
	if not _running or _shell.paused():
		_sync_visual()
		return
	_accum += minf(delta, 0.25)     # never spiral after a stall
	while _accum >= DT:
		_accum -= DT
		var inp := _read_input()
		_step_pipes(DT, inp)
		if mode == "foot" and not piping():
			kid.step(DT, inp)
		_step_ride(DT, inp)
		_step_bank(DT, inp)
		_step_pieces(DT, inp)
		if kid.just_jumped: Audio.play("jump")
		if kid.just_landed: Audio.play("land", 1.0, -12.0)
		if kid.just_struck: Audio.play("warn")
		if run != null:
			run.step(kid.x, kid.y)
			if run.just_bolt: Audio.bolt(run.bolts_got)
			if run.just_golden: Audio.play("clank")
			if run.just_blueprint:
				Audio.play("thunk")
				_shell.banner("blueprint")
			if run.just_checkpoint:
				Audio.play("clank", 1.2)
				_shell.banner("checkpoint")
			if run.just_phase: Audio.play("clank", 0.9)
			if run.just_raised:
				Audio.play("thunk", 1.1)
				_shell.banner("clear")
			# the level's checkpoint owns the respawn, not a number in kid.gd
			kid.last_checkpoint = run.checkpoint
		_step_hoists(DT)
		_step_vents(DT)
		_step_robots(DT)
		_step_advance(DT)
	_sync_visual()
	_sync_robots()
	_sync_machine()
	_sync_bank()
	_sync_pieces()
	_sync_arm()
	_sync_pickups()
	_sync_hoists()
	_sync_vents()
	if _diorama != null:
		_diorama.step_fore(DT, kid.climbing)
	_place_camera(false)


## The flag ends the level and the next one begins — no map, no menu.
## A short beat first, so the flag going up is something you SEE rather than
## a cut you are told about.
const ADVANCE_DELAY := 1.6

func _step_advance(dt: float) -> void:
	if run == null or not run.finished:
		return
	_advance_t += dt
	if _advance_t < ADVANCE_DELAY:
		return
	_advance_t = 0.0
	# CLOCKING OUT HAPPENS AT THE END OF A WORLD, never a level (DESIGN §4.2)
	# — it is the world's curtain. Three levels to a world, so it lands on
	# every third flag.
	if (_index + 1) % 3 == 0:
		GameState.worlds_cleared += 1
		Audio.play("thunk", 0.85)
	if _index + 1 >= _roster.size():
		# Twelve is the whole game (DESIGN §4.2). Nothing past it yet — the
		# clock-out beat belongs to a WORLD, not a level, and is not built.
		return
	_index += 1
	_load(String(_roster[_index].get("slug", "")))


## Tear the room down and build the next one. Everything the level owns is
## rebuilt; GameState keeps what survives a level.
func _load(slug: String) -> void:
	var next := LevelData.load_slug(slug)
	if next == null:
		return
	GameState.bolts_collected += run.bolts_got if run != null else 0
	for n in [_bank_node, _pickup_node, _golden_node, _machine_node, _wall_node, _girder_node, _blueprint_node]:
		if n != null:
			n.queue_free()
	for n in _robot_nodes:
		n.queue_free()
	_robot_nodes.clear()
	_robot_tells.clear()
	_robot_legs.clear()
	robots.clear()
	for n in _hoist_nodes:
		n.queue_free()
	_hoist_nodes.clear()
	hoists.clear()
	for n in _vent_nodes:
		n.queue_free()
	_vent_nodes.clear()
	vents.clear()
	for c in get_children():
		if c is MultiMeshInstance3D and c.name == "Tiles":
			c.queue_free()
	_bank_node = null
	_pickup_node = null
	_golden_node = null
	_blueprint_node = null
	_machine_node = null
	_seat_node = null
	_boom_node = null
	_stick_node = null
	_bucket_node = null
	bank = null
	wall = null
	girder = null
	_wall_node = null
	_girder_node = null
	machine = null
	mode = "foot"

	level = next
	GameState.current_level = _index + 1
	_build_tiles()
	_build_diorama()
	var k = level.spawn.get("kid", {})
	kid = Kid.new(level, float(k.get("x", 4.5)), float(k.get("y", 4)))
	_build_robots()
	_build_machine()
	_build_bank()
	_build_pieces()
	_build_pickups()
	_build_hoists()
	_build_vents()
	_cam_x = kid.x
	_place_camera(true)


func _read_input() -> Dictionary:
	var ax := Input.get_axis("move_left", "move_right")
	return {
		"ax": ax,
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"up_held": Input.is_action_pressed("move_up"),
		"down_held": Input.is_action_pressed("move_down"),
		"action_pressed": Input.is_action_just_pressed("action"),
		"action_held": Input.is_action_pressed("action"),
	}


func _sync_visual() -> void:
	if _model == null:
		return
	_model.position = Vector3(kid.x, kid.y, 0.0)
	# The rig is modelled facing +x, so facing -x is a half turn. VERSIONS.md
	# records the trap on the other side of this: the browser build's rig
	# already turns +z->+x, so any EXTRA yaw points him at the camera.
	_face_kid()
	_play(_clip_for(kid.visual_state()))
	if _shell:
		# THE REAL HUD: what a six-year-old needs at a glance. The debug readout
		# that used to live here is still available, behind a switch.
		_shell.set_hud({
			"bolts": run.bolts_got if run else 0,
			"bolts_total": run.bolts_total if run else 0,
			"golden": run.golden_got if run else 0,
			"golden_total": run.golden_total if run else 0,
			"address": level.slug.replace("eeri-", ""),
			"name": level.display_name,
			"blueprints": GameState.blueprints,
		})
		if _shell.show_debug:
			var alive := 0
			for r in robots:
				if not r.dead:
					alive += 1
			var dbg := "[%s] %s  %s   x %.1f y %.1f  stomped %d bumped %d robots %d" % [
				BUILD,
				level.display_name, (kid.visual_state() if mode == "foot" else mode),
				kid.x, kid.y, stomps, hits, alive]
			if bank != null:
				dbg += "  bank %d/%d" % [bank.remaining, bank.rows]
			if wall != null:
				dbg += "  wall %s" % ["intact", "cracked", "down"][wall.state()]
			if girder != null:
				dbg += "  girder %s" % ["stacked", "slung", "seated"][girder.state()]
			# Render diagnostics ride along on the SAME line, every frame, so
			# a black screen still tells you something: if this line is
			# updating at all, the game loop is alive and it is the RENDERER
			# that has nothing to show, not a frozen script.
			var vp := get_viewport()
			var key := _stage.get_node_or_null("Key") as DirectionalLight3D
			dbg += "  |  frame %d  %dx%d  cam %s  diorama %d  %s/%s  shadow %s@%s" % [
				Engine.get_frames_drawn(), vp.get_visible_rect().size.x,
				vp.get_visible_rect().size.y, (_cam != null and _cam.current),
				(_diorama.get_child_count() if _diorama else -1),
				RenderingServer.get_video_adapter_name(),
				ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
				("on" if (key and key.shadow_enabled) else "OFF"),
				ProjectSettings.get_setting(
					"rendering/lights_and_shadows/directional_shadow/size", "?")]
			# and the browser's own console, which is where Godot reports a
			# shader that would not compile or a framebuffer it could not get
			# What the suspect systems actually contain, so a black screen
			# can be told apart from an empty one.
			var tiles_n := 0
			var tn := _stage.get_node_or_null("Tiles")
			if tn and tn is MultiMeshInstance3D and tn.multimesh:
				# instance_count, not visible_instance_count: the latter is -1
				# for "draw them all", which reads as an error and is not.
				tiles_n = tn.multimesh.instance_count
			dbg += "  tiles %d  kid %s  canary %s" % [
				tiles_n,
				("yes" if (_model and _model.visible) else "no"),
				("yes" if (_cam and _cam.get_node_or_null("Canary")) else "no")]
			# WHAT THE RENDERER ITSELF THINKS IT DID. This is the number that
			# separates the two remaining possibilities without another guess:
			#   draw calls > 0 and still black -> the scene IS being submitted
			#     and the GPU/driver is dropping it (a device-side fault).
			#   draw calls == 0 -> nothing is being submitted at all, and the
			#     fault is ours: culling, camera, viewport or visibility.
			# Texture memory is here too because the diorama's layers are
			# 4096-wide and uncompressed (vram compression is off by design),
			# which is a lot of VRAM on a phone and worth being able to see
			# rather than estimate.
			dbg += "  MODE %d/%s" % [_render_mode, RENDER_MODES[_render_mode]]
			# THE CAMERA MATRIX ITSELF. v22 ruled out depth testing: a quad with
			# no_depth_test still does not rasterise. Clear works, 38 draws are
			# submitted, nothing lands, nothing errors. The way that happens
			# silently is geometry being PROJECTED TO NOWHERE -- a camera
			# transform carrying NaN or a degenerate basis makes every vertex
			# invalid, and a driver simply discards those primitives without
			# complaint. Desktop and phone run identical level data, so if
			# these numbers differ the cause is finally in view.
			if _cam:
				var gp := _cam.global_position
				var det := _cam.global_transform.basis.determinant()
				dbg += "  CAM(%.2f,%.2f,%.2f) det=%.3f fov=%.1f near=%.3f far=%.0f" % [
					gp.x, gp.y, gp.z, det, _cam.fov, _cam.near, _cam.far]
			dbg += "  draws %d  objs %d  vram %.1fMB" % [
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				float(RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0]
			var caps := _js_caps()
			if caps != "":
				dbg += "
GL " + caps
			# One readback, once the scene has certainly drawn a few frames.
			if _vp_probe == "" and Engine.get_frames_drawn() > 30:
				_probe_viewport()
			if _vp_probe != "":
				dbg += "
" + _vp_probe
			var first := _js_first_errors(5)
			if first != "":
				dbg += "
FIRST: " + first
			var tail := _js_log_tail(3)
			if tail != "":
				dbg += "
" + tail
			_shell.set_debug(dbg)


## THE THREE-QUARTER TURN, ported from js/kid.js pose().
##
## THIS WAS WRONG and the owner spotted it on the iPad: Eeri ran facing the
## CAMERA instead of side-on. The port used `0.0 if facing > 0 else PI`,
## which points a +z-modelled rig straight down the lens one way and straight
## away the other. The browser build has never done that -- js/kid.js line 17
## defines FACE_TURN = 0.42 * PI (about 75.6 degrees) and calls it exactly
## what it is: "3/4 view: forward +/-x, tipped toward camera". That tip is
## the look; a pure side-on profile would lose his face.
##
## THE MIRROR IS -THETA, NOT PI - THETA, and js/kid.js spends a paragraph on
## why because it cost them a bug: "the two rigs mirror differently... for a
## +z-forward rig the mirror is simply -theta... That is the moon-walk: the
## run clip playing forwards on a body facing the wrong way." eeri_v5.glb IS
## the +z-forward skinned rig, so it takes -FACE_TURN going left.
##
## Riding is its own case -- the seat owns the facing, and a skinned rig sits
## at SKIN_RIDE_YAW (PI/2) rather than the walking turn.
##
## The turn is EASED at 0.18 per frame rather than snapped, which is what
## makes a direction change read as him turning round instead of flipping.
const FACE_TURN := 0.42 * PI
const SKIN_RIDE_YAW := PI * 0.5
const TURN_EASE := 0.18
var _turn := FACE_TURN


func _face_kid() -> void:
	if _model == null:
		return
	var target: float
	if mode == "riding":
		target = SKIN_RIDE_YAW
	elif kid.facing > 0:
		target = FACE_TURN
	else:
		target = -FACE_TURN
	_turn += (target - _turn) * TURN_EASE
	_model.rotation.y = _turn


## js/kid.js CLIP_FOR — the body names a state, the model picks a clip.
func _clip_for(state: String) -> String:
	match state:
		"air": return "jump"
		"climb": return "climb"
		"run": return "run"
		"walk": return "walk"
		_: return "idle"
