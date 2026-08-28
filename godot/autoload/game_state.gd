extends Node
## Placeholder for the one serialisable run state (EERI_GODOT_HANDOFF.md §4).
##
## Nothing reads or writes this yet — no level, no kid, no rooms.js
## equivalent exists on this side. It exists now so a future scene has
## somewhere to put state that is not itself, the same reason app_shell in
## the Piritori port never keeps a second copy of cash or day.
##
## The browser build has no mid-run save today either (DESIGN.md is silent
## on it), so there is no existing contract to match — decide this with the
## owner before wiring a save format, do not invent one.

var current_world := 1
var current_level := 1
var bolts_collected := 0
## A world is three levels and CLOCKING OUT is its curtain (DESIGN §4.2) —
## Eeri walking out through a gate, not something a level does.
var worlds_cleared := 0
var golden_collected := 0
var blueprints := 0

## js/main.js's worldGolden/worldOfGolden -- the running count of golden
## bolts banked toward THIS world's clock-out building, separate from
## golden_collected's session-wide total. Keyed on the world rather than the
## level index so a deep link or a level jump into the middle of a world
## does not arrive carrying the PREVIOUS world's nine.
var world_golden := 0
var world_of_golden := -1


func reset() -> void:
	current_world = 1
	current_level = 1
	bolts_collected = 0
	worlds_cleared = 0
	golden_collected = 0
	blueprints = 0
	world_golden = 0
	world_of_golden = -1
