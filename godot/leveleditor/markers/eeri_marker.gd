@tool
class_name EeriMarker
extends Node3D
## Base for every level-editor marker. A colored, billboarded disc so it is
## visible and clickable in the 3D viewport at any zoom, plus a text label so
## two markers standing near each other (a bolt beside a golden bolt) are
## still tellable apart without opening the Inspector.
##
## Position is read directly off `position.x` / `position.y` at export time —
## drag it in the viewport, or type exact numbers in the Inspector. Either is
## "the editor"; this script does not care which was used.

@export var marker_color := Color(1, 1, 0) : set = _set_color

var _mesh: MeshInstance3D
var _label: Label3D


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
