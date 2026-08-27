extends SceneTree
## BAKE THE 3D CAST INTO 2D SPRITE SHEETS.
##
## Runs on DESKTOP, where Godot's 3D renderer works, and writes PNGs the web
## build draws with the 2D pipeline -- which is the only pipeline the owner's
## phone will render (Pixel 10, PowerVR D-Series DXT-48-1536; see
## EERI_GODOT_HANDOFF §14 for the thirty-five builds that established that,
## and godotengine/godot#121005 and #113911 for the same GPU misbehaving in
## Godot's compatibility renderer with no error reported).
##
## THIS IS NOT A COMPROMISE OF THE ART. ART_BRIEF §3.4 already asks for flat
## unlit cutouts with the shading painted in and "no cast shadow maps", and
## the camera is a FIXED side-on shot (play.gd's CAM_FOV 21 at z 34, axis
## aligned, "even a slight tilt turns the ground into a receding plane"). A
## fixed camera plus flat lighting is precisely the case where pre-rendered
## sprites are indistinguishable from live 3D -- it is how the genre's own
## reference art was made before real-time 3D was cheap.
##
## Run:
##   godot --path godot --script res://tools/bake_sprites.gd
## (NOT --headless: this needs a real GPU to render into.)
##
## Writes res://data/sprites/<model>_<clip>_<NN>.png plus a .json manifest
## naming the frames, which scenes/play2d.gd loads.

const OUT_DIR := "res://data/sprites"
## Frames per animation clip. Eight reads as animation at 12fps playback
## without turning the pack into a flipbook the download cannot carry.
const FRAMES := 8
const FRAME_W := 256
const FRAME_H := 256

## model id -> {path, clips}. Clip names are the ones assets/manifest.json
## declares for the Meshy rig; the kid carries fourteen and only the ones the
## 2D build actually shows are baked.
const CAST := {
	"eeri": {
		"path": "res://data/3d/eeri_v5.glb",
		"clips": ["idle", "walk", "run", "jump", "fall", "climb"],
	},
}


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("bake_sprites: needs a real GPU -- run WITHOUT --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var manifest := {}
	for id in CAST.keys():
		var made: Dictionary = await _bake(id, CAST[id])
		if not made.is_empty():
			manifest[id] = made
	var f := FileAccess.open(OUT_DIR + "/sprites.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()
		print("wrote %s/sprites.json" % OUT_DIR)
	quit(0)


func _bake(id: String, spec: Dictionary) -> Dictionary:
	var path := String(spec["path"])
	if not ResourceLoader.exists(path):
		printerr("  %s: missing %s" % [id, path])
		return {}
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("  %s: not a scene" % id)
		return {}

	# A viewport of our own so the bake is independent of the editor window.
	var vp := SubViewport.new()
	vp.size = Vector2i(FRAME_W, FRAME_H)
	vp.transparent_bg = true            # cutouts, so the lanes show through
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# THE SAME LIGHT THE 3D PORT USED, so the bake matches what the port
	# looked like on a machine where it rendered: one soft key from upper
	# left, no shadow maps (ART_BRIEF forbids them), gentle ambient.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.68, 0.85)
	e.ambient_light_energy = 0.30
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = false
	vp.add_child(sun)

	var rig := packed.instantiate()
	vp.add_child(rig)

	# FRAMED SIDE-ON, matching play.gd's axis-aligned camera. Orthographic so
	# a sprite scales linearly with distance in the 2D renderer instead of
	# carrying a baked perspective that would fight the lane parallax.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2
	cam.position = Vector3(0, 0.85, 4.0)
	cam.current = true
	vp.add_child(cam)

	var anim := _find_anim(rig)
	var out := {"w": FRAME_W, "h": FRAME_H, "clips": {}}
	for clip in spec["clips"]:
		if anim == null or not anim.has_animation(clip):
			continue
		var a := anim.get_animation(clip)
		var names: Array[String] = []
		for i in FRAMES:
			var t := (float(i) / float(FRAMES)) * a.length
			anim.play(clip)
			anim.seek(t, true)
			# Two frames: one for the pose to apply, one for it to render.
			await process_frame
			await process_frame
			var img: Image = vp.get_texture().get_image()
			img = _anchor(img)
			var name := "%s_%s_%02d.png" % [id, clip, i]
			img.save_png(OUT_DIR + "/" + name)
			names.append(name)
		out["clips"][clip] = names
		print("  %s/%s: %d frames" % [id, clip, names.size()])
	vp.queue_free()
	return out


## ANCHOR EACH FRAME ON ITS OWN FOOTPRINT.
##
## The owner reported the kid "twitching in place", and the frames show why:
## across the idle clip the figure's horizontal centre swings from 130.5 to
## 113 inside a 256px cell -- a 17px slide. In 3D that is the animation's own
## weight shift and reads as life; as a sequence of sprites pinned to one
## world point it reads as jitter, because the world point stops meaning the
## same part of him from frame to frame.
##
## So every frame is recentred on the horizontal middle of its own opaque
## bounding box, while the BOTTOM is left exactly where it is -- his feet are
## what stand on the ground, and moving those would make him bob instead.
func _anchor(src: Image) -> Image:
	var used := src.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return src
	var want_cx := float(src.get_width()) * 0.5
	var have_cx := float(used.position.x) + float(used.size.x) * 0.5
	var dx := int(round(want_cx - have_cx))
	if dx == 0:
		return src
	var out := Image.create_empty(src.get_width(), src.get_height(), false, src.get_format())
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(src, used, Vector2i(used.position.x + dx, used.position.y))
	return out


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f != null:
			return f
	return null
