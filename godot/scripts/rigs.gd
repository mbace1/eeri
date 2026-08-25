class_name Rigs
extends RefCounted
## The World 3 and World 4 machines — ported from js/rigs.js.
##
## WHY THIS EXISTS. Twelve levels, four worlds, and only two machine classes.
## The level data has always DECLARED four types — excavator, crane, skidder,
## loader — and a port that builds an excavator for anything that is not a
## crane hands a forest clearing and a night earthworks the same yellow
## digger. That was a real bug in this port until now.
##
## THE CHEAP PART IS THE CLASS, THE EXPENSIVE PART IS THE SILHOUETTE. Machine
## animates NAMED NODES — house, boom, stick, bucket, seat, step, wheels,
## beacon — and knows nothing else about what it is driving. So a new machine
## is a new MODEL against that contract, not a new class: build the same nodes
## into a different shape and every verb, every mount, every mercy frame and
## every gate works untouched. It is the same seam a live .glb would arrive
## through.
##
## THE BODY COLOUR STAYS IN THE FAMILY. PAL.MACHINE is "the cast's family
## colour", and a green skidder would read as a different cast rather than as
## another machine on the same site. These are told apart by SILHOUETTE, which
## is the house rule anyway: a flat fill inside a hard line has nowhere to put
## the difference except the outline. A forest livery is a palette decision
## and belongs to the art lane, not to a model builder.

const MACHINE := Craft.MACHINE
const MACHINE_DK := Craft.MACHINE_DK
const DARK := Craft.DARK
const INK := Craft.INK
const STEEL := Craft.STEEL


