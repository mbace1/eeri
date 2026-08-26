@tool
class_name EeriMachineSpawn
extends EeriMarker
## Where the ride machine is parked. `kind` decides the body (scripts/rigs.gd
## for skidder/loader, the live .glb for excavator/crane) — see
## GODOT_GAMEPLAY_NOTES for why the SPAWN KEY equals the machine type on the
## runtime side; the exporter writes that key for you either way.
enum Kind {EXCAVATOR, CRANE, SKIDDER, LOADER}
@export var kind := Kind.EXCAVATOR
func _init() -> void:
	marker_color = Color(1.0, 0.69, 0.12)
func _label_text() -> String:
	return "MACHINE: %s" % Kind.keys()[kind].to_lower()
func kind_string() -> String:
	return Kind.keys()[kind].to_lower()
