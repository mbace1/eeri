extends Node2D
## EERI, RENDERED BY THE 2D PIPELINE.
##
## WHY THIS EXISTS, in one paragraph. Thirty-five builds established on the
## owner's phone (PowerVR D-Series via ANGLE, Android Chrome) that Godot's 3D
## renderer draws nothing but black there: every material, every shader
## including a four-line hand-written one, every mesh, direct and inside a
## SubViewport, with and without an environment, with explicit exposure and
## tonemapping, at 79MB and at 5MB of pack, under gl_compatibility and
## forward_plus base methods, with and without autoloads -- and, decisively,
## piritori-eden's OWN project fails identically when built here. Meanwhile
## the 2D pipeline draws this game's actual painted art correctly: the v30
## bisect read 75BCEA straight off data/2d/day_sky_v2.webp as a Sprite2D.
##
## THIS IS NOT A DOWNGRADE. ART_BRIEF §3.4 asks for flat unlit cutouts with
## the shading painted in and "no cast shadow maps"; assets/README.md
## describes the lanes as paintings at fixed world rects; the browser build
## draws them on plain unlit planes. The perspective camera was only ever
## doing parallax arithmetic on our behalf. scripts/diorama2d.gd now does that
## arithmetic explicitly, so the same paintings land in the same places.
##
## WHAT IS REUSED, WHICH IS ALMOST EVERYTHING. scripts/kid.gd is engine
## independent by design -- a deliberate decision recorded in
## GODOT_PORT_ANALYSIS §3.2, which forbade CharacterBody3D precisely so the
## reach budget stayed provable -- so the physics, the collision sweep in
## level_data.gd, the twelve authored levels and every gate that tests them
## carry over untouched. Only the drawing changes.
##
## STATUS: first playable pass. The diorama and the kid are real; machines,
## robots and pieces are not drawn yet. Ships behind ?r2d so the 3D path is
## still reachable for anyone testing on hardware where it works.

const DT := 1.0 / 60.0
const BUILD := "v36-2d"

## Matches scenes/play.gd exactly, so the framing is the one the rooms were
## authored and proved against.
const CAM_FOV := 21.0
const CAM_Z := 34.0
const CAM_Y_OFF := 2.6
const CAM_FLOOR := 5.8
const CAM_LEAD := 1.6

var level: LevelData
var kid: Kid
var _diorama: Diorama2D
var _shell: Shell
var _actors: Node2D
var _kid_node: Node2D

var _cam_x := 0.0
var _cam_y := 8.0
var _running := false
var _roster: Array = []
var _index := 0


func _ready() -> void:
	var slug := "eeri-1-1"
	var idx := LevelData.load_index()
	_roster = idx.get("levels", [])
	level = LevelData.load_slug(slug)
	if level == null:
		push_error("2D: could not load %s" % slug)
		return

	_diorama = Diorama2D.new()
	_diorama.name = "Diorama2D"
	_diorama.layer = 0
	add_child(_diorama)
	_diorama.build(Diorama2D.world_for(level.index))

	# The actors ride a layer ABOVE the painted lanes but BELOW the fore
	# occluder would sit -- for this first pass they are simply above the set,
	# which matches every lane except `fore`.
	var actor_layer := CanvasLayer.new()
	actor_layer.name = "Actors"
	actor_layer.layer = 1
	add_child(actor_layer)
	_actors = Node2D.new()
	actor_layer.add_child(_actors)

	var k = level.spawn.get("kid", {})
	kid = Kid.new(level, float(k.get("x", 4.5)), float(k.get("y", 4.0)))
	_kid_node = _build_kid()
	_actors.add_child(_kid_node)

	_shell = Shell.new()
	add_child(_shell)
	_shell.start_pressed.connect(func(): _running = true; _shell.show_title(false))
	_shell.resume_pressed.connect(func(): _shell.set_paused(false))
	_shell.restart_pressed.connect(func(): _shell.set_paused(false))
	_shell.show_title(false)
	_running = true

	_cam_x = kid.x
	_cam_y = maxf(kid.y + CAM_Y_OFF, CAM_FLOOR)
	_place()


## EERI, FROM THE REAL RIG. tools/bake_sprites.gd renders eeri_v5.glb's own
## clips on DESKTOP -- where Godot's 3D renderer works -- through the same
## light rig play.gd used, and writes them to data/sprites. So the figure on
## screen is the actual model, not an approximation of it: same cap and
## spikes, same navy tee, same machine-yellow wellies, same animation.
##
## A fixed side-on camera and flat unlit light is exactly the case where a
## pre-rendered sprite is indistinguishable from live 3D, which is why this
## costs the look nothing. If the bake is missing the flat placeholder below
## still draws, so a fresh clone without baked sprites is playable rather
## than empty.
var _frames := {}          # clip -> Array[Texture2D]
var _sprite: Sprite2D
var _clip := "idle"
var _clip_t := 0.0

const CLIP_FPS := 12.0
## js/kid.js CLIP_FOR -- the body names a state, the drawing picks a clip.
const CLIP_FOR := {
	"idle": "idle", "walk": "walk", "run": "run",
	"jump": "jump", "fall": "jump", "climb": "climb",
}


