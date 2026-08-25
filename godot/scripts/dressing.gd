class_name Dressing
extends Node3D
## The per-world PLAYFIELD dressing — ported from js/world2-dressing.js and
## js/world34-dressing.js.
##
## This is the layer between the painted backdrop and the play lane, and it is
## what stops worlds 2, 3 and 4 reading as world 1 with a different wallpaper.
## js/world2-dressing.js states the discipline and it is kept here:
##
##   "Deliberately VISUAL ONLY. Collision stays in the room grid."
##   "One or two strong identifiers per screen, never wallpaper."
##
## So nothing in this file is ever solid, ever collides, or ever appears in a
## reachability check. If a piece of dressing looks like a platform, that is a
## bug — collision never comes from artwork.

## Behind the actors and the collision meshes.
const BACK_Z := -0.72
## A few cut-face assets sit just in FRONT of the earth at y<4, where they
## cannot hide gameplay.
const FACE_Z := 0.86

# js/palette.js PAL
const STEEL := [Color("4a5a6a"), Color("5f7080"), Color("7a8a9a"), Color("9aaab8")]
const SKY_PALE := Color("c2e2f4")
const INK := Color("1a1410")
const MACHINE := Color("ffb01f")
const MACHINE_DK := Color("d88c12")
const EARTH := [Color("6e4c32"), Color("8a6242"), Color("a87c52"), Color("c49a66")]
const WATER_DK := Color("2a7f9e")
const DARK := Color("26221c")

var _mats := {}


## `world` is the manifest layer-set id; `site` is the level INDEX, because
## worlds 3 and 4 dress differently level by level — js/world34-dressing.js
## keys off the site, not the world.
func build(world: String, site := 0) -> int:
	for c in get_children():
		c.queue_free()
	match world:
		"pipeworks":
			return _pipeworks()
		"grove":
			return WorldDressing34.grove(self, site)
		"nightshift":
			return WorldDressing34.nightshift(self, site)
		_:
			# Groundworks carries no dressing group in the browser build
			# either — world 1 IS the baseline the others depart from.
			return 0


# ---- materials -----------------------------------------------------------
# `craftMat(colour, 'balsa'|'card'|'felt')` in the browser build tints a
# shared craft grain map. The grains are live textures in the manifest, so the
# same trick works here: the texture is the GRAIN and the colour modulates it.
func _mat(c: Color, grain := "balsa") -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), grain]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var entry: Dictionary = AssetRegistry.manifest.get("textures", {}).get(grain, {})
	if String(entry.get("status", "")) == "live":
		var t := load("res://data/" + String(entry.get("file", ""))) as Texture2D
		if t:
			m.albedo_texture = t
	_mats[key] = m
	return m


