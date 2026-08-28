class_name ClockOut
extends RefCounted
## THE WORLD'S CLOCK-OUT BUILDING (DESIGN §4.3). Ported from js/clockout.js.
##
## THE HOLE THIS FILLS. Eeri is on a worksite, and twelve levels used to go
## past with nothing on that site ever getting finished. The golden bolts
## were a count, and a count that buys nothing is a chore with a sparkle on
## it. So they build the world's building: a world is three levels, each
## hides three, and the nine you find are the nine parts of the thing this
## world was working on. Nine of nine and the lights go on. Four of nine and
## it stands there four-ninths built, with the gaps visible.
##
## IT NEVER GATES ANYTHING. You clock out either way and the next world opens
## either way — the reward for finding the golden bolts is SEEING MORE OF THE
## THING, never being let past a door.
##
## WHY A MISSING PART IS A FRAME RATHER THAN A HOLE. An absent part left
## blank reads as a smaller building, not an unfinished one. A part not yet
## earned is drawn as its own STEEL OUTLINE — four uprights and a ring where
## the floor would be — which is what an unfinished storey looks like on a
## real site, and tells you exactly what is missing and where it would go.
##
## Nine parts stacked three by three: three storeys of three bays, filling
## from the BOTTOM LEFT the way a building actually goes up — never a fourth
## storey with no third — so a partial building is always a plausible object.

const PARTS := 9

## Body tones are literals rather than palette entries, same as js/clockout.js
## — a building is not part of the cast, and it is the one thing on screen
## that owns these four colours.
const BUILDING := {
	"groundworks": {"name": "the tower",     "body": "#cbb8a0", "w": 2.0, "h": 1.5,  "roof": "flat"},
	"pipeworks":   {"name": "the pumphouse", "body": "#9fb0bc", "w": 2.4, "h": 1.25, "roof": "flat"},
	"grove":       {"name": "the lodge",     "body": "#a8794c", "w": 2.3, "h": 1.3,  "roof": "pitch"},
	"nightshift":  {"name": "the depot",     "body": "#8e97a6", "w": 2.5, "h": 1.2,  "roof": "flat"},
}

const PAL_INK := Color("#1a1410")
const PAL_STEEL_1 := Color("#5f7080")


static func _mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## A detail map multiplied onto a palette colour -- the same rule play.gd's
## terrain materials follow (assets/manifest.json's own "textures" table).
static func _mat(tint: Color, tex_name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var e: Dictionary = AssetRegistry.manifest.get("textures", {}).get(tex_name, {})
	if String(e.get("status", "")) == "live":
		var tex := load("res://data/" + String(e.get("file", ""))) as Texture2D
		if tex != null:
			m.albedo_texture = tex
			m.uv1_scale = Vector3.ONE
	m.albedo_color = tint
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## A LIT WINDOW IS NOT A LIGHT. ART_BRIEF §3.4 forbids a post stack and there
## is no bloom to catch a glow, so the window IS the lamp: an unlit material
## at full warmth, exactly the trick the machine beacon (Machine's own
## headlamp quad) already uses.
static func _unlit(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


static func _box(parent: Node3D, mat: Material, w: float, h: float, d: float,
		x: float, y: float, z: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(x, y, z)
	parent.add_child(mi)


## `found` is 0..9. Clamped rather than trusted -- the count is summed across
## three levels and a replayed level must not be able to build a tenth storey.
## Returns {root: Node3D, name: String, got: int, parts: int}.
static func build(world: String, found: float) -> Dictionary:
	var spec: Dictionary = BUILDING.get(world, BUILDING["groundworks"])
	var got: int = clampi(int(round(found)), 0, PARTS)
	var w: float = spec["w"]
	var h: float = spec["h"]

	var root := Node3D.new()
	root.name = "ClockOutBuilding"
	var body := _mat(Color(String(spec["body"])), "card")
	var dark := _mat(_mix(Color(String(spec["body"])), PAL_INK, 0.34), "card")
	var steel := _mat(PAL_STEEL_1, "balsa")
	var lit_glass := _unlit(Color("#ffdb8a"))
	var dark_glass := _unlit(Color("#2b3340"))

	# the pad it stands on -- a building with no ground under it floats
	_box(root, dark, w * 3.0 + 0.5, 0.18, 1.7, 0.0, 0.09)

	for i in PARTS:
		var bay: int = i % 3
		var storey: int = int(i / 3)
		var x: float = float(bay - 1) * w
		var y: float = 0.18 + float(storey) * h + h * 0.5
		if i < got:
			_box(root, body, w * 0.96, h * 0.96, 1.5, x, y)
			_box(root, dark, w * 0.99, h * 0.1, 1.54, x, y + h * 0.46)   # floor band
			var g := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(w * 0.42, h * 0.4)
			g.mesh = qm
			g.material_override = lit_glass if got == PARTS else dark_glass
			g.position = Vector3(x, y, 0.76)
			root.add_child(g)
		else:
			# NOT YET BUILT: the frame it will stand in. Four uprights and a
			# ring, in steel, so the gap is a shape you can point at.
			for dx in [-w * 0.46, w * 0.46]:
				for dz in [-0.7, 0.7]:
					_box(root, steel, 0.1, h * 0.96, 0.1, x + dx, y, dz)
			for dz in [-0.7, 0.7]:
				_box(root, steel, w * 0.96, 0.08, 0.1, x, y + h * 0.46, dz)
			for dx in [-w * 0.46, w * 0.46]:
				_box(root, steel, 0.1, 0.08, 1.5, x + dx, y + h * 0.46, 0.0)

	# The roof only goes on a FINISHED building -- the strongest reading of
	# "finished" available without a word on screen: an open top is a site,
	# a closed top is a building.
	if got == PARTS:
		var top: float = 0.18 + 3.0 * h
		if String(spec["roof"]) == "pitch":
			# THREE.ConeGeometry(w, h, 4) is a four-sided pyramid -- the exact
			# same shape a CylinderMesh gives with top_radius 0 and four
			# radial segments.
			var r := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = w * 2.1
			cm.height = h * 1.1
			cm.radial_segments = 4
			r.mesh = cm
			r.material_override = dark
			r.rotation.y = PI / 4.0
			r.position = Vector3(0.0, top + h * 0.55, 0.0)
			root.add_child(r)
		else:
			_box(root, dark, w * 3.1, 0.22, 1.66, 0.0, top + 0.11)
			_box(root, steel, 0.12, 0.9, 0.12, w * 1.1, top + 0.66, 0.0)   # the aerial
			var lamp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.24
			lamp.mesh = sm
			lamp.material_override = _unlit(Color("#ff6a4a"))          # its red light
			lamp.position = Vector3(w * 1.1, top + 1.14, 0.0)
			root.add_child(lamp)

	return {"root": root, "name": String(spec["name"]), "got": got, "parts": PARTS}
