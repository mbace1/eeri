class_name Craft
extends RefCounted
## The palette and the box-builder the code-drawn models share.
##
## The robots, the bank, the wall and the girder are all `"placeholder"` in
## assets/manifest.json — meaning the BROWSER BUILD draws them in code too, in
## js/robots.js buildRobot() and js/pieces.js. The .glb files exist on disk but
## are not approved through the seam, so using them here would put the Godot
## build AHEAD of the browser one and break the very manifest contract
## AssetRegistry exists to honour. Parity means porting the code, not
## promoting the asset.
##
## Colours are js/palette.js PAL, verbatim.

const MACHINE := Color("ffb01f")
const MACHINE_DK := Color("d88c12")
const DARK := Color("26221c")
const HAZARD := Color("e8402a")
const INK := Color("1a1410")
const CLOUD := Color("f4faff")
const STEEL := [Color("4a5a6a"), Color("5f7080"), Color("7a8a9a"), Color("9aaab8")]


static func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	# 'balsa' in craftMat: matte, no specular. These are toy parts, not
	# plastic — ART_BRIEF's craft register.
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


static func box(parent: Node3D, w: float, h: float, d: float, c: Color,
		x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	bm.material = mat(c)
	mi.mesh = bm
	mi.position = Vector3(x, y, z)
	parent.add_child(mi)
	return mi


## Build a small machine's body. Ported shape-for-shape from js/robots.js
## buildRobot(); the comments there are the design and are kept.
## Returns {root, tell, legs}.
static func robot(kind: String) -> Dictionary:
	var g := Node3D.new()
	var legs: Array[Node3D] = []
	var tell: MeshInstance3D

	match kind:
		"bucket":
			# A DIGGER BUCKET, and the silhouette has to say "machinery that
			# fell off a machine" from across the screen. Asleep it reads as
			# debris, which is the point — the tell is the head lifting.
			box(g, 0.86, 0.42, 0.66, STEEL[1], 0, 0.21, 0)      # the scoop
			box(g, 0.90, 0.12, 0.70, STEEL[2], 0, 0.44, 0)      # the lip
			for tx in [-0.3, -0.1, 0.1, 0.3]:                   # teeth
				box(g, 0.10, 0.16, 0.12, STEEL[3], tx, 0.52, 0.3)
			box(g, 0.30, 0.26, 0.34, MACHINE_DK, 0.1, 0.6, 0)   # the head
			for lx in [-0.24, 0.24]:
				legs.append(box(g, 0.16, 0.18, 0.20, STEEL[2], lx, 0.09, 0))
			tell = box(g, 0.10, 0.10, 0.06, HAZARD, 0.24, 0.63, 0.16)
		"roller":
			# WIDE and LOW: the silhouette is the drum, and it has to read as
			# "you cannot land on this" from across the screen.
			box(g, 0.90, 0.26, 0.56, MACHINE_DK, 0, 0.40, 0)    # deck
			var drum := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.28
			cm.bottom_radius = 0.28
			cm.height = 0.62
			cm.material = mat(STEEL[2])
			drum.mesh = cm
			drum.rotation.x = PI / 2
			drum.position = Vector3(0, 0.28, 0)
			g.add_child(drum)
			legs.append(drum)
			box(g, 0.24, 0.20, 0.40, DARK, -0.34, 0.50, 0)      # the cab
			tell = box(g, 0.14, 0.12, 0.10, HAZARD, 0.40, 0.44, 0)
		"hopper":
			# A jackhammer on legs: TALL and narrow, the mass up top, so the
			# crouch before a hop is legible at any size.
			box(g, 0.34, 0.50, 0.34, MACHINE_DK, 0, 0.62, 0)    # body
			box(g, 0.44, 0.12, 0.44, MACHINE.lerp(INK, 0.2), 0, 0.92, 0)
			box(g, 0.16, 0.42, 0.16, STEEL[2], 0, 0.20, 0)      # the pick
			tell = box(g, 0.13, 0.13, 0.10, HAZARD, 0.19, 0.74, 0)
			for dz in [0.16, -0.16]:
				legs.append(box(g, 0.09, 0.30, 0.09, DARK, 0, 0.20, dz))
		_:
			# Squat, wide, one exaggerated feature: the eye. Machine yellow
			# says it belongs to the worksite; hazard red says this one is
			# not yours.
			box(g, 0.62, 0.42, 0.50, MACHINE_DK, 0, 0.34, 0)    # body
			box(g, 0.66, 0.10, 0.54, DARK, 0, 0.12, 0)          # skirt
			tell = box(g, 0.16, 0.16, 0.10, HAZARD, 0.26, 0.40, 0)
			box(g, 0.50, 0.12, 0.42, MACHINE.lerp(INK, 0.2), 0, 0.60, 0)
			for dx in [-0.2, 0.2]:
				for dz in [0.18, -0.18]:
					legs.append(box(g, 0.10, 0.24, 0.10, DARK, dx, 0.12, dz))

	# The telegraph is NAMED the same on both sides of the seam, because the
	# rule the gate checks is about the GAME — the tell has to be a size you
	# can see — not about which art is behind it today.
	tell.name = "tell"
	return {"root": g, "tell": tell, "legs": legs}
