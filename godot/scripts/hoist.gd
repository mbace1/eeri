class_name Hoist
extends RefCounted
## A lift platform — the one place in this game where the floor is not a tile.
## Ported from js/hoist.js.
##
## A TRIANGLE, NOT A SINE, and that is the whole design of it. The hoist has
## to be READ — you wait for it, and waiting is only fair if the arrival is
## predictable — and a sine spends most of its time near the ends, which reads
## as a lift that hesitates. Constant speed with a hard turn is what a real
## one does.

var c0 := 0.0
var c1 := 0.0
var cy0 := 0.0
var cy1 := 0.0
var period := 4.0

var x := 0.0
## The TOP surface — the thing the player stands on — so nothing downstream
## has to add half a thickness to work out where the floor is.
var y := 0.0
var vy := 0.0
var hw := 0.5
var t := 0.0

## Parked at the bottom rather than frozen mid-shaft. A lift stopped halfway
## is a floor nobody can reach and a level nobody can finish: the game must
## still be completable with the animation off.
var reduced_motion := false


func _init(def: Dictionary) -> void:
	c0 = float(def.get("c0", 0))
	c1 = float(def.get("c1", 0))
	cy0 = float(def.get("cy0", 0))
	cy1 = float(def.get("cy1", 0))
	period = float(def.get("period", 4))
	if period <= 0.0:
		period = 4.0
	hw = (c1 - c0 + 1.0) * 0.5
	x = (c0 + c1 + 1.0) * 0.5
	y = cy0


## Where the shaft's head sits, in world y.
func head_y() -> float:
	return cy1 + 1.3


func step(dt: float) -> void:
	t = fmod(t + dt / period, 1.0)
	var k: float = t * 2.0 if t < 0.5 else 2.0 - t * 2.0     # 0 -> 1 -> 0
	var was := y
	y = cy0 + (cy1 - cy0) * k
	vy = (y - was) / dt if dt > 0.0 else 0.0
	if reduced_motion:
		y = cy0
		vy = 0.0


## What the player's platform pass reads. Deliberately the same loose shape
## Robot.landed_on uses, so the player never learns what kind of thing is
## carrying it.
## TAKES AN X, and a hoist ignores it -- js/plank.js: "a hoist's deck is
## flat, so top() never looked at x. A tipped plank's deck genuinely is not
## flat, so top(x) is where that generalisation actually earns its keep."
func top(_px: float = 0.0) -> float:
	return y


func overlaps(px: float, phw: float) -> bool:
	return absf(px - x) < hw + phw
