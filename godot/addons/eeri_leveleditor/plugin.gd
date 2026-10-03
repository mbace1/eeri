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


func _enter_tree() -> void:
	_dock = preload("res://leveleditor/editor_dock.gd").new()
	_dock.name = "Layers"
	_dock.custom_minimum_size = Vector2(220, 120)
	add_control_to_dock(DOCK_SLOT_LEFT_UL, _dock)
	scene_changed.connect(_on_scene_changed)
	_on_scene_changed(get_editor_interface().get_edited_scene_root())


func _exit_tree() -> void:
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
		if is_instance_valid(n) and n is Node3D and EeriLayerRail.is_marker(n):
			EeriLayerRail.place(n as Node3D, index)
	_pending.clear()