static func _cyl(parent: Node3D, r: float, h: float, c: Color,
		x: float, y: float, z: float, seg := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.material = Craft.mat(c)
	mi.mesh = cm
	mi.position = Vector3(x, y, z)
	parent.add_child(mi)
	return mi


static func _named(parent: Node3D, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


## The cab. The rider must stay VISIBLE (the Yoshi rule, ART_BRIEF §3.6), so
## it is an open seat and never a canopy that swallows him — and the EMPTY
## seat is how a player tells an unmanned machine from a tamed one.
static func _cab_in(house: Node3D, x: float) -> Node3D:
	var cab := Node3D.new()
	cab.position = Vector3(x, 0, 0)
	house.add_child(cab)
	Craft.box(cab, 0.78, 0.07, 0.80, STEEL[1], 0, 0.03, 0)
	Craft.box(cab, 0.30, 0.26, 0.52, MACHINE_DK, 0.36, 0.20, 0)
	Craft.box(cab, 0.34, 0.10, 0.34, DARK, -0.12, 0.22, 0)
	Craft.box(cab, 0.10, 0.40, 0.34, DARK, -0.30, 0.42, 0)
	var seat := _named(cab, "seat")
	seat.position = Vector3(-0.1, 0.12, 0)
	return seat


## Lit and turning while UNMANNED, dark once Eeri is aboard.
static func _beacon_at(house: Node3D, x: float, y: float, z: float) -> Node3D:
	var b := _named(house, "beacon")
	b.position = Vector3(x, y, z)
	var lamp := _cyl(b, 0.12, 0.17, Color("ff9c1a"), 0, 0.1, 0, 8)
	var m := lamp.mesh.material as StandardMaterial3D
	if m:
		m.emission_enabled = true
		m.emission = Color("ffdc8a")
		m.emission_energy_multiplier = 0.8
	Craft.box(b, 0.1, 0.1, 0.1, DARK, 0, 0, 0)
	return b


## The step up to the cab — the mount move is legible because this exists.
static func _step_on(root: Node3D, x: float, y: float, z: float) -> Node3D:
	var st := _named(root, "step")
	st.position = Vector3(x, y, z)
	Craft.box(st, 0.36, 0.07, 0.30, MACHINE, 0, 0, 0)
	Craft.box(st, 0.06, 0.45, 0.06, DARK, -0.15, 0.25, 0)
	return st


## WORLD 3. WIDE, SHORT TRACKS — a skidder works on soft ground, so it sits on
## more track than the excavator and lower over it, and the silhouette says
## "this one does not sink" before anything else about it registers. The STACK
## is the part that reads against a treeline. The BRUSH GUARD is bars rather
## than a canopy, because it works under branches AND the rider must stay
## visible.
static func skidder() -> Dictionary:
	var root := Node3D.new()
	var tracks := _named(root, "tracks")
	var wheels := _named(tracks, "wheels")
	for dz in [0.68, -0.68]:
		Craft.box(tracks, 3.0, 0.7, 0.5, DARK, 0, 0.38, dz)
		Craft.box(tracks, 2.5, 0.22, 0.54, INK, 0, 0.09, dz)
		for wx in [-1.05, -0.35, 0.35, 1.05]:
			var spin := Node3D.new()
			spin.position = Vector3(wx, 0.32, dz)
			_cyl(spin, 0.26, 0.56, STEEL[1], 0, 0, 0, 9).rotation.x = PI / 2
			wheels.add_child(spin)
	_step_on(root, 0.95, 0.6, 0.66)
	Craft.box(root, 2.2, 0.2, 1.25, STEEL[0], -0.05, 0.82, 0)

	var house := _named(root, "house")
	house.position.y = 0.92
	Craft.box(house, 1.35, 0.7, 1.1, MACHINE, -0.3, 0.35, 0)
	Craft.box(house, 0.55, 0.6, 1.1, MACHINE_DK, -1.18, 0.33, 0)
	Craft.box(house, 1.35, 0.1, 1.14, MACHINE_DK, -0.3, 0.05, 0)
	_cyl(house, 0.075, 0.85, DARK, -0.72, 1.12, 0.32, 8)
	_cyl(house, 0.11, 0.12, INK, -0.72, 1.56, 0.32, 8)
	for dz in [0.34, -0.34]:
		Craft.box(house, 0.06, 0.62, 0.06, STEEL[0], 0.9, 0.72, dz)
	for bx in [0.55, 0.78, 1.0]:
		Craft.box(house, 0.06, 0.06, 0.78, STEEL[0], bx, 1.05, 0)
	_cab_in(house, 0.52)
	_beacon_at(house, -0.48, 1.1, 0.36)

	var boom := _named(house, "boom")
	boom.position = Vector3(0.35, 0.3, 0)
	Craft.box(boom, 1.5, 0.34, 0.28, MACHINE, 0.72, 0, 0)
	Craft.box(boom, 1.5, 0.09, 0.30, MACHINE_DK, 0.72, -0.17, 0)
	var stick := _named(boom, "stick")
	stick.position = Vector3(1.44, 0, 0)
	Craft.box(stick, 1.0, 0.22, 0.2, MACHINE, 0.46, 0, 0)
	# Still called `bucket`: it is what closes on the load, and Machine drives
	# it by that name. A GRAPPLE, because a skidder drags rather than reaches.
	var bucket := _named(stick, "bucket")
	bucket.position = Vector3(0.94, 0, 0)
	Craft.box(bucket, 0.22, 0.20, 0.44, STEEL[1], 0.02, -0.08, 0)
	for dz in [0.2, -0.2]:
		var jaw := Node3D.new()
		jaw.position = Vector3(0.1, -0.16, dz)
		bucket.add_child(jaw)
		Craft.box(jaw, 0.40, 0.09, 0.10, STEEL[0], 0.16, -0.06, 0)
		Craft.box(jaw, 0.10, 0.24, 0.10, STEEL[0], 0.34, -0.20, 0)
		jaw.rotation.z = -0.25
		jaw.rotation.y = 0.22 if dz > 0 else -0.22
	boom.rotation.z = 0.52
	stick.rotation.z = -1.35
	bucket.rotation.z = -0.6
	return {"root": root, "boom": boom, "stick": stick, "bucket": bucket}


## WORLD 4. FOUR BIG WHEELS, not tracks — a wheeled loader reads as fast and
## as road machinery, which is what a night shift on a made-up site would run.
## The MAST with two work lamps is what makes it World 4's machine rather than
## a yellow digger at night; the lamp IS the light, because §3.4 forbids a
## post stack and there is no bloom to catch a glow.
static func loader() -> Dictionary:
	var root := Node3D.new()
	var under := _named(root, "tracks")
	var wheels := _named(under, "wheels")
	Craft.box(under, 2.5, 0.34, 1.15, INK, -0.1, 0.62, 0)
	for dz in [0.66, -0.66]:
		for wx in [-0.92, 0.86]:
			var spin := Node3D.new()
			spin.position = Vector3(wx, 0.5, dz)
			_cyl(spin, 0.50, 0.42, DARK, 0, 0, 0, 12).rotation.x = PI / 2
			_cyl(spin, 0.24, 0.46, STEEL[1], 0, 0, 0, 9).rotation.x = PI / 2
			wheels.add_child(spin)
	_step_on(root, 0.5, 0.72, 0.7)

	var house := _named(root, "house")
	house.position.y = 0.86
	Craft.box(house, 1.5, 0.66, 1.12, MACHINE, -0.5, 0.33, 0)
	Craft.box(house, 1.5, 0.10, 1.16, MACHINE_DK, -0.5, 0.03, 0)
	Craft.box(house, 0.4, 0.30, 0.90, MACHINE_DK, -1.3, 0.5, 0)
	_cyl(house, 0.06, 0.34, DARK, -0.95, 0.82, 0.3, 8)
	_cab_in(house, 0.42)
	_beacon_at(house, -0.35, 1.06, 0.34)

	var mast := Node3D.new()
	mast.position = Vector3(-0.55, 0.66, 0)
	house.add_child(mast)
	_cyl(mast, 0.06, 1.1, STEEL[0], 0, 0.55, 0, 8)
	Craft.box(mast, 0.5, 0.07, 0.1, STEEL[0], 0, 1.1, 0)
	for dx in [-0.2, 0.2]:
		Craft.box(mast, 0.20, 0.16, 0.22, DARK, dx, 1.02, 0)
		var glass := Craft.box(mast, 0.04, 0.12, 0.16, Color("fff2c8"), dx + 0.11, 1.02, 0)
		var gm := glass.mesh.material as StandardMaterial3D
		if gm:
			gm.emission_enabled = true
			gm.emission = Color("fff2c8")
			gm.emission_energy_multiplier = 1.4

	# boom -> stick -> BLADE. A loader lifts from the front and low, so the arm
	# rests almost flat instead of folded up over the house.
	var boom := _named(house, "boom")
	boom.position = Vector3(0.45, 0.1, 0)
	for dz in [0.42, -0.42]:
		Craft.box(boom, 1.9, 0.22, 0.16, MACHINE, 0.9, 0, dz)
	Craft.box(boom, 0.3, 0.16, 0.9, MACHINE_DK, 0.3, 0, 0)
	var stick := _named(boom, "stick")
	stick.position = Vector3(1.8, 0, 0)
	Craft.box(stick, 0.5, 0.18, 0.9, MACHINE, 0.2, 0, 0)
	var bucket := _named(stick, "bucket")
	bucket.position = Vector3(0.45, 0, 0)
	Craft.box(bucket, 0.50, 0.12, 1.30, STEEL[1], 0.2, -0.22, 0)
	Craft.box(bucket, 0.12, 0.44, 1.30, STEEL[1], -0.02, -0.02, 0)
	Craft.box(bucket, 0.62, 0.06, 1.34, STEEL[0], 0.28, -0.28, 0)
	for dz in [-0.5, 0.0, 0.5]:
		Craft.box(bucket, 0.10, 0.05, 0.12, DARK, 0.5, -0.28, dz)
	boom.rotation.z = 0.24
	stick.rotation.z = -0.9
	bucket.rotation.z = -0.35
	return {"root": root, "boom": boom, "stick": stick, "bucket": bucket}


## Code-drawn bodies for the two machines that have no live .glb. Returns an
## empty Dictionary for excavator/crane, which DO have one.
static func build(kind: String) -> Dictionary:
	match kind:
		"skidder":
			return skidder()
		"loader":
			return loader()
		_:
			return {}
