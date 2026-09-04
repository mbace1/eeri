class_name Plank
extends RefCounted
## THE TIPPING PLANK — World 2's own gizmo (v15.46, ported from js/plank.js).
##
## It has no held verb and no cycle to read, unlike every other gizmo in this
## game (a hoist runs a period, a dig is a held button) — it answers WEIGHT.
## A rigid beam pivots at its own centre; standing anywhere but dead centre
## sinks that side and lifts the other. Crossing is one committed walk through
## the tip, not a timed jump or a button held at a target — the newest of the
## "no aiming, no hold" family this game keeps building (the flattener being
## the other one).
##
## THE CONTRACT is hoist.gd's own — `top(x)` / `overlaps(x, hw)`, read by
## kid.gd's platform pass — generalised the one way a hoist never needed. A
## hoist's deck is flat, so its `top()` never looked at x; a tipped plank's
## deck genuinely is not, which is where that argument earns its keep.
##
## WHO DRIVES THE TILT: not this file. play.gd's own per-frame loop calls
## `step(dt, rider_x, rider_hw)` the same way it drives every other
## cross-entity interaction (the dig, the girder, the flatten), because a
## plank that reached into Kid to read its own rider would be the one entity
## here that knows about the thing riding it — and every other one is
## deliberately ignorant of that.

## js/parts.js PLANK_DROP — how far an end can sink. Shared there so the room
## prover and the entity agree on how far it can tip; the same single number
## is what makes a 7-tile trench crossable at all.
const DROP := 1.2

var c0 := 0.0
var c1 := 0.0
var cy0 := 0.0
var hw := 0.0
var x := 0.0
## -1 (left end down) … +1 (right end down)
var tilt := 0.0


func _init(def: Dictionary) -> void:
	c0 = float(def.get("c0", 0))
	c1 = float(def.get("c1", 0))
	cy0 = float(def.get("cy0", 0))
	hw = (c1 - c0 + 1.0) * 0.5
	x = (c0 + c1 + 1.0) * 0.5


## The surface height at world column `px` — the whole reason this takes an
## argument. Linear across the board and clamped to its own ends, matching a
## rigid beam rather than a rope.
func top(px: float = 0.0) -> float:
	var dx: float = clampf(px - x, -hw, hw)
	return cy0 - tilt * DROP * (dx / hw)


func overlaps(px: float, phw: float) -> bool:
	return absf(px - x) < hw + phw


## Called once a frame IN EVERY MODE — the same reason hoists animate while
## you are in a cab: a plank that froze the instant you drove past it would
## settle to a different tilt than the one you left it at, and arrive back
## under you having silently moved.
func step(dt: float, rider_x, rider_hw := 0.0) -> void:
	# The target is the rider's own offset across the half-width, so standing
	# at an END asks for the full tip and standing at CENTRE asks for level —
	# the board is asked to do exactly what your weight is doing.
	var target := 0.0
	if rider_x != null and overlaps(float(rider_x), rider_hw):
		target = clampf((float(rider_x) - x) / hw, -1.0, 1.0)
	tilt += (target - tilt) * minf(1.0, 6.0 * dt)


## The z rotation that draws it. The board is modelled along its own local x
## from -hw to +hw at y = 0, so one rotation about the group's own centre is
## the whole animation — no per-vertex work, the same trick the excavator's
## boom uses for its own joint.
func angle() -> float:
	return -atan2(tilt * DROP, hw)
