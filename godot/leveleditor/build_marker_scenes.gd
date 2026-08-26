extends SceneTree
## Turns every marker script in leveleditor/markers/ into a draggable .tscn
## prefab, so a level author never opens a script — drag the prefab from the
## FileSystem dock, position it in the 3D viewport, set its fields in the
## Inspector. That whole loop is stock Godot; nothing here is a custom UI.
##
## Regenerate after adding/renaming a marker script:
##   godot --headless --path . --script res://leveleditor/build_marker_scenes.gd

const DIR := "res://leveleditor/markers/"
## EeriMarker and EeriSpanMarker are BASES, not placeable markers themselves.
const SKIP := ["eeri_marker.gd", "eeri_span_marker.gd"]

func _init() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		printerr("FAIL: cannot open ", DIR)
		quit(1)
		return
	d.list_dir_begin()
	var made := 0
	var name := d.get_next()
	while name != "":
		if name.ends_with(".gd") and not SKIP.has(name):
			_build(name)
			made += 1
		name = d.get_next()
	d.list_dir_end()
	print("Wrote %d marker prefab(s)" % made)
	quit(0)


func _build(script_name: String) -> void:
	var script := load(DIR + script_name) as Script
	if script == null:
		printerr("  skip (no script): ", script_name)
		return
	var node := Node3D.new()
	node.set_script(script)
	node.name = script.get_global_name() if script.get_global_name() != "" \
		else script_name.trim_suffix(".gd").capitalize().replace(" ", "")
	# Build the gizmo NOW so it is baked into the saved scene rather than
	# depending on _ready() firing — a marker dropped into a level scene
	# should be visible the instant it lands, in-editor, with no play button.
	if node.has_method("_build_gizmo"):
		node.call("_build_gizmo")

	var packed := PackedScene.new()
	var res := packed.pack(node)
	if res != OK:
		printerr("  FAIL packing ", script_name, ": ", res)
		return
	var out := DIR + script_name.trim_suffix(".gd") + ".tscn"
	var err := ResourceSaver.save(packed, out)
	if err != OK:
		printerr("  FAIL saving ", out, ": ", err)
		return
	print("  ", out)
