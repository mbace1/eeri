extends SceneTree
## Builds leveleditor/level_template.tscn — the scene a new level starts
## from: a GridMap already wearing tiles.meshlib, plus an empty Entities
## folder to drag marker prefabs into. Duplicate this scene (FileSystem dock
## > right-click > Duplicate) to start a new level; never edit the template
## itself once other levels depend on the habit of duplicating it.
##
## Regenerate after changing the legend or the canvas size:
##   godot --headless --path . --script res://leveleditor/build_level_template.gd

const OUT := "res://leveleditor/level_template.tscn"
## Matches export_level.gd's W/H/GROUND exactly — the fixed canvas every
## room in js/parts.js already assumes, so a proved jump (REACH, js/kid.js)
## means the same thing in a hand-authored level as in a generated one.
const W := 96
const H := 18


func _init() -> void:
	var root := Node3D.new()
	root.name = "eeri-new-level"
	# The exporter reads this metadata for the output filename and level
	# name — set both before running export_level.gd on a duplicate.
	root.set_meta("eeri_slug", "eeri-new-level")
	root.set_meta("eeri_name", "NEW LEVEL")

	var gm := GridMap.new()
	gm.name = "Terrain"
	gm.mesh_library = load("res://leveleditor/tiles.meshlib")
	gm.cell_size = Vector3(1, 1, 1)
	root.add_child(gm)
	gm.owner = root

	# A thin ground-line marker strip so the fixed GROUND row (y=4, matching
	# js/parts.js) is visible without having to remember the number — paint
	# terrain relative to this, not from the viewport's own y=0.
	var ground_hint := MeshInstance3D.new()
	ground_hint.name = "GroundLineHint (paint terrain AT or BELOW this — do not save)"
	var box := BoxMesh.new()
	box.size = Vector3(W, 0.03, 0.03)
	ground_hint.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ground_hint.material_override = mat
	ground_hint.position = Vector3(W / 2.0, 4.0, 0)
	root.add_child(ground_hint)
	ground_hint.owner = root

	var entities := Node3D.new()
	entities.name = "Entities"
	root.add_child(entities)
	entities.owner = root

	var packed := PackedScene.new()
	var res := packed.pack(root)
	if res != OK:
		printerr("FAIL packing template: ", res)
		quit(1)
		return
	var err := ResourceSaver.save(packed, OUT)
	if err != OK:
		printerr("FAIL saving ", OUT, ": ", err)
		quit(1)
		return
	print("Wrote %s (%dx%d canvas, ground row 4)" % [OUT, W, H])
	quit(0)
