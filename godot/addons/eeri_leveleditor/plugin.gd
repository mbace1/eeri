@tool
extends EditorPlugin
## Editor half of the level editor's layer slider. The dock and the layer
## table live in leveleditor/ — this file only exists because Godot 4 loads
## editor plugins from res://addons/<name>/plugin.cfg.
##
## Dropping a marker prefab (everything leveleditor/markers/ already places;
## there is no separate background pack) sets position.z to the selected
## layer and snaps x/y. Existing markers are left where they are: the slider
## chooses the layer you are placing, it does not restack the scene.
## Dragging a marker that is already placed is handled on EeriMarker itself
## (`snap_xy`): x/y only, so this plugin must not also listen for moves.

var _dock: Control
var _armed := false
var _flush_queued := false
var _pending: Array[Node] = []
var _apply_dialog: ConfirmationDialog


func _enter_tree() -> void:
	_dock = preload("res://leveleditor/editor_dock.gd").new()
	_dock.name = "Layers"
	_dock.custom_minimum_size = Vector2(220, 120)
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)
	_dock.configure(self)
	scene_changed.connect(_on_scene_changed)
	_on_scene_changed(get_editor_interface().get_edited_scene_root())
	if OS.get_environment("EERI_EDITOR_SMOKE") == "1":
		call_deferred("_run_editor_smoke")


func _run_editor_smoke() -> void:
	await load("res://tests/editor_ui_smoke.gd").new().run(self)


func _exit_tree() -> void:
	if _apply_dialog != null:
		_apply_dialog.queue_free()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	_pending.clear()
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _on_scene_changed(root: Node) -> void:
	# Connecting after the scene is already built means the markers it was
	# saved with do not get re-snapped. Signals that still arrive while the
	# open is finishing are dropped until _arm.
	_armed = false
	_pending.clear()
	if root != null:
		_watch(root)
	if _dock != null:
		_dock.set_current(root)
	_flush_queued = true
	call_deferred("_arm")


func _arm() -> void:
	_flush_queued = false
	_pending.clear()
	_armed = true


func _watch(n: Node) -> void:
	if not n.child_entered_tree.is_connected(_on_child):
		n.child_entered_tree.connect(_on_child)
	for c in n.get_children():
		_watch(c)


func _on_child(child: Node) -> void:
	_watch(child)
	if not _armed:
		return
	# The dropped node is usually the marker itself. A wrapper (a duplicated
	# group) carries the markers as children that have already entered, so
	# walk the subtree instead of trusting the root alone.
	_collect_markers(child)
	if _pending.is_empty() or _flush_queued:
		return
	_flush_queued = true
	call_deferred("_flush_places")


func _collect_markers(n: Node) -> void:
	if EeriLayerRail.is_marker(n):
		_pending.append(n)
	for c in n.get_children():
		_collect_markers(c)


func _flush_places() -> void:
	_flush_queued = false
	if not _armed or _dock == null:
		_pending.clear()
		return
	var index := 0
	if _dock.has_method("selected_index"):
		index = int(_dock.call("selected_index"))
	for n in _pending:
		if is_instance_valid(n) and n is Node3D and EeriLayerRail.is_marker(n) and not n.has_meta("eeri_layer"):
			EeriLayerRail.place(n as Node3D, index)
	_pending.clear()


func open_level(slug: String) -> void:
	var path := "res://authored/%s.tscn" % slug
	if not FileAccess.file_exists(path):
		var root := EeriLevelImporter.new().build(slug)
		if root == null:
			_dock.show_status("Could not open this level. Regenerate the game data first.", true)
			return
		if not _write_scene(root, path):
			root.free()
			return
		root.free()
	_open_saved_draft.call_deferred(path)


func new_level() -> void:
	var root := (load("res://leveleditor/level_template.tscn") as PackedScene).instantiate()
	var slug := "eeri-draft-%d" % int(Time.get_unix_time_from_system())
	root.set_meta("eeri_slug", slug)
	root.set_meta("eeri_world", "groundworks")
	var path := "res://authored/%s.tscn" % slug
	if _write_scene(root, path):
		_open_saved_draft.call_deferred(path)
	root.free()


func _open_saved_draft(path: String) -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning():
		await filesystem.filesystem_changed
	get_editor_interface().open_scene_from_path(path)


