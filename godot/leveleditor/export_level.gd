@tool
extends EditorScript
## THE EDITOR'S RUN BUTTON: exports whatever level scene is currently open.
## All the actual logic lives in level_exporter.gd (a plain RefCounted) —
## Godot refuses to instantiate an EditorScript outside the editor itself, so
## nothing that needs to be testable headlessly can live in this file.
##
## HOW TO RUN IT (built-in Godot, no plugin): open the level scene you are
## editing, open THIS script in the Script editor, and either press the "Run"
## button (the play-circle icon in the script editor's top bar) or
## File > Run. Godot calls _run() against whatever scene is open.
##
## Writes: res://data/levels/<slug>.json — same folder the JS exporter
## writes, so a hand-authored level and a generated one are indistinguishable
## to everything that loads them.

func _run() -> void:
	var root := get_scene()
	if root == null:
		push_error("No scene is open. Open the level you want to export first.")
		return
	var result := LevelExporter.new().export_scene(root)
	if result.is_empty():
		return   # export_scene() already push_error'd the reason
	var problems: Array = result["problems"]
	if not problems.is_empty():
		push_warning("Exported with %d problem(s):\n  " % problems.size()
			+ "\n  ".join(problems))
	print("Wrote %s%s" % [result["path"],
		"" if problems.is_empty() else "  (%d problem(s), see above)" % problems.size()])
