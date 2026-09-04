class_name Machine
extends RefCounted
## The ride — a port of js/excavator.js's drive body.
##
## DESIGN.md §1: the ride is "a REWARD and a change of gear, not a puzzle".
## Thirty to forty seconds, board at a marked point, ride a stretch no amount
## of jumping could cross, step off at the far end.
##
## THE SCALE RULE (DESIGN §1) is what ties it to robot.gd: big machines you
## RIDE, small machines you DODGE. Both are Tonka x Cat, both belong to the
## site; the contrast is size and intent.
##
## ART_BRIEF §1.2: a machine is DANGEROUS UNTIL IT IS YOURS. Untamed it works
## its own cycle — not hunting anybody, just heavy and blind — and the empty
## seat is how a player tells an unmanned machine from a tamed one. Mounting
## is what tames it.
##
## Behaviour only, no scene node, same as kid.gd and robot.gd.

## Per KIND, from js/excavator.js and js/crane.js. The crane is slower and
## heavier: it carries a swinging weight, and DESIGN's scale rule means the
## bigger machine is the more committed one.
## All four types the LEVEL DATA declares. It has always named them —
## excavator, crane, skidder, loader — and picking crane-if-there-is-a-wall
## else excavator gave a forest clearing and a night earthworks the same
## yellow digger. The `arm` figures the data carries are its reach.
## CORRECTED against js/excavator.js and js/crane.js directly (both files
## fix TOP/ACCEL/hw/h as MODULE-LEVEL constants, not per-instance fields) --
## the previous table here gave skidder and loader their own invented
## speeds and sizes, which the real game does not: every Excavator-classed
## machine (excavator, skidder, loader, flattener) shares excavator.js's
## one set of numbers, and only Crane -- a genuinely separate class -- has
## its own. Found while sourcing the flattener's own entry, same as the
## palette constants two sessions ago: read the file, do not recall it.
const SPEC := {
	"excavator": {"top": 3.4, "accel": 4.2, "hw": 1.42, "h": 2.1},
	"crane":     {"top": 2.8, "accel": 3.4, "hw": 1.6, "h": 2.3},
	"skidder":   {"top": 3.4, "accel": 4.2, "hw": 1.42, "h": 2.1},
	"loader":    {"top": 3.4, "accel": 4.2, "hw": 1.42, "h": 2.1},
	# World 1's road roller (v15.45, js/flattener.js) -- an Excavator-classed
	# machine like skidder and loader, so it shares the same numbers.
	"flattener": {"top": 3.4, "accel": 4.2, "hw": 1.42, "h": 2.1},
}
## Kept as the excavator's, because test_ride asserts against them and they
## are the figures DESIGN reasons about.
const TOP := 3.4
const ACCEL := 4.2
const GRAV := 30.0

## The wrecking ball's own clock (js/crane.js).
const WIND := 0.7
const SWING := 0.95
const RESET := 0.7

var level: LevelData
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var face := 1
var t := 0.0
## Untamed until boarded (ART_BRIEF §1.2).
var tamed := false
## A slung load halves the pace: carrying is a commitment, not a stroll.
var carrying := false

var kind := "excavator"
var hw := 1.4
var h := 2.1

## The swing, on the wrecking ball's own clock: it winds back, and only THEN
## does it come through. rest -> wind -> strike -> rest.
var swing := "rest"
var swing_t := 0.0
var struck_this_swing := false


var _top := TOP
var _accel := ACCEL


func _init(level_data: LevelData, sx: float, sy: float, machine_kind := "excavator") -> void:
	level = level_data
	x = sx
	y = sy
	kind = machine_kind
	var spec: Dictionary = SPEC.get(kind, SPEC["excavator"])
	_top = float(spec["top"])
	_accel = float(spec["accel"])
	hw = float(spec["hw"])
	h = float(spec["h"])


func tame() -> void:
	tamed = true


## THE THREAT BEFORE IT IS TAMED (ART_BRIEF §1.2). Ported from js/excavator.js
## work() and js/crane.js work() -- an untamed machine is not a static prop,
## it runs a slow cycle of its own. Only the excavator's version is actually
## dangerous (js: "the bucket sweeping low IS the danger, and the lift is the
## window you mount in"); the crane only sways.
##
## NOT PORTED, named rather than silently dropped: js/excavator.js's animate()
## eases boom/stick through a full spring with overshoot-and-settle, couples
## the bucket's curl to the boom angle, rolls the wheels, and spins the
## beacon. This gives the same TARGET motion and the same danger window off
## a simple ease -- the extra polish on top of it is a separate, later pass.
var boom := 0.52     # rest pose, assets/README.md's authored rig
var stick := -1.35
var boom_target := 0.52
var stick_target := -1.35

