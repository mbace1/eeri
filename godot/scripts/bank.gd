class_name Bank
extends RefCounted
## The dirt bank — the LOCK the excavator exists to open, ported from the
## Bank in js/main.js plus the dig stroke in js/excavator.js.
##
## It comes down a row at a time, and every row is a real bite of the stroke
## rather than a timer expiring. The owner's note on 2026-08-21 is the whole
## reason the stroke exists at all: the old version "takes a long time to push
## up and down for the block to disappear with very little indicators... it
## doesn't look like an excavator at work".
##
## TWO THINGS IT REFUSES TO ASK OF A SIX-YEAR-OLD, both learned:
##
##   1. Aiming the arm. In range is a fact about the MACHINE, not about the
##      boom. It used to also require driving the boom below 0.3 yourself,
##      with the same button that digs — so the first thing the game asked
##      for was to solve a control before it would let you dig.
##   2. Guessing what is diggable. Within reach the bank ARMS: it lifts and
##      pulses, because "a thing you can act on has to look different from a
##      thing you cannot".

## One bucketful, start to start. 0.46s reads as work rather than as a wait.
const STROKE := 0.46
## How far from the bank's centre the machine can still reach it.
const REACH_PAD := 3.2

var c0 := 0.0
var c1 := 0.0
var cy0 := 0.0
var rows := 0
var remaining := 0
var cleared := false

## Armed = in reach, so it is visibly diggable before anything is pressed.
var armed := false

# --- the stroke, from js/excavator.js -------------------------------------
var digging := false
var stroke_t := 0.0
## True for exactly the frame the bucket closes — one bite per stroke.
var bit := false

var boom := 0.52       # rest pose, from assets/README.md
var stick := -1.35
var bucket := -0.6


func _init(def: Dictionary) -> void:
	c0 = float(def.get("c0", 0))
	c1 = float(def.get("c1", 0))
	cy0 = float(def.get("cy0", 0))
	rows = int(def.get("rows", 0))
	remaining = rows


func centre() -> float:
	return (c0 + c1) * 0.5


## IN RANGE IS A FACT ABOUT THE MACHINE, not about where the arm happens to
## be pointing. Park next to it and hold the verb.
func in_reach(machine_x: float) -> bool:
	return absf(machine_x - centre()) < (c1 - c0) * 0.5 + REACH_PAD


## Advance the arm. `want_dig` is the held verb; `machine_x` decides reach.
## Sets `bit` true on the single frame the bucket closes through the cut.
func step(dt: float, machine_x: float, want_dig: bool) -> void:
	bit = false
	armed = in_reach(machine_x) and not cleared
	digging = want_dig and armed

	if not digging:
		stroke_t = 0.0
		boom = 0.52
		stick = -1.35
		bucket = -0.6
		return

	var prev := stroke_t
	stroke_t += dt / STROKE
	var k: float = fmod(stroke_t, 1.0)

	# 0..0.35 reach · 0.35..0.62 plunge · 0.62..0.78 curl (the bite) ·
	# 0.78..1 lift. Written as one curve so the arm never snaps between
	# phases: the boom is a dip and the stick a reach, half a beat apart.
	boom = 0.52 - 0.42 * sin(minf(1.0, k / 0.78) * PI)
	stick = -1.35 + 0.55 * sin(minf(1.0, k / 0.9) * PI)
	bucket = -0.6 - 0.9 * maxf(0.0, sin((k - 0.35) / 0.5 * PI))

	# The bite lands on the CURL, which is where a bucket actually takes
	# earth. Once per stroke, on the crossing.
	bit = k >= 0.62 and fmod(prev, 1.0) < 0.62
	if bit:
		_take()


func _take() -> void:
	if cleared:
		return
	remaining -= 1
	if remaining <= 0:
		remaining = 0
		cleared = true


## Top of the bank as it stands — the rows that are still there. Used by the
## level to decide what is solid, so digging really does open the way.
func top_y() -> float:
	return cy0 + float(remaining)
