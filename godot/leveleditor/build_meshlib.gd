extends SceneTree
## Builds leveleditor/tiles.meshlib — the GridMap palette a level author paints
## terrain with, straight in Godot's own 3D viewport.
##
## ONE ITEM PER GRID CHARACTER, from js/parts.js SOLID_CHARS + CLIMB_CHAR —
## the same legend LevelData.gd already reads. Colours here are an EDITING
## convenience (so a bank reads as diggable-brown and a wall as brick-red
## while you paint) and are NOT what the game renders: the shipped play scene
## draws every solid tile as the one card-textured box, because that is what
## assets/README.md and the shipped art actually specify. Two renderers for
## one legend is the point — author-time needs to be legible, ship-time needs
## to match the diorama.
##
## Regenerate after changing the legend:
##   godot --headless --path . --script res://leveleditor/build_meshlib.gd

const OUT := "res://leveleditor/tiles.meshlib"

## char -> [display name, colour, solid]. Order matches SOLID_CHARS +
## CLIMB_CHAR, so this is the whole legend in one place.
const TILES := [
	["#", "earth",       Color(0.47, 0.35, 0.24), true],
	["=", "ledge",        Color(0.62, 0.50, 0.36), true],
	["G", "girder_span",  Color(0.55, 0.55, 0.58), true],
	["B", "bank_dig",     Color(0.55, 0.34, 0.16), true],
	["K", "wall_brick",   Color(0.62, 0.28, 0.22), true],
	["C", "belt_right",   Color(0.90, 0.70, 0.15), true],
	["c", "belt_left",    Color(0.75, 0.55, 0.10), true],
	["T", "tarp_bounce",  Color(0.85, 0.45, 0.15), true],
	["~", "water_shallow", Color(0.25, 0.55, 0.75), true],
	["H", "ladder",       Color(0.85, 0.85, 0.80), false],
]

func _init() -> void:
	var lib := MeshLibrary.new()
	for i in TILES.size():
		var ch: String = TILES[i][0]
		var name: String = TILES[i][1]
		var col: Color = TILES[i][2]
		var solid: bool = TILES[i][3]

		var mesh := BoxMesh.new()
		# Ladders are drawn thin — a rung strip, not a solid cube — so painting
		# one cannot be mistaken for a solid tile in the viewport, matching
		# the fact that CLIMB_CHAR is NOT in SOLID_CHARS.
		mesh.size = Vector3(1, 1, 1) if solid else Vector3(0.9, 1, 0.16)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 1.0
		mesh.material = mat

		var id := lib.get_last_unused_item_id()
		lib.create_item(id)
		lib.set_item_name(id, "%s  (%s)" % [name, ch])
		lib.set_item_mesh(id, mesh)
		lib.set_item_mesh_transform(id, Transform3D())
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		lib.set_item_shapes(id, [shape, Transform3D()])

	var err := ResourceSaver.save(lib, OUT)
	if err != OK:
		printerr("FAIL: could not write ", OUT, " (", err, ")")
		quit(1)
		return
	print("Wrote %s — %d tile types (%s)" % [OUT, TILES.size(),
		", ".join(TILES.map(func(t): return t[0]))])
	quit(0)
