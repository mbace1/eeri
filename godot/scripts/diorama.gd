class_name Diorama
extends Node3D
## The five-lane cutout diorama — the world behind and in front of the play
## plane, built from the shipped craft art in assets/2d.
##
## The rects, z depths and tile counts are the contract in
## `assets/README.md` and `js/layers.js`, not choices made here. Painting a
## layer to the wrong rect does not throw; it stretches, and the diorama
## quietly stops lining up with the ground the player stands on.
##
## WHAT IS DELIBERATELY DIFFERENT FROM THE BROWSER BUILD, and it is the one
## place this port is allowed to be better (GODOT_PORT_ANALYSIS.md §3.1):
##
##   The browser build renders UNLIT and bakes a depth haze into each
##   painting (LAYER_TINT: skyline 0.58 ... fore 0). It has to — three.js
##   with MeshBasicMaterial has no light to respond to.
##
##   ART_BRIEF's 80% reference is Yoshi's Crafted World, whose whole
##   register is "toy-diorama materiality, visible hand-built set, SOFT
##   FRIENDLY LIGHT". Soft friendly light is exactly what a flat unlit stack
##   cannot do, so here the tint is applied as real distance FOG instead:
##   same colour relationship, but it responds to the light rather than
##   being painted into the picture.
##
##   The paintings still carry their own baked tint — they are the shipped
##   art and repainting them is the Art lane's call, not the port's — so the
##   fog is kept SUBTLE and additive. If the two ever fight, the fix is to
##   ask Art for untinted plates, never to fight the art from code.

## Lane -> {z, x0, x1, y0, y1}, from js/layers.js LAYER_RECTS.
const RECTS := {
	"sky":     {"z": -48.0, "x0": -60.0, "x1": 170.0, "y0": -6.0, "y1": 40.0},
	"skyline": {"z": -30.0, "x0": -30.0, "x1": 130.0, "y0": 0.0, "y1": 30.0},
	"far":     {"z": -14.0, "x0": -20.0, "x1": 120.0, "y0": 0.0, "y1": 20.0},
	"mid":     {"z": -6.0,  "x0": -12.0, "x1": 110.0, "y0": 0.0, "y1": 14.0},
	"near":    {"z": -2.0,  "x0": -8.0,  "x1": 104.0, "y0": 0.0, "y1": 8.0},
	# the occluder lane: tall enough to be CROPPED top and bottom, which is
	# the whole point of a foreground
	"fore":    {"z": 2.2,   "x0": -8.0,  "x1": 104.0, "y0": -2.0, "y1": 14.0},
}
## Back to front. Draw order matters for the alpha-blended cutouts.
const ORDER := ["sky", "skyline", "far", "mid", "near", "fore"]

var _built := false
## The FORE lane's own mesh instances, so it can fade independently of the
## rest of the set.
var _fore_meshes: Array[MeshInstance3D] = []
var _fore_opacity := 1.0


## `world` is a manifest layer-set id: groundworks / pipeworks / grove /
## nightshift. Returns how many lanes actually mounted.
func build(world: String) -> int:
	for c in get_children():
		c.queue_free()
	_built = false

	var sets: Dictionary = AssetRegistry.manifest.get("layers", {})
	if not sets.has(world):
		push_warning("no layer set '%s' in the manifest" % world)
		return 0
	var set: Dictionary = sets[world]

	var mounted := 0
	for lane in ORDER:
		if not set.has(lane):
			continue
		var e = set[lane]
		if typeof(e) != TYPE_DICTIONARY or e.get("status", "") != "live":
			continue
		var files: Array = []
		if e.has("files"):
			files = e["files"]
		elif e.has("file"):
			files = [e["file"]]
		if files.is_empty():
			continue
		var made := _mount(lane, files)
		if made:
			mounted += 1
		if lane == "fore":
			_fore_meshes = _last_mounted.duplicate()
	_built = mounted > 0
	return mounted


## THE CLOSE LANES ARE TILED, and it is not optional. assets/README.md:
## 4096 is the texture size a modest phone GPU is guaranteed to accept, and
## a layer that fails to upload is not a soft layer, it is a MISSING one.
## Over a 112-unit rect one texture can only carry 36.6 px/unit, so `mid` and
## `near` ship as two tiles each, laid left to right across the rect.
var _last_mounted: Array[MeshInstance3D] = []


## THE FOREGROUND STANDS ASIDE FOR A CLIMB (owner, 2026-08-21: "some
## foreground assets block view of ladders"). A climb is the one move that
## puts the player behind the fore lane for seconds at a time, standing
## still — everywhere else you are moving and a beat of occlusion is depth
## rather than a problem. Faded rather than cut: a hole punched in the art
## per ladder would be a second set of coordinates to keep in step with the
## levels, and this project has written down what happens when one number
## lives in two files.
func step_fore(dt: float, climbing: bool) -> void:
	var target := 0.24 if climbing else 1.0
	_fore_opacity += (target - _fore_opacity) * minf(1.0, 10.0 * dt)
	for m in _fore_meshes:
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = _fore_opacity


func _mount(lane: String, files: Array) -> bool:
	_last_mounted = []
	var r: Dictionary = RECTS[lane]
	var w: float = r["x1"] - r["x0"]
	var h: float = r["y1"] - r["y0"]
	var n := files.size()
	var tile_w := w / float(n)
	var any := false

	for i in n:
		var path := "res://data/" + String(files[i])
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("layer %s: missing %s" % [lane, path])
			continue
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(tile_w, h)
		mi.mesh = qm

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Cutout craft shapes read as PAPER, not plastic: no specular, and
		# lit softly rather than shaded.
		mat.roughness = 1.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		# UNSHADED, ALL OF IT — and this is a decision, not a shortcut.
		#
		# The first cut lit these planes with the same key light the actors
		# get, and it bleached the whole set: these paintings already have
		# their shading painted IN (key light upper-left, per assets/README.md)
		# plus a depth tint baked per lane, so a second light lands on top of
		# a picture that has already been lit and washes it out.
		#
		# So the split is: the PAINTED SET stays exactly as authored, and the
		# real light falls only on what is genuinely 3D — the kid, the
		# machines, the tiles. That is also how a Crafted World shot actually
		# reads: lit figures with contact shadows standing in a built set,
		# not a set pretending to be lit from the same lamp.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# A cutout has hard edges; keep them hard rather than letting the
		# mip chain soften a deliberately torn silhouette.
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mi.material_override = mat

		mi.position = Vector3(
			r["x0"] + tile_w * (float(i) + 0.5),
			r["y0"] + h * 0.5,
			r["z"])
		# Never cast: a backdrop plane throwing a shadow across the playfield
		# is the single most obvious way to break a diorama.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_last_mounted.append(mi)
		any = true
	return any


func built() -> bool:
	return _built


## Which manifest layer set a level index uses — three levels to a world
## (DESIGN §4.1), in the order the worlds are named in §4.2.
static func world_for(level_index: int) -> String:
	const SETS := ["groundworks", "pipeworks", "grove", "nightshift"]
	var w: int = clampi(level_index / 3, 0, SETS.size() - 1)
	return SETS[w]
