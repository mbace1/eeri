class_name WorldDressing34
extends RefCounted
## Worlds 3 and 4 playfield dressing — ported from js/world34-dressing.js.
##
## Same discipline as world 2's: VISUAL ONLY, collision stays in the room
## grid, and one or two strong identifiers per screen rather than wallpaper.
##
## Everything here is drawn UNSHADED, like the browser build's
## MeshBasicMaterial panels. These are flat card silhouettes standing between
## the painted backdrop and the play lane; lighting them would do to them what
## it did to the backdrop — put a second light on a picture that already has
## its shading in it.

const ASSET := {
	"forestTunnel": "2d/world3_log_tunnel_lib_v1.webp",
	"forestClearing": "2d/world3_stump_clearing_lib_v1.webp",
	"root": "2d/f_root_v1.png",
	"worklamp": "2d/world4_worklamp_lib_v1.webp",
	"reel": "2d/world4_cable_reel_lib_v1.webp",
	"barriers": "2d/world4_barrier_lamps_lib_v1.webp",
}


static func _flat(col: Color, opacity := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, opacity)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opacity < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func panel(root: Node3D, x: float, y: float, w: float, h: float,
		col: Color, z := -1.1, opacity := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.material_override = _flat(col, opacity)
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func disc(root: Node3D, x: float, y: float, r: float, col: Color,
		z := -1.0, opacity := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 18
	mi.mesh = cm
	mi.material_override = _flat(col, opacity)
	mi.position = Vector3(x, y, z)
	mi.rotation.x = PI / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


## Hazard tape: alternating amber and ink cells.
static func stripe(root: Node3D, x: float, y: float, w: float, z := -0.72) -> void:
	var n: int = maxi(4, int(round(w / 1.05)))
	var cw := w / float(n)
	for i in n:
		panel(root, x - w / 2.0 + cw * (float(i) + 0.5), y, cw * 0.92, 0.34,
			Color("f2a51c") if i % 2 else Color("26221c"), z)


static func warm_window(root: Node3D, x: float, y: float, w: float, h: float,
		z := -0.70, glow := false) -> void:
	if glow:
		disc(root, x, y, maxf(w, h) * 1.25, Color("ffbd48"), z - 0.08, 0.07)
	panel(root, x, y, w + 0.35, h + 0.35, Color("243140"), z - 0.03)
	panel(root, x, y, w, h, Color("ffbd48"), z)


## A library cutout, sized from the image's own aspect so it is never squashed.
static func cutout(root: Node3D, key: String, x: float, y: float, h: float,
		z := -0.85, opacity := 1.0, flip := false) -> void:
	if not ASSET.has(key):
		return
	var tex := load("res://data/" + String(ASSET[key])) as Texture2D
	if tex == null:
		push_warning("world 3/4 dressing asset missing: %s" % key)
		return
	var sz := tex.get_size()
	if sz.y <= 0.0:
		return
	var w := h * (sz.x / sz.y)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, opacity)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(x, y, z)
	if flip:
		mi.scale.x = -1.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


# ---- WORLD 3: FOREST CLEARING / ROOT WORK --------------------------------

## THE CANOPY IS NOT A ROW OF CIRCLES, and this is the whole note from
## js/world34-dressing.js because it was the diagnosis of why World 3 read as
## green blobs. Fourteen flat discs of one green in one line, each spanning
## about a fifth of the screen at this depth — so the eye read circles, not
## trees. Making them smaller does not help: what gives a disc away is that
## its EDGE is a perfect arc all the way round in a single value.
##
## Two changes, both about breaking the arc: a tree is a CLUSTER of three or
## four overlapping lobes at different radii, so the silhouette has notches in
## it; and it has TWO values, a darker mass with a lighter crown up and to the
## left, which is §3.1's key-from-upper-left applied to a shape that had no
## shading in it at all. Plus a trunk under every second one — a canopy
## floating with nothing holding it up is the other half of why they read as
## decals.
static func _tree(root: Node3D, x: float, y: float, r: float, flip: bool) -> void:
	var DARKG := Color("22422f")
	var LIT := Color("2f5941")
	disc(root, x, y, r, DARKG, -1.56, 0.97)
	disc(root, x + r * (0.52 if flip else -0.52), y - r * 0.34, r * 0.78, DARKG, -1.56, 0.97)
	disc(root, x + r * (-0.44 if flip else 0.44), y - r * 0.46, r * 0.66, DARKG, -1.56, 0.97)
	disc(root, x - r * 0.3, y + r * 0.42, r * 0.62, LIT, -1.545, 0.97)
	disc(root, x + r * 0.16, y + r * 0.58, r * 0.4, LIT, -1.545, 0.97)


static func _world3_backdrop(root: Node3D) -> void:
	# Layered felt-card forest bands. Low contrast so platforms and Eeri stay
	# readable; the detailed cutouts sit nearer the playfield.
	panel(root, 48, 10.5, 124, 22, Color("355b47"), -1.70)
	panel(root, 48, 7.2, 124, 12, Color("416d4d"), -1.64)
	panel(root, 48, 4.0, 124, 2.5, Color("6b5438"), -1.58)

	var line := [[2, 12.4, 2.6], [9, 13.2, 3.0], [16, 12.0, 2.4], [24, 13.4, 2.9],
		[32, 12.2, 2.5], [40, 13.6, 3.1], [48, 12.6, 2.7], [56, 13.2, 2.9],
		[64, 12.1, 2.4], [72, 13.5, 3.0], [80, 12.4, 2.6], [88, 13.3, 2.8],
		[96, 12.2, 2.5], [104, 13.0, 2.7]]
	for i in line.size():
		var e = line[i]
		var x := float(e[0])
		var y := float(e[1])
		var r := float(e[2])
		if i % 2 == 0:
			panel(root, x + 0.2, y - r - 1.5, 0.5, 3.4, Color("2d2016"), -1.58)
		_tree(root, x, y, r, i % 2 == 1)


static func _timber_frame(root: Node3D, x: float, base: float, h: float,
		w := 5.2, z := -0.82) -> void:
	var dark := Color("6e4c32")
	var light := Color("a87c52")
	panel(root, x - w / 2.0, base + h / 2.0, 0.42, h, dark, z)
	panel(root, x + w / 2.0, base + h / 2.0, 0.42, h, dark, z)
	panel(root, x, base + h, w + 0.6, 0.46, light, z + 0.01)
	var brace := panel(root, x, base + h / 2.0, 0.30, sqrt(w * w + h * h), light, z + 0.02)
	brace.rotation.z = -atan2(w, h)


static func _log_beam(root: Node3D, x: float, y: float, w: float, z := -0.70) -> void:
	panel(root, x, y, w, 0.62, Color("7a5136"), z)
	panel(root, x, y + 0.16, w * 0.94, 0.18, Color("a87950"), z + 0.01)
	# rope wraps: it reads as intentionally placed timber, not another ledge
	for dx in [-w * 0.36, w * 0.36]:
		panel(root, x + dx, y, 0.18, 0.82, Color("c59a66"), z + 0.02)


static func _root_pocket(root: Node3D, x: float, y: float, flip := false, s := 1.0) -> void:
	cutout(root, "root", x, y, 2.7 * s, -0.74, 0.92, flip)
	disc(root, x + (-1.0 if flip else 1.0) * 0.8 * s, y + 0.9 * s,
		0.65 * s, Color("355b47"), -0.79, 0.95)


static func grove(root: Node3D, site := 6) -> int:
	_world3_backdrop(root)
	if site == 6:
		# 3-1 THE CUT BANK. A big early hollow establishes the forest at once,
		# then the level opens into a cut clearing around the machine. The root
		# pockets underline the two tarp beats without sitting on their collision.
		cutout(root, "forestTunnel", 17, 6.6, 8.2, -0.97, 0.96)
		_root_pocket(root, 31, 5.2, false, 1.05)
		_root_pocket(root, 61, 5.0, true, 0.95)
		cutout(root, "forestClearing", 75, 5.9, 7.5, -0.90, 0.98)
		_log_beam(root, 37, 8.1, 7.0, -0.88)
	elif site == 7:
		# 3-2 THE TIMBER LIFT — the hoists own the composition, so the timber
		# work sits BEHIND both of them and they read as purposeful forestry
		# machinery rather than generic elevators.
		cutout(root, "forestClearing", 8, 5.7, 6.3, -0.94, 0.94)
		_timber_frame(root, 15, 4.1, 6.0, 5.2, -0.84)
		_timber_frame(root, 31, 4.1, 7.3, 5.4, -0.84)
		_log_beam(root, 35, 10.1, 8.0, -0.80)
		_root_pocket(root, 51, 4.8, true, 0.85)
		cutout(root, "forestTunnel", 61, 6.5, 8.2, -0.96, 0.91, true)
		# the final chasm gets a felled-log promise before the machine solves it
		_log_beam(root, 75.5, 3.4, 9.4, -0.89)
		_timber_frame(root, 87, 4.0, 6.0, 4.8, -0.88)
	else:
		# 3-3 ROOT WORKS — denser clearing, the world's peak. The machine/wall
		# end sits in an obvious ROOT-CLEARING zone so the familiar crane
		# mechanic no longer reads as a random return to World 1.
		cutout(root, "forestTunnel", 12, 6.5, 8.4, -0.98, 0.94)
		_root_pocket(root, 27, 5.0, false, 1.15)
		_timber_frame(root, 31, 4.1, 7.4, 5.6, -0.85)
		cutout(root, "forestClearing", 49, 5.8, 7.5, -0.92, 0.95)
		_root_pocket(root, 61, 4.9, true, 1.10)
		for x in [72, 77, 83]:
			_root_pocket(root, float(x), 5.0, int(x) % 2 == 0, 1.0)
		cutout(root, "forestClearing", 89, 5.4, 6.1, -0.93, 0.88, true)
	return root.get_child_count()


# ---- WORLD 4: NIGHT WAREHOUSE / LOADING DOCK -----------------------------

static func _night_base(root: Node3D) -> void:
	panel(root, 48, 10.0, 124, 22, Color("14263c"), -1.72)
	panel(root, 48, 4.1, 124, 3.0, Color("101b28"), -1.62)
	# Soft-LOOKING but flat pools: scenery circles, not gameplay lights.
	for x in [18, 48, 78]:
		disc(root, float(x), 7.0, 6.0, Color("ffbd48"), -1.48, 0.055)


static func _loading_dock(root: Node3D, x0: float, width: float,
		blue: bool, bays: int) -> void:
	var wall := Color("214e78") if blue else Color("777d83")
	var trim := Color("173b5c") if blue else Color("666d73")
	panel(root, x0 + width / 2.0, 9.0, width, 10.8, wall, -1.22)
	panel(root, x0 + width / 2.0, 14.25, width, 0.42, Color("9aaab8"), -1.02)
	panel(root, x0 + width / 2.0, 4.1, width, 0.8, trim, -0.92)

	var bay_xs := [x0 + 15, x0 + 37, x0 + 59] if bays == 3 else [x0 + 18, x0 + 43]
	for x in bay_xs:
		panel(root, x, 7.0, 12.0, 5.8, Color("30363d"), -0.96)
		stripe(root, x, 10.05, 10.8, -0.76)
		warm_window(root, x - 2.0, 6.0, 1.6, 0.7, -0.69)
		warm_window(root, x + 2.0, 6.0, 1.6, 0.7, -0.69)

	# Raised office + yellow service ladder: the most useful readable feature
	# from the owner-supplied grey loading-dock sheet.
	var ox := x0 + width - 7.0
	panel(root, ox, 10.8, 13.0, 8.7, Color("365b77") if blue else Color("85888a"), -0.90)
	warm_window(root, ox - 2.5, 12.3, 4.3, 2.2, -0.67, true)
	panel(root, ox + 3.0, 12.0, 2.8, 4.0, Color("214e78"), -0.66)
	panel(root, ox, 8.0, 13.0, 0.28, Color("e3a51b"), -0.63)
	var y := 4.8
	while y < 9.3:
		panel(root, ox + 5.4, y, 2.0, 0.16, Color("e3a51b"), -0.61)
		y += 0.76
	panel(root, ox + 4.45, 7.0, 0.16, 5.5, Color("e3a51b"), -0.61)
	panel(root, ox + 6.35, 7.0, 0.16, 5.5, Color("e3a51b"), -0.61)


static func _dock_slab(root: Node3D, x: float, y: float, w: float, z := -0.60) -> void:
	panel(root, x, y, w, 0.72, Color("686d72"), z)
	panel(root, x, y + 0.32, w, 0.14, Color("9aaab8"), z + 0.01)
	stripe(root, x, y - 0.25, minf(w * 0.8, 8.5), z + 0.02)


static func _crate_stack(root: Node3D, x: float, y: float, n := 3, z := -0.54) -> void:
	for i in n:
		var dx := float(i % 2) * 1.15
		var dy := float(i / 2) * 0.92
		panel(root, x + dx, y + dy, 1.0, 0.82, Color("9d7048"), z)
		panel(root, x + dx, y + dy, 0.78, 0.06, Color("c49a66"), z + 0.01)


static func _service_deck(root: Node3D, x: float, y: float, w: float, z := -0.52) -> void:
	panel(root, x, y, w, 0.32, Color("7a8a9a"), z)
	for px in [x - w / 2.0, x + w / 2.0]:
		panel(root, px, y + 1.45, 0.16, 3.0, Color("e3a51b"), z + 0.01)
	panel(root, x, y + 2.85, w, 0.16, Color("e3a51b"), z + 0.01)


## Owner source: timber-card uprights, blue bolted braces, blue beam, orange
## trolley, twin chain drop and a black/yellow hook block.
static func _gantry(root: Node3D) -> void:
	var blue := Color("245985")
	var timber := Color("8a6242")
	var steel := Color("7a838a")
	for x in [55, 91]:
		var fx := float(x)
		panel(root, fx, 9.2, 1.55, 13.2, timber, -0.55)
		panel(root, fx, 8.8, 0.96, 10.9, blue, -0.51)
		var brace := panel(root, fx + (2.2 if fx < 70.0 else -2.2), 10.1, 0.48, 6.2, blue, -0.49)
		brace.rotation.z = -0.55 if fx < 70.0 else 0.55
	panel(root, 73, 14.8, 37.0, 1.35, blue, -0.52)
	panel(root, 73, 14.72, 33.5, 0.38, steel, -0.48)
	stripe(root, 73, 14.45, 23.0, -0.44)
	panel(root, 77, 13.4, 5.4, 1.9, Color("e97822"), -0.40)
	for x in [76.1, 77.9]:
		panel(root, x, 10.6, 0.21, 4.9, Color("282522"), -0.36)
	panel(root, 77, 8.0, 3.3, 2.8, Color("3b3c3d"), -0.34)
	stripe(root, 77, 8.45, 2.9, -0.30)
	warm_window(root, 59.5, 13.1, 1.1, 0.9, -0.31, true)


static func nightshift(root: Node3D, site := 9) -> int:
	_night_base(root)
	if site == 9:
		# 4-1 THE NIGHT SHIFT — loading dock + belt rhythm. Each conveyor
		# section sits visually in a loading lane instead of on anonymous
		# floor; these slabs are BEHIND the actual belt collision.
		_loading_dock(root, 6, 76, false, 2)
		for x in [17, 31, 51]:
			_dock_slab(root, float(x), 3.8, 8.0, -0.58)
		cutout(root, "barriers", 8, 4.3, 2.2, -0.53, 0.98)
		cutout(root, "reel", 63, 4.6, 2.6, -0.52, 0.98)
		cutout(root, "worklamp", 84, 5.8, 4.0, -0.50, 1.0)
		_crate_stack(root, 88, 4.4, 4, -0.56)
	elif site == 10:
		# 4-2 THE LIT SCAFFOLD. The room's vertical gameplay belongs to the
		# architecture: the two hoists service DECKS instead of floating in
		# front of a wall.
		_loading_dock(root, 3, 88, true, 3)
		_service_deck(root, 18, 7.7, 8.5, -0.51)
		_service_deck(root, 34, 10.2, 9.0, -0.51)
		_dock_slab(root, 51, 4.0, 11.0, -0.57)
		cutout(root, "worklamp", 10, 5.9, 4.1, -0.48, 1.0)
		cutout(root, "worklamp", 52, 6.0, 4.2, -0.48, 1.0)
		cutout(root, "barriers", 89, 4.3, 2.1, -0.49, 0.96)
		_crate_stack(root, 79, 4.4, 5, -0.56)
	else:
		# 4-3 LAST LIGHTS — the gantry owns the finale, so the warehouse is
		# quietened to leave a darker visual runway to the machine.
		_loading_dock(root, 2, 90, true, 3)
		panel(root, 48, 9.0, 98, 13.0, Color("0f1f30"), -0.72, 0.46)
		_dock_slab(root, 18, 3.9, 13.0, -0.58)
		_dock_slab(root, 36, 3.9, 11.0, -0.58)
		_gantry(root)
		cutout(root, "worklamp", 45, 5.8, 4.1, -0.24, 1.0)
		cutout(root, "barriers", 94, 4.4, 2.1, -0.23, 0.96)
		_crate_stack(root, 50, 4.3, 3, -0.25)
	return root.get_child_count()