func work(dt: float) -> void:
	t += dt
	if kind == "excavator":
		var ph := t * 0.62
		boom_target = 0.5 + sin(ph) * 0.42   # js/excavator.js work(), unchanged
		stick_target = -1.2 + sin(ph + 0.9) * 0.34
	else:
		# crane and anything else standing untamed: a gentle sway, never a
		# strike -- only the excavator's bucket sweeps low enough to matter.
		boom_target = 0.42 + sin(t * 0.4) * 0.1
	boom += (boom_target - boom) * minf(1.0, 5.0 * dt)
	stick += (stick_target - stick) * minf(1.0, 5.0 * dt)
	vx = 0.0
	vy -= GRAV * dt
	var my := level.move_y(x, y, hw, h, vy * dt)
	y = my["y"]
	if my["hit"]:
		vy = 0.0


## js/excavator.js: "get swinging() { return this.n.boom.rotation.z < 0.34; }"
## -- true for the half of the cycle that will knock you flat. Only the
## excavator carries this window; a swaying crane never does.
func swinging() -> bool:
	return kind == "excavator" and boom < 0.34


## js/main.js unmannedStrike()'s bucket-side test. Approximated off the
## MACHINE'S OWN centre rather than the bucket tip's world position -- the
## same coarseness can_mount() already uses for its own reach check, and fair
## here because the machine does not move while unmanned (vx is held at 0).
func unmanned_danger(px: float, py: float) -> bool:
	if tamed or not swinging():
		return false
	return absf(x - px) < 1.2 and py < y + h + 0.3


## `drive` is -1, 0 or 1.
func step(dt: float, drive: float) -> void:
	t += dt

	# Heavy ease in and out — weight is the whole act.
	var target := drive * _top * (0.55 if carrying else 1.0)
	vx += (target - vx) * minf(1.0, _accel * dt)
	if absf(vx) < 0.02 and drive == 0.0:
		vx = 0.0
	if drive != 0.0:
		face = int(signf(drive))

	vy -= GRAV * dt
	var mx := level.move_x(x, y, hw, h, vx * dt)

	# A MACHINE REFUSES A CLIFF. It stops at the lip rather than driving off,
	# which is what keeps a ride a reward instead of a way to lose one.
	var dir := signf(vx)
	if dir == 0.0:
		dir = float(face)
	var ahead: float = mx["x"] + dir * hw
	if level.is_grounded(x, y, hw) and level.ground_top(ahead, y + 0.5) < y - 1.5:
		vx = 0.0
	else:
		x = mx["x"]
		if mx["hit"]:
			vx = 0.0

	var my := level.move_y(x, y, hw, h, vy * dt)
	y = my["y"]
	if my["hit"]:
		vy = 0.0


## Start a swing; ignored if one is already running. THE WIND-UP IS THE
## TELEGRAPH — DESIGN §4.1 wants >= 1.0s before anything can touch you, and
## the ball only becomes dangerous partway INTO the strike (see striking()).
func heave() -> bool:
	if swing != "rest":
		return false
	swing = "wind"
	swing_t = 0.0
	struck_this_swing = false
	return true


## The ball is only dangerous through the middle of the strike, never on the
## wind-up and never on the follow-through.
func striking() -> bool:
	return swing == "strike" and swing_t > 0.18 and swing_t < 0.62


func step_swing(dt: float) -> void:
	if swing == "rest":
		return
	swing_t += dt
	if swing == "wind" and swing_t >= WIND:
		swing = "strike"
		swing_t = 0.0
	elif swing == "strike" and swing_t >= SWING:
		swing = "reset"
		swing_t = 0.0
	elif swing == "reset" and swing_t >= RESET:
		swing = "rest"
		swing_t = 0.0


## Where the rider sits, and where the mount move passes through. The real
## GLB declares `seat` and `step` nodes (assets/README.md); these are the
## fallback offsets for the greybox, in the same places.
## WHERE THE WORKING END ACTUALLY IS -- js/excavator.js bucketWorld().
##
## THIS IS NOT COSMETIC AND THE APPROXIMATION IT REPLACES WAS A REAL BUG. The
## sheet is SOLID TERRAIN: a machine drives up to it and stops a body-width
## short, exactly as it does at a bank. Testing the flatten range against the
## machine's own centre therefore never passed -- the excavator parked at
## 56.58 against a sheet starting at 58 and drove at it forever, which is the
## same class of failure test_playthrough's own comment already records about
## the bank ("it parks at 82.6 against a bank centred on 86").
##
## The drum hangs off `boom` at x 1.05 with the barrel a further 0.05 along
## (scripts/rigs.gd flattener()), so the working end reaches ~1.1 ahead of
## the body -- which is what puts it over the metal while the machine itself
## is still short of it.
const ARM_REACH := 1.1

func bucket_x() -> float:
	return x + float(face) * ARM_REACH


func seat_pos() -> Vector2:
	return Vector2(x - face * 0.1, y + 1.25)


func step_pos() -> Vector2:
	return Vector2(x + face * 0.95, y + 0.55)


## Close enough, and standing, to climb aboard. js/main.js nearExc().
func can_mount(px: float, py: float, grounded: bool) -> bool:
	return absf(px - x) < 2.6 and py > y - 1.0 and py < y + 2.4 and grounded
