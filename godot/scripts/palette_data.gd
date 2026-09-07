class_name PaletteData
extends RefCounted
## The browser build's palette and its per-world GROUND COLOUR, read as data.
##
## CONTENT IS AUTHORED ONCE AND FLOWS (CLAUDE.md). Levels, scenery, strings,
## glyphs, audio and the asset manifest all cross the seam that way and none of
## them has ever drifted, because regenerating is the only way to change one.
## Colour was the last thing still being RETYPED — `play.gd` carried hand-typed
## copies of `js/level.js`'s tables — and on 2026-09-07 the two were measured
## against each other:
##
##   pipeworks earth   js  0.40 / 0.36 / 0.32 / 0.28 toward STEEL
##                     gd  0.22 / 0.20 / 0.16 / 0.14        ← about HALF
##   nightshift lip    js  mix(mix(GREEN, INK, 0.48), SKY, 0.12)
##                     gd  mix(GREEN, INK, 0.45)            ← no sky at all
##   grove earth       js  mix(E[1], GREEN_DK, 0.22), mix(E[2], …, 0.38)
##                     gd  mix(E[1], GREEN_DK, 0.12), mix(E[2], …, 0.28)
##
## The first row is the whole of v15.51, which exists because at the ORIGINAL
## strengths all four worlds still screenshotted as the same brown — "Lambert
## and the detail map between them flatten a 15% tint to nothing a phone can
## see". The browser build was fixed. The tablet build kept the strengths that
## had already been proved insufficient, and nobody could see it because the
## numbers were in two files nothing compared.
##
## THE MIXES ARE NOT EVALUATED HERE, deliberately. `export-palette.mjs`
## resolves them and writes finished '#rrggbb'. A port that re-ran
## `mix(a, b, 0.3)` would be a second implementation of the rule, which is the
## thing the rule forbids — and re-running it from a retyped constant is
## exactly how the rows above came to disagree. This file reads colours and
## cannot express an opinion about them.

const PATH := "res://data/palette.json"

var pal := {}          ## name -> "#rrggbb" or Array of them
var layer_z := {}      ## SKY/SKYLINE/FAR/MID/NEAR/PLAY/FORE -> z
var layer_tint := {}
var ground := {}       ## world -> {earth: [4], lip, fringe}
var loaded := false


static func load_data() -> PaletteData:
	var d := PaletteData.new()
	if not FileAccess.file_exists(PATH):
		push_warning("palette.json missing — run godot/tools/export-palette.mjs")
		return d
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return d
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("palette.json is not an object")
		return d
	d.pal = parsed.get("pal", {})
	d.layer_z = parsed.get("layerZ", {})
	d.layer_tint = parsed.get("layerTint", {})
	d.ground = parsed.get("ground", {})
	d.loaded = not d.ground.is_empty()
	return d


## A single palette entry, e.g. `colour("INK")`. Ramps are indexed:
## `colour("STEEL", 2)`.
func colour(name: String, index := -1, fallback := Color.MAGENTA) -> Color:
	if not pal.has(name):
		return fallback
	var v = pal[name]
	if index >= 0:
		if typeof(v) != TYPE_ARRAY or index >= v.size():
			return fallback
		return Color(String(v[index]))
	if typeof(v) == TYPE_ARRAY:
		return fallback
	return Color(String(v))


func _world(world: String) -> Dictionary:
	if ground.has(world):
		return ground[world]
	# the same fallback `Level`'s constructor makes on the other side
	if ground.has("groundworks"):
		return ground["groundworks"]
	return {}


## The four earth bands, DEEPEST FIRST — the order `_strata_for` already
## indexed by, so nothing downstream changes except the colour drawn.
func earth_for(world: String) -> Array:
	var g := _world(world)
	var out: Array = []
	for c in g.get("earth", []):
		out.append(Color(String(c)))
	return out


## The grass lip: a daylight green strip is wrong at night and wrong in a
## trench, and it is the brightest thing on the floor.
func lip_for(world: String) -> Color:
	var g := _world(world)
	return Color(String(g.get("lip", "#3cc85a")))


## The LIGHT the felt fringe is lit by — a multiplier onto the photograph, so
## the nap and the cut tufts survive. White in World 1, which is the light it
## was photographed in.
func fringe_for(world: String) -> Color:
	var g := _world(world)
	return Color(String(g.get("fringe", "#ffffff")))
