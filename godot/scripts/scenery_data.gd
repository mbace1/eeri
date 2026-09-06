class_name SceneryData
extends RefCounted
## The browser build's SCENERY rows, read as data.
##
## CONTENT IS AUTHORED ONCE AND FLOWS (CLAUDE.md). Levels, strings, glyphs,
## audio and the art manifest all cross the seam that way; scenery never did,
## and on 2026-09-06 that bill came due twice at once:
##
##  · everything the art lane made that week — World 3's felt treeline, the
##    lamps, World 1 and 2's dressing vocabulary, every piece the rebuilt
##    level editor can place — was invisible to this build;
##  · and `dressing34.gd`, a HAND-PORT of the old js/world34-dressing.js, was
##    still drawing the fourteen flat green discs the browser build deleted in
##    v15.55. Two implementations of one thing, drifting apart — the single
##    failure mode the rule exists to prevent.
##
## `godot/tools/export-scenery.mjs` writes `data/scenery.json` by importing the
## real modules, so it cannot drift. This reads it.
##
## THERE IS NO ALLOW-LIST HERE, deliberately. The exporter writes each row
## whole, through the browser build's own `withDefaults`, and this hands the
## row to the builder as it arrived. `export-levels.mjs` carries an allow-list
## and it cost a release: `sheet` and `planks` reached the port as `null` with
## no error until two separate files learned their names (SESSION_HANDOFF
## §3.1). A row here can gain a field without this file being touched.

const PATH := "res://data/scenery.json"

var art := {}          ## name -> {file,label,layer,h}
var props := {}        ## name -> {label,layer,art}
var layer_z := {}      ## SKY/SKYLINE/FAR/MID/NEAR/PLAY/FORE -> z
var play_z := -0.85
var worlds := {}       ## world -> Array[Dictionary]


static func load_data() -> SceneryData:
	var d := SceneryData.new()
	if not FileAccess.file_exists(PATH):
		push_warning("scenery.json missing — run godot/tools/export-scenery.mjs")
		return d
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return d
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("scenery.json is not an object")
		return d
	d.art = parsed.get("art", {})
	d.props = parsed.get("props", {})
	d.layer_z = parsed.get("layerZ", {})
	d.play_z = float(parsed.get("playZ", -0.85))
	d.worlds = parsed.get("worlds", {})
	return d


func rows_for(world: String) -> Array:
	var r = worlds.get(world, [])
	return r if typeof(r) == TYPE_ARRAY else []


## The depth a lane sits at. `play` is not a painted lane and has no LAYER_Z
## entry — it is where a dressing cutout stands, in front of `near` and behind
## anything the player can touch, and the number is js/layers.js's own.
func z_for(lane: String) -> float:
	if lane == "play" or lane == "":
		return play_z
	var key := lane.to_upper()
	if layer_z.has(key):
		return float(layer_z[key])
	return play_z


## Mount every ART row of a world under `root`. Props that are not keyed
## cutouts (the dressing vocabulary, lamps) are left to their own builders —
## this owns the pieces `js/artprops.js` owns on the other side, and nothing
## else, so there is exactly one thing here that could ever disagree with the
## browser build and it is a file both of them read.
##
## Returns how many were mounted, so a gate can assert a number rather than
## trust a screenshot.
func mount_art(root: Node3D, world: String) -> int:
	var n := 0
	for row in rows_for(world):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var prop := String(row.get("prop", ""))
		if not art.has(prop):
			continue                      # a builder prop, not a cutout
		var spec: Dictionary = art[prop]
		var tex := load("res://data/" + String(spec.get("file", ""))) as Texture2D
		if tex == null:
			push_warning("scenery art missing: %s" % prop)
			continue
		var sz := tex.get_size()
		if sz.y <= 0.0:
			continue
		var h := float(row.get("h", spec.get("h", 1.0)))
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(h * (sz.x / sz.y), h)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1, float(row.get("o", 1.0)))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# unshaded like every other keyed cutout in this build: these are flat
		# card silhouettes and the shading is already painted into them
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		# THE ROW'S `y` IS WHERE THE PIECE STANDS, not its centre — the same
		# arithmetic the browser build got wrong once and shipped, hanging
		# every tree a metre above the ground (v15.57). The mount does it.
		mi.position = Vector3(float(row.get("x", 0.0)), float(row.get("y", 0.0)) + h * 0.5, z_for(String(row.get("layer", "play"))))
		if bool(row.get("flip", false)):
			mi.scale.x = -1.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "art_%s_%d" % [prop, n]
		root.add_child(mi)
		n += 1
	return n
