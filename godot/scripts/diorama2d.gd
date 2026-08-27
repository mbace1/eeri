class_name Diorama2D
extends CanvasLayer
## THE DIORAMA, DRAWN BY THE 2D PIPELINE.
##
## WHY THIS EXISTS. Thirty-two builds established, on the owner's phone
## (PowerVR D-Series via ANGLE), that EVERY spatial path renders black --
## direct, inside a SubViewport shaped exactly like piritori-eden's, through a
## stock material, a four-line hand-written shader, emission, with explicit
## exposure, with ACES tonemapping, as a Sprite3D, textured or bare. And that
## the 2D pipeline renders THIS GAME'S OWN PAINTED ART correctly: the v30
## bisect read 75BCEA off res://data/2d/day_sky_v2.webp drawn as a Sprite2D.
##
## So the port stops asking the device for 3D. The art was never really 3D
## anyway -- ART_BRIEF §3.4 calls for flat unlit cutouts with the shading
## painted in, the browser build draws them on plain unlit planes, and
## assets/README.md's own table describes the lanes as paintings at fixed
## world rects. A perspective camera was only ever doing the parallax
## arithmetic for us.
##
## SO THIS DOES THAT ARITHMETIC EXPLICITLY. For a lane at depth d in front of
## a camera with vertical FOV f, the on-screen scale is
##
##     ppu = (viewport_height / 2) / (d * tan(f / 2))
##
## and a lane's screen position follows from where the camera is. Same
## numbers the 3D camera produced, same LAYER_RECTS from js/layers.js, same
## draw order -- but through the one pipeline this device will actually draw.
##
## The result is not a downgrade or a stand-in: it is the browser build's own
## model of the world (five painted planes at authored depths) expressed
## directly instead of via a camera that cannot run here.

## Lane -> {z, x0, x1, y0, y1}. Copied from scripts/diorama.gd, which took
## them from js/layers.js LAYER_RECTS. One source, three renderers.
const RECTS := {
	"sky":     {"z": -48.0, "x0": -60.0, "x1": 170.0, "y0": -6.0, "y1": 40.0},
	"skyline": {"z": -30.0, "x0": -30.0, "x1": 130.0, "y0": 0.0, "y1": 30.0},
	"far":     {"z": -14.0, "x0": -20.0, "x1": 120.0, "y0": 0.0, "y1": 20.0},
	"mid":     {"z": -6.0,  "x0": -12.0, "x1": 110.0, "y0": 0.0, "y1": 14.0},
	"near":    {"z": -2.0,  "x0": -8.0,  "x1": 104.0, "y0": 0.0, "y1": 8.0},
	"fore":    {"z": 2.2,   "x0": -8.0,  "x1": 104.0, "y0": -2.0, "y1": 14.0},
}
## Back to front; the cutouts are alpha-blended so order is load-bearing.
const ORDER := ["sky", "skyline", "far", "mid", "near", "fore"]

## Matches scenes/play.gd's camera so the framing is identical to the 3D port.
const CAM_FOV := 21.0
const WORLDS := ["groundworks", "pipeworks", "grove", "nightshift"]

var _lanes := {}          # lane -> Array[Sprite2D], left to right
var _fore: Array[Sprite2D] = []
var _fore_opacity := 1.0
var _built := false


static func world_for(level_index: int) -> String:
	return WORLDS[clampi(level_index / 3, 0, WORLDS.size() - 1)]


func build(world: String) -> int:
	for c in get_children():
		c.queue_free()
	_lanes.clear()
	_fore.clear()
	var set: Dictionary = AssetRegistry.manifest.get("layers", {}).get(world, {})
	var mounted := 0
	for lane in ORDER:
		if not set.has(lane):
			continue
		var e = set[lane]
		if String(e.get("status", "")) != "live":
			continue
		# THE CLOSE LANES ARE TILED and it is not optional -- assets/README.md
		# caps a texture at 4096 and mid/near therefore ship as two tiles laid
		# left to right across the rect. Same rule here as in the 3D lane.
		var files: Array = []
		var f = e.get("file", "")
		if f is Array:
			files = f
		elif String(f) != "":
			files = [String(f)]
		var made := _mount(lane, files)
		if made:
			mounted += 1
	_built = mounted > 0
	return mounted


func _mount(lane: String, files: Array) -> bool:
	if files.is_empty():
		return false
	var sprites: Array[Sprite2D] = []
	for path in files:
		var t := load("res://data/" + String(path)) as Texture2D
		if t == null:
			push_warning("layer %s: missing %s" % [lane, path])
			continue
		var sp := Sprite2D.new()
		sp.texture = t
		sp.centered = true
		# Nearest would crawl on a painting magnified past its stored
		# resolution; the shipped art is soft craft render and wants the
		# filtering the browser build's LinearFilter also uses.
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sp)
		sprites.append(sp)
	if sprites.is_empty():
		return false
	_lanes[lane] = sprites
	if lane == "fore":
		_fore = sprites
	return true


## Reposition every lane for a camera at (cam_x, cam_y) in world units.
## Called once per frame from the play scene -- cheap: a handful of Sprite2D
## transforms, no allocation.
func place(cam_x: float, cam_y: float, cam_z: float, vp: Vector2) -> void:
	if not _built or vp.y <= 0.0:
		return
	var half_tan := tan(deg_to_rad(CAM_FOV) * 0.5)
	for lane in ORDER:
		if not _lanes.has(lane):
			continue
		var r: Dictionary = RECTS[lane]
		# Depth from the camera to this lane's plane. Guarded because the fore
		# lane sits at z=+2.2 and a camera could in principle be pushed past
		# it; a negative depth would mirror the painting.
		var d: float = maxf(0.5, cam_z - float(r["z"]))
		var ppu: float = (vp.y * 0.5) / (d * half_tan)
		var sprites: Array = _lanes[lane]
		var n := sprites.size()
		var span: float = float(r["x1"]) - float(r["x0"])
		var tile_w: float = span / float(n)
		var lane_h: float = float(r["y1"]) - float(r["y0"])
		for i in n:
			var sp: Sprite2D = sprites[i]
			var tex := sp.texture
			if tex == null:
				continue
			var ts := tex.get_size()
			if ts.x <= 0.0 or ts.y <= 0.0:
				continue
			# Scale the painting so it covers exactly its authored world rect.
			sp.scale = Vector2((tile_w * ppu) / ts.x, (lane_h * ppu) / ts.y)
			var cx: float = float(r["x0"]) + tile_w * (float(i) + 0.5)
			var cy: float = float(r["y0"]) + lane_h * 0.5
			sp.position = Vector2(
				vp.x * 0.5 + (cx - cam_x) * ppu,
				vp.y * 0.5 - (cy - cam_y) * ppu)


## js/main.js fades the foreground while climbing so the player is never lost
## behind an occluder. Ported here unchanged in spirit.
func step_fore(dt: float, climbing: bool) -> void:
	var want := 0.24 if climbing else 1.0
	_fore_opacity += (want - _fore_opacity) * minf(1.0, 6.0 * dt)
	for sp in _fore:
		sp.modulate.a = _fore_opacity
