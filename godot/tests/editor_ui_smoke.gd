extends RefCounted
## Run against the real EditorPlugin, dock controls and native undo manager:
## EERI_EDITOR_SMOKE=1 godot --headless --editor --path godot
var passed := 0
var failed := 0
const SLUG := "eeri-editor-ui-test"

func check(label: String, value: bool) -> void:
	print("EDITOR UI %s - %s" % ["ok" if value else "FAIL", label])
	if value: passed += 1
	else: failed += 1

func _button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := _button(child, label)
		if found != null: return found
	return null

func run(plugin: EditorPlugin) -> void:
	var tree := plugin.get_tree()
	tree.create_timer(60).timeout.connect(func(): print("EDITOR UI FAIL - timed out"); tree.quit(1))
	await tree.create_timer(1.0).timeout
	var dock = plugin._dock
	var source := "res://data/levels/%s.json" % SLUG
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://data/levels/eeri-1-1.json"))
	file.close()
	dock._levels.add_item("Editor smoke fixture")
	dock._levels.set_item_metadata(dock._levels.item_count - 1, SLUG)
	dock._levels.select(dock._levels.item_count - 1)
	_button(dock, "Open level").pressed.emit()
	var root: Node
	for i in 120:
		await tree.create_timer(0.05).timeout
		root = plugin.get_editor_interface().get_edited_scene_root()
		if root != null and root.get_meta("eeri_slug", "") == SLUG: break
	check("Open level opens a saved campaign draft", root != null and root.get_meta("eeri_slug", "") == SLUG)
	if root == null or root.get_meta("eeri_slug", "") != SLUG:
		tree.quit(1)
		return
	dock.set_layer_index(EeriLayerRail.index_of("FAR"))
	dock._filter.text = "spruce"
	dock._filter.text_changed.emit("spruce")
	check("the searchable palette contains the existing spruce art", dock._palette.item_count == 1)
	dock._palette.select(0)
	_button(dock, "Add selected piece").pressed.emit()
	await tree.process_frame
	var selection := plugin.get_editor_interface().get_selection().get_selected_nodes()
	var marker: Node3D = selection[0] if not selection.is_empty() else null
	check("Add piece selects real editable art on FAR", marker is EeriArtCutout and marker.get_meta("eeri_layer", "") == "FAR")
	var undo := plugin.get_undo_redo()
	var history := undo.get_history_undo_redo(undo.get_object_history_id(root))
	history.undo()
	await tree.process_frame
	check("native undo removes the placed art", marker != null and marker.get_parent() == null)
	dock.set_layer_index(EeriLayerRail.index_of("NEAR"))
	history.redo()
	await tree.process_frame
	await tree.process_frame
	check("native redo preserves the original layer after moving the slider", marker != null
		and marker.get_parent() != null and marker.get_meta("eeri_layer", "") == "FAR")
	_button(dock, "Save").pressed.emit()
	var saved_scene := "res://authored/%s.tscn" % SLUG
	var saved := ResourceLoader.load(saved_scene, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reopened := saved.instantiate()
	var art_saved := false
	for child in reopened.get_node("Entities").get_children():
		if child is EeriArtCutout and child.prop_key == "treeSpruce": art_saved = true
	check("Save persists the newly added art in the authored scene", art_saved)
	reopened.free()
	_button(dock, "Check").pressed.emit()
	check("Check validates the edited scene through the dock", dock._status.text.begins_with("Ready to play"))
	var shot := OS.get_environment("EERI_EDITOR_SHOT")
	if shot != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		plugin.get_editor_interface().get_base_control().get_viewport().get_texture().get_image().save_png(shot)
	dock._from_checkpoint.button_pressed = true
	_button(dock, "Play").pressed.emit()
	var preview = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/eeri-editor-preview.json"))
	check("Play exports the current art and checkpoint choice", preview is Dictionary
		and preview.get("preview_checkpoint", false) and preview.get("scenery", []).any(func(row): return row.get("prop") == "treeSpruce"))
	check("Play launches the preview scene", plugin.get_editor_interface().is_playing_scene())
	plugin.get_editor_interface().stop_playing_scene()
	check("stopping play keeps the authoring scene open", plugin.get_editor_interface().get_edited_scene_root() == root)
	plugin.get_editor_interface().close_scene()
	DirAccess.remove_absolute(saved_scene)
	DirAccess.remove_absolute(source)
	print("EDITOR UI: %d passed, %d failed" % [passed, failed])
	tree.quit(1 if failed else 0)
