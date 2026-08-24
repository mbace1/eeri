class_name SteamVent
extends RefCounted
## The steam vent — an environmental hazard, always telegraphed before it is
## lethal (DESIGN §3).
##
## THE TELL IS THE WHOLE THING. The collar glows for VENT_WARN seconds before
## anything comes out, and DESIGN §4.1 fixes that at >= 1.0s: "no hazard is
## lethal on the frame you first see it". A vent that blew without warning
## would be a memorisation test, which this game does not do — "difficulty
## comes from READING, never from reflex or memorisation".

## js/parts.js CLOCK.vent
const CYCLE := 3.2
const WARN := 1.05
const BLOW := 0.6

var x := 0.0
var y := 0.0
var t := 0.0
## Steady rather than flashing under reduced motion — the tell must still be
## readable, it just stops strobing.
var reduced_motion := false


func _init(level: LevelData, at_x: float, phase := 0.0) -> void:
	x = at_x
	y = level.ground_top(at_x, 8.0)
	# Staggered, so a row of vents does not fire as one wall.
	t = phase


func step(dt: float) -> void:
	t += dt


func blowing() -> bool:
	var k: float = fmod(t, CYCLE)
	return k > WARN and k < WARN + BLOW


## Lit before it blows. This is the readable half of the cycle.
func warning() -> bool:
	return fmod(t, CYCLE) <= WARN


func hits(px: float, py: float, phw: float, ph: float) -> bool:
	if not blowing():
		return false
	return absf(px - x) < phw + 0.42 and py < y + 2.2 and py + ph > y
