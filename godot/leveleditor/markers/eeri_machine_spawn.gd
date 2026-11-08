@tool
class_name EeriMachineSpawn
extends EeriMarker
## Where the ride machine is parked. `kind` decides the body (scripts/rigs.gd
## for skidder/loader, the live .glb for excavator/crane) — see
## GODOT_GAMEPLAY_NOTES for why the SPAWN KEY equals the machine type on the
## runtime side; the exporter writes that key for you either way.
enum Kind {EXCAVATOR, CRANE, SKIDDER, LOADER, FLATTENER, PUMP}
@export var kind := Kind.EXCAVATOR : set = _set_kind
@export var track_left := -6.0
@export var track_right := 6.0
@export_range(0.1, 10.0, 0.1) var arm_reach := 2.6
func _init() -> void:
	marker_color = Color(1.0, 0.69, 0.12)
func _label_text() -> String:
	return "MACHINE: %s" % Kind.keys()[kind].to_lower()
func kind_string() -> String:
	return Kind.keys()[kind].to_lower()

func _set_kind(value: int) -> void:
	kind = value
	if _label != null: _label.text = _label_text()

func work_verbs() -> Array:
	match kind:
		Kind.CRANE: return ["smash"]
		Kind.FLATTENER: return ["flatten"]
		Kind.PUMP: return ["drain"]
	return ["dig", "span"]
