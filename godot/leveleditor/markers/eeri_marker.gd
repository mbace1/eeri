@tool
class_name EeriMarker
extends Node3D
## Base for every level-editor marker. A colored, billboarded disc so it is
## visible and clickable in the 3D viewport at any zoom, plus a text label so
## two markers standing near each other (a bolt beside a golden bolt) are
## still tellable apart without opening the Inspector.
##
## Position is read directly off `position.x` / `position.y` at export time.
## A drop snaps through `EeriLayerRail.place`. A later drag (or a typed x/y)
## snaps onto that same half-tile grid and does not change `position.z` or
## `eeri_layer`. Opening a saved level does not re-snap: moves are ignored
## until the next idle frame after the marker enters the tree.

@export var marker_color := Color(1, 1, 0) : set = _set_color

var _mesh: MeshInstance3D
var _label: Label3D
var _snap_ready := false
var _snapping := false


func _enter_tree() -> void:
	# Local, not global: a position write notifies synchronously.
	# NOTIFICATION_TRANSFORM_CHANGED is flushed later and would miss the
	# drag that just happened. Arm on the next idle frame so a scene open
	# leaves saved positions where they were.
	set_notify_local_transform(true)
	_snap_ready = false
	_snapping = false
	call_deferred("_arm_snap")


func _arm_snap() -> void:
	if not is_inside_tree():
		return
	_snap_ready = true


func _notification(what: int) -> void:
	if what != NOTIFICATION_LOCAL_TRANSFORM_CHANGED or not _snap_ready or _snapping:
		return
	_snapping = true
	EeriLayerRail.snap_xy(self)
	_snapping = false


func _ready() -> void:
	if _mesh == null:
		_build_gizmo()


func _build_gizmo() -> void:
	_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	_mesh.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = marker_color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = m
	add_child(_mesh)

	_label = Label3D.new()
	_label.text = _label_text()
	_label.font_size = 32
	_label.pixel_size = 0.01
	_label.position = Vector3(0, 0.4, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color.WHITE
	_label.outline_size = 6
	add_child(_label)


## Override in a subclass to show something more useful than the node name —
## a robot marker shows its kind, a machine spawn shows which machine.
func _label_text() -> String:
	return name


func _set_color(c: Color) -> void:
	marker_color = c
	if _mesh:
		(_mesh.material_override as StandardMaterial3D).albedo_color = c


## Round-trip helper: every marker answers "where am I", in the (x, y) the
## exporter needs. z is ignored — the play plane is z=0.
func export_pos() -> Vector2:
	return Vector2(position.x, position.y)