func _box(w: float, h: float, d: float, m: Material, x: float, y: float, z := BACK_Z) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	# DRESSING NEVER CASTS. A prop behind the lane throwing a shadow across
	# the playfield reads as an object you could stand on.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ring(r: float, t: float, m: Material, x: float, y: float, z := BACK_Z + 0.1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.01, r - t)
	tm.outer_radius = r
	mi.mesh = tm
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	mi.rotation.x = PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _disc(r: float, m: Material, x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.04
	mi.mesh = cm
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	mi.rotation.x = PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A live cut-face asset (f_pipe, f_root, f_brick...) on a quad. These are the
## real production cutouts, not redraws — the browser build is explicit that
## it uses the shipped asset here rather than a palette-tinted substitute.
func _cut(key: String, w: float, h: float, x: float, y: float, z := FACE_Z, rot := 0.0) -> void:
	var entry: Dictionary = AssetRegistry.manifest.get("textures", {}).get(key, {})
	if String(entry.get("status", "")) != "live":
		return
	var t := load("res://data/" + String(entry.get("file", ""))) as Texture2D
	if t == null:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	mi.rotation.z = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---- WORLD 2: PIPEWORKS --------------------------------------------------
# Service walls, pipe racks, drainage pieces, pump/valve hardware and one high
# walkway — the modular vocabulary from art-src/world-2-library.
func _pipeworks() -> int:
	var steel := _mat(STEEL[2].lerp(SKY_PALE, 0.12))
	var steel_dark := _mat(STEEL[0].lerp(INK, 0.16))
	var yellow := _mat(MACHINE)
	var yellow_dark := _mat(MACHINE_DK)
	var card := _mat(EARTH[2].lerp(SKY_PALE, 0.08), "card")
	var water := _mat(WATER_DK, "felt")
	var pump_blue := _mat(WATER_DK.lerp(STEEL[2], 0.35))
	var ink := _mat(DARK)

	var pipe_mouth := func(x: float, y: float, r := 0.62) -> void:
		_ring(r, 0.18, steel, x, y)
		_disc(maxf(0.05, r - 0.2), ink, x, y, BACK_Z + 0.08)

	var pipe_stack := func(x: float, y: float, s := 1.0) -> void:
		# Strapped triangular stack: the World-2 yard silhouette, kept low and
		# behind the lane.
		for p in [[0.0, 0.0], [1.18, 0.0], [2.36, 0.0], [0.59, 1.02], [1.77, 1.02]]:
			pipe_mouth.call(x + p[0] * s, y + p[1] * s, 0.56 * s)
		_box(3.15 * s, 0.14, 0.14, yellow_dark, x + 1.18 * s, y + 0.5 * s, BACK_Z + 0.2)

	var service_wall := func(x: float, w: float, h: float) -> void:
		# Broad card/cement connector with visible steel structural straps.
		_box(w, h, 0.24, card, x + w / 2.0, 3.55 + h / 2.0)
		var sx := x + 0.7
		while sx < x + w:
			_box(0.18, h + 0.25, 0.12, steel_dark, sx, 3.55 + h / 2.0, BACK_Z + 0.08)
			sx += 2.1

	var valve := func(x: float, y: float, r := 0.48) -> void:
		_ring(r, 0.11, yellow, x, y, BACK_Z + 0.24)
		var a := 0.0
		while a < PI:
			var spoke := _box(r * 1.55, 0.08, 0.08, yellow_dark, x, y, BACK_Z + 0.23)
			spoke.rotation.z = a
			a += PI / 4.0
		_disc(0.12, ink, x, y, BACK_Z + 0.26)

	var standpipe := func(x: float, h := 2.5) -> void:
		_box(0.42, h, 0.42, steel, x, 3.75 + h / 2.0)
		_box(1.05, 0.38, 0.42, steel_dark, x + 0.31, 3.75 + h - 0.22)
		valve.call(x, 3.75 + h * 0.66, 0.44)

	var pump_platform := func(x: float) -> void:
		# Readable industrial punctuation, not an interactable machine — the
		# real ride has to stay visually dominant.
		_box(4.6, 0.28, 1.0, steel_dark, x + 2.3, 4.02)
		_box(1.45, 1.65, 0.8, pump_blue, x + 1.1, 4.95)
		_box(0.9, 0.28, 0.82, yellow, x + 1.1, 5.64, BACK_Z + 0.05)
		_ring(0.26, 0.07, steel_dark, x + 1.1, 5.13, BACK_Z + 0.3)      # gauge
		_box(1.8, 0.34, 0.34, steel, x + 3.15, 4.82)                    # manifold
		valve.call(x + 3.65, 5.12, 0.38)
		var hose := _ring(0.58, 0.09, water, x + 2.7, 4.25, BACK_Z + 0.12)
		hose.scale.z = 0.55                                             # folded flat

	var walkway := func(x: float, w: float, y: float) -> void:
		# HIGH CROSSING ONLY. It frames the lane without pretending to be a
		# platform, because collision never comes from artwork.
		_box(w, 0.26, 0.7, steel_dark, x + w / 2.0, y)
		var px := x + 0.35
		while px < x + w:
			_box(0.1, 1.2, 0.12, yellow_dark, px, y + 0.72, BACK_Z + 0.02)
			px += 1.55
		_box(w, 0.1, 0.12, yellow, x + w / 2.0, y + 1.28, BACK_Z + 0.02)

	# OPENING — pipe yard identity before the first hazard.
	pipe_stack.call(7.2, 3.65, 0.82)
	_cut("f_pipe", 1.9 * 1.15, 0.8 * 1.15, 13.0, 2.55, FACE_Z, -0.08)

	# TRENCH / SERVICE WALL — a strong built connector with one valve, then
	# negative space around the actual shallow/deep-water reads.
	service_wall.call(21.0, 6.8, 2.5)
	pipe_mouth.call(24.4, 5.0, 0.82)
	standpipe.call(29.6, 2.15)

	# MIDPOINT — pump hardware sells the treatment-plant fantasy while the
	# checkpoint and traversal stay unobscured in front.
	pump_platform.call(42.0)
	_cut("f_pipe", 1.9 * 0.9, 0.8 * 0.9, 51.5, 2.2, FACE_Z, 0.12)

	# BACK HALF — elevated infrastructure frames the pipe/hoist sequences.
	walkway.call(57.0, 8.2, 9.6)
	pipe_stack.call(69.2, 3.55, 0.72)
	standpipe.call(76.4, 2.8)

	# FINAL SCREEN — one large junction shape, leaving the ride/wall/flag
	# silhouette clear at play height.
	service_wall.call(85.5, 6.0, 2.0)
	pipe_mouth.call(87.2, 4.95, 0.72)
	pipe_mouth.call(90.0, 4.95, 0.72)
	valve.call(93.0, 5.35, 0.52)
	return get_child_count()


