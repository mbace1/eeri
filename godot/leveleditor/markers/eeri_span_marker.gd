@tool
class_name EeriSpanMarker
extends EeriMarker
## Base for anything that covers a horizontal RANGE rather than a point —
## a robot patrol, a hoist shaft, a pit, a water region. Drawn as a bar from
## position.x to position.x + span_width, at position.y, so the extent is
## visible in the viewport rather than only in the Inspector.
@export var span_width := 4.0 : set = _set_span

var _bar: MeshInstance3D

func _build_gizmo() -> void:
	super()
	_bar = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(span_width, 0.1, 0.1)
	_bar.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = marker_color
	_bar.material_override = m
	_bar.position = Vector3(span_width / 2.0, 0, 0)
	add_child(_bar)

func _set_span(v: float) -> void:
	span_width = v
	if _bar:
		(_bar.mesh as BoxMesh).size.x = v
		_bar.position.x = v / 2.0

## The span in world x, LEFT-EDGE-RELATIVE — position.x is c0, position.x +
## span_width is c1. Matches every {c0, c1} pair in the JSON schema.
func c0() -> float:
	return position.x
func c1() -> float:
	return position.x + span_width