func _write_scene(root: Node, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute("res://authored")
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK: error = ResourceSaver.save(packed, path)
	if error != OK:
		_dock.show_status("Could not save the draft: " + error_string(error), true)
		return false
	get_editor_interface().get_resource_filesystem().scan()
	return true


func save_level() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root.has_meta("eeri_slug"):
		_dock.show_status("Open a level before saving.", true)
		return
	var error: Error
	if DisplayServer.get_name() == "headless" and root.scene_file_path.begins_with("res://authored/"):
		get_editor_interface().save_scene_as(root.scene_file_path, false)
		error = OK
	elif root.scene_file_path.begins_with("res://authored/"):
		error = get_editor_interface().save_scene()
	else:
		DirAccess.make_dir_recursive_absolute("res://authored")
		get_editor_interface().save_scene_as("res://authored/%s.tscn" % root.get_meta("eeri_slug"))
		error = OK
	_dock.show_status("Draft saved." if error == OK else "Could not save: " + error_string(error), error != OK)


func validate_level() -> void:
	var result := _export(false)
	if not result.is_empty() and result["problems"].is_empty():
		_dock.show_status("Ready to play · %d bolts · %d placed art pieces" %
			[result["out"]["bolts"].size(), result["out"]["scenery"].size()])


func _export(write: bool) -> Dictionary:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root.has_meta("eeri_slug"):
		_dock.show_status("Open a level before checking or playing.", true)
		return {}
	var result := LevelExporter.new().export_scene(root, "eeri-editor-preview", write)
	if result.is_empty():
		_dock.show_status("This scene needs a Terrain GridMap and a level slug.", true)
	elif not result["problems"].is_empty():
		_dock.show_status("Fix before playing:\n• " + "\n• ".join(result["problems"]), true)
	return result


func play_level(from_checkpoint := false) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root != null:
		root.set_meta("eeri_preview_checkpoint", from_checkpoint)
	var result := _export(true)
	if result.is_empty() or not result.get("written", false): return
	get_editor_interface().play_custom_scene("res://leveleditor/preview_level.tscn")
	_dock.show_status("Playing your edits. Stop the game to return to this scene.")


func add_piece(entry: Dictionary) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root.has_meta("eeri_slug"):
		_dock.show_status("Open a level before adding a piece.", true)
		return
	var marker: EeriMarker
	if entry.has("art"):
		marker = EeriArtCutout.new()
		marker.prop_key = String(entry["art"])
	else:
		marker = (load(entry["scene"]) as PackedScene).instantiate()
	marker.name = String(entry["label"]).replace(" ", "")
	marker.position = Vector3(4.5, 4, 0)
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is EeriMarker:
		marker.position = selected[0].position + Vector3(1, 0, 0)
	var layer: int = _dock.selected_index() if marker is EeriArtCutout or marker is EeriLamp else EeriLayerRail.index_of("PLAY")
	EeriLayerRail.place(marker, layer)
	var parent: Node = root.get_node_or_null("Entities")
	if parent == null: parent = root
	var undo := get_undo_redo()
	undo.create_action("Add " + String(entry["label"]), UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(parent, "add_child", marker, true)
	undo.add_do_method(marker, "set_owner", root)
	undo.add_undo_method(parent, "remove_child", marker)
	undo.add_do_reference(marker)
	undo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(marker)
	get_editor_interface().edit_node(marker)
	get_editor_interface().mark_scene_as_unsaved()
	_dock.show_status("Added %s. Move it in the viewport; edit its settings in the Inspector." % entry["label"])


func review_world_art() -> void:
	var result := _export(true)
	if result.is_empty() or not result.get("written", false): return
	var output := []
	var tool := ProjectSettings.globalize_path("res://tools/apply-scenery.mjs")
	var preview := ProjectSettings.globalize_path("res://data/levels/eeri-editor-preview.json")
	var code := OS.execute("node", [tool, preview], output, true)
	if code != 0:
		_dock.show_status("Could not apply world art:\n" + "\n".join(output), true)
		return
	var summary = JSON.parse_string("\n".join(output))
	if not summary is Dictionary:
		_dock.show_status("Could not read the world-art review.", true)
		return
	if not summary.get("changed", false):
		_dock.show_status("World art already matches this draft.")
		return
	if _apply_dialog != null: _apply_dialog.queue_free()
	_apply_dialog = ConfirmationDialog.new()
	_apply_dialog.title = "Apply world art"
	_apply_dialog.dialog_text = "%s: %d → %d art placements.\nThis changes shared scenery in all three levels.\nGameplay changes stay in your draft." % [summary["world"], summary["before"], summary["after"]]
	_apply_dialog.ok_button_text = "Apply art"
	_apply_dialog.confirmed.connect(func():
		var current := _export(true)
		if current.is_empty() or not current.get("written", false): return
		var applied := []
		var status := OS.execute("node", [tool, preview, "--write"], applied, true)
		if status != 0:
			_dock.show_status("World art was not applied:\n" + "\n".join(applied), true)
			return
		var root := get_editor_interface().get_edited_scene_root()
		root.set_meta("eeri_scenery_source", SceneryData.load_data().rows_for(String(current["out"]["world"])))
		save_level()
		_dock.show_status("World art applied to both builds. Your gameplay draft is saved separately."))
	get_editor_interface().get_base_control().add_child(_apply_dialog)
	_apply_dialog.popup_centered()