func _load_sprites() -> bool:
	var p := "res://data/sprites/sprites.json"
	if not FileAccess.file_exists(p):
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	var raw = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) != TYPE_DICTIONARY or not raw.has("eeri"):
		return false
	var clips: Dictionary = raw["eeri"].get("clips", {})
	for clip in clips.keys():
		var arr: Array[Texture2D] = []
		for name in clips[clip]:
			var t := load("res://data/sprites/" + String(name)) as Texture2D
			if t:
				arr.append(t)
		if not arr.is_empty():
			_frames[clip] = arr
	return not _frames.is_empty()


func _build_kid() -> Node2D:
	var n := Node2D.new()
	if _load_sprites():
		_sprite = Sprite2D.new()
		_sprite.texture = _frames[_frames.keys()[0]][0]
		_sprite.centered = false
		# The bake frames him standing on the bottom of a 256px cell, so the
		# sprite hangs UP and LEFT from the world point his feet occupy.
		_sprite.offset = Vector2(-128, -256)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		n.add_child(_sprite)
		return n
	# Fallback: flat shapes in his own palette, so a clone with no baked
	# sprites still shows something honest rather than nothing.
	var body := ColorRect.new()
	body.color = Color(0.18, 0.23, 0.36)
	body.size = Vector2(26, 30); body.position = Vector2(-13, -46)
	n.add_child(body)
	var boots := ColorRect.new()
	boots.color = Color(1.0, 0.69, 0.12)
	boots.size = Vector2(24, 8); boots.position = Vector2(-12, -6)
	n.add_child(boots)
	var head := ColorRect.new()
	head.color = Color(0.94, 0.79, 0.64)
	head.size = Vector2(22, 20); head.position = Vector2(-11, -64)
	n.add_child(head)
	var cap := ColorRect.new()
	cap.color = Color(0.54, 0.60, 0.31)
	cap.size = Vector2(26, 10); cap.position = Vector2(-13, -70)
	n.add_child(cap)
	return n


func _step_anim(dt: float) -> void:
	if _sprite == null:
		return
	var want: String = CLIP_FOR.get(kid.visual_state(), "idle")
	if not _frames.has(want):
		want = "idle"
	if want != _clip:
		_clip = want
		_clip_t = 0.0
	if not _frames.has(_clip):
		return
	_clip_t += dt
	var arr: Array = _frames[_clip]
	var i := int(_clip_t * CLIP_FPS) % arr.size()
	_sprite.texture = arr[i]


func _process(delta: float) -> void:
	if not _running or _shell.paused():
		return
	var steps := 0
	var acc := delta
	while acc >= DT and steps < 5:
		kid.step(DT, {
			"left": Input.is_action_pressed("move_left"),
			"right": Input.is_action_pressed("move_right"),
			"up": Input.is_action_pressed("move_up"),
			"down": Input.is_action_pressed("move_down"),
			"jump": Input.is_action_pressed("jump"),
			"action": Input.is_action_pressed("action"),
		})
		acc -= DT
		steps += 1

	var tx := kid.x + float(kid.facing) * CAM_LEAD
	var ty := maxf(kid.y + CAM_Y_OFF, CAM_FLOOR)
	_cam_x += (tx - _cam_x) * minf(1.0, 3.2 * delta)
	_cam_y += (ty - _cam_y) * minf(1.0, 2.6 * delta)
	# Never show past the ends of the room -- same clamp play.gd applies.
	var vp := get_viewport().get_visible_rect().size
	var half_w := (vp.x * 0.5) / _ppu(vp)
	_cam_x = clampf(_cam_x, half_w * 0.85, float(level.w) - half_w * 0.85)

	_diorama.step_fore(delta, kid.climbing)
	_step_anim(delta)
	_place()

	if _shell:
		_shell.show_touch(DisplayServer.is_touchscreen_available())
		_shell.set_hud({
			"bolts": 0, "bolts_total": 100, "golden": 0, "golden_total": 3,
			"address": level.slug.replace("eeri-", "eeri "),
		})


## Pixels per world unit on the PLAY PLANE (z = 0), from the same frustum the
## 3D camera used: half-height = CAM_Z * tan(fov/2).
func _ppu(vp: Vector2) -> float:
	return (vp.y * 0.5) / (CAM_Z * tan(deg_to_rad(CAM_FOV) * 0.5))


func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	_diorama.place(_cam_x, _cam_y, CAM_Z, vp)
	var ppu := _ppu(vp)
	_kid_node.position = Vector2(
		vp.x * 0.5 + (kid.x - _cam_x) * ppu,
		vp.y * 0.5 - (kid.y - _cam_y) * ppu)
	# EERI IS 1.62 TILES TALL -- the figure the 3D port measured off the
	# skeleton ("kid rig: skeleton span 0.849 units -> scaled to 1.620
	# tiles"). The bake fills a 256px cell with 2.2 world units of camera
	# height, so one baked pixel is 2.2/256 world units and the sprite must
	# be scaled by ppu * (2.2/256) to stand the right height in the set.
	var s := ppu * (2.2 / 256.0) if _sprite != null else ppu / 57.0
	_kid_node.scale = Vector2(s * float(kid.facing), s)
