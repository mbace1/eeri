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


func reset() -> void:
	current_world = 1
	current_level = 1
	bolts_collected = 0
