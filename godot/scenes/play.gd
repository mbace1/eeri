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
var vents: Array[SteamVent] = []
var _vent_nodes: Array[Node3D] = []
var hoists: Array[Hoist] = []
var _hoist_nodes: Array[Node3D] = []
var _pickup_node: MultiMeshInstance3D
var _golden_node: MultiMeshInstance3D
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
	# THE PLAY PLANE IS CARD. The manifest ships `card_detail` live and
	# describes it as exactly this job — "corrugated kraft: the earth, the cut
	# faces, the deep bands" — so the ground the player stands on is made of
	# the same material as the set behind it rather than being a flat brown
	# slab competing with it.
	var card: Dictionary = AssetRegistry.manifest.get("textures", {}).get("card", {})
	var tex: Texture2D = null
	if String(card.get("status", "")) == "live":
		tex = load("res://data/" + String(card.get("file", ""))) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)   # one tile of card per tile
		# card_detail is GRAIN, not colour — kraft paper is nearly white, so
		# used as albedo straight it reads as pale sand. It modulates an earth
		# tone taken off the near lane's own painted ground so the play plane
		# and the set agree about what the site is made of.
		mat.albedo_color = Color(0.46, 0.33, 0.21)
	else:
		mat.albedo_color = Color(0.47, 0.35, 0.24)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
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
	# Tuned against the PAINTED set, not in isolation: the lanes are unshaded
	# and carry their own light, so the actors only need enough to sit in the
	# scene and throw a contact shadow.
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.29, 0.66, 0.91)   # the intro's sky blue
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.68, 0.85)
	e.ambient_light_energy = 0.30
	env.environment = e
	add_child(env)


# ---- the diorama ---------------------------------------------------------
func _build_diorama() -> void:
	if _diorama != null:
		_diorama.queue_free()
	_diorama = Diorama.new()
	_diorama.name = "Diorama"
	add_child(_diorama)
	var world := Diorama.world_for(level.index)
	var n := _diorama.build(world)
	if n == 0:
		push_warning("no layer art mounted for '%s' — the room will be greybox" % world)


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
		add_child(node)
		_robot_nodes.append(node)
		_robot_tells.append(built["tell"])


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
		if i < _robot_tells.size():
			var hot: bool = r.state in ["notice", "wind", "wake", "crouch"]
			var m := (_robot_tells[i] as MeshInstance3D).mesh.material as StandardMaterial3D
			if m:
				var k: float = (sin(r.t * 26.0) * 0.5 + 0.5) if hot else 0.0
				m.albedo_color = Craft.HAZARD.lerp(Color.WHITE, k * 0.7)


# ---- the ride ------------------------------------------------------------
func _build_machine() -> void:
	var spawns = level.spawn.get("excavator", null)
	if spawns == null:
		return
	# Which machine this room parks. The wall levels get the crane — the ball
	# that swings at you unmanned is the ball you swing at the wall.
	var mkind := "crane" if level.wall != null else "excavator"
	machine = Machine.new(level, float(spawns.get("x", 0)), float(spawns.get("y", 0)), mkind)

	var packed := load("res://data/3d/excavator_v1.glb") as PackedScene
	if packed != null:
		_machine_node = packed.instantiate()
		add_child(_machine_node)
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
			push_warning("excavator has no `seat` node — falling back to the offset")
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(machine.hw * 2.0, machine.h, 1.4)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.72, 0.12)      # MACHINE yellow
		bm.material = mat
		mi.mesh = bm
		_machine_node = mi
		add_child(_machine_node)


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
	bank = Bank.new(level.bank)
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
	add_child(_bank_node)
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
	_sync_pickups()
	_sync_hoists()
	_sync_vents()


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
	add_child(n)
	return n


func _sync_pickups() -> void:
	if run == null:
		return
	var spin := Time.get_ticks_msec() * 0.002
	_fill(_pickup_node, level.bolts, func(i): return run.bolt_alive(i), spin)
	_fill(_golden_node, level.golden, func(i): return run.golden_alive(i), spin * 0.7)


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
		add_child(mi)
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
		add_child(_wall_node)

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
		add_child(_girder_node)
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
		add_child(mi)
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
	add_child(_cam)
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


func _begin() -> void:
	_shell.show_title(false)
	_running = true


func _web_flag(name: String) -> bool:
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var js := Engine.get_singleton("JavaScriptBridge")
	return bool(js.eval("new URLSearchParams(location.search).has('%s')" % name, true))


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
	if Input.is_action_just_pressed("ui_cancel"):
		_shell.toggle_pause()
	# Touch is shown only once a touch is actually seen — a pad drawn on a
	# desktop screen is clutter.
	if DisplayServer.is_touchscreen_available():
		_shell.show_touch(_running and not _shell.paused())
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
			if run.just_blueprint: Audio.play("thunk")
			if run.just_checkpoint: Audio.play("clank", 1.2)
			if run.just_phase: Audio.play("clank", 0.9)
			if run.just_raised: Audio.play("thunk", 1.1)
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
	for n in [_bank_node, _pickup_node, _golden_node, _machine_node, _wall_node, _girder_node]:
		if n != null:
			n.queue_free()
	for n in _robot_nodes:
		n.queue_free()
	_robot_nodes.clear()
	_robot_tells.clear()
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
	_model.rotation.y = 0.0 if kid.facing > 0 else PI
	_play(_clip_for(kid.visual_state()))
	if _shell:
		var alive := 0
		for r in robots:
			if not r.dead:
				alive += 1
		var txt := "%s  %s
%s  x %.1f y %.1f
stomped %d  bumped %d  robots %d" % [
			level.slug, level.display_name,
			(kid.visual_state() if mode == "foot" else mode), kid.x, kid.y,
			stomps, hits, alive]
		if run != null:
			txt += "
bolts %d/%d  golden %d/%d%s%s" % [
				run.bolts_got, run.bolts_total, run.golden_got, run.golden_total,
				"  blueprint" if run.blueprint_got else "",
				"  CHECKPOINT" if run.checkpoint_lit else ""]
			if run.flag_phase >= 0:
				txt += "
flag %d/3%s" % [run.flag_phase + 1,
					"  LEVEL COMPLETE" if run.flag_raised else ""]
		if bank != null:
			txt += "
bank %d/%d%s" % [bank.remaining, bank.rows,
				"  CLEARED" if bank.cleared else ("  (in reach)" if bank.armed else "")]
		if wall != null:
			txt += "
wall %s" % ["intact", "cracked", "down"][wall.state()]
		if girder != null:
			txt += "  girder %s" % ["stacked", "slung", "seated"][girder.state()]
		_shell.set_hud(txt)


## js/kid.js CLIP_FOR — the body names a state, the model picks a clip.
func _clip_for(state: String) -> String:
	match state:
		"air": return "jump"
		"climb": return "climb"
		"run": return "run"
		"walk": return "walk"
		_: return "idle"
