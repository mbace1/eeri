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

const TOP := 3.4
const ACCEL := 4.2
const GRAV := 30.0

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

var hw := 1.4
var h := 2.1


func _init(level_data: LevelData, sx: float, sy: float) -> void:
	level = level_data
	x = sx
	y = sy


func tame() -> void:
	tamed = true


## `drive` is -1, 0 or 1.
func step(dt: float, drive: float) -> void:
	t += dt

	# Heavy ease in and out — weight is the whole act.
	var target := drive * TOP * (0.55 if carrying else 1.0)
	vx += (target - vx) * minf(1.0, ACCEL * dt)
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


## Where the rider sits, and where the mount move passes through. The real
## GLB declares `seat` and `step` nodes (assets/README.md); these are the
## fallback offsets for the greybox, in the same places.
func seat_pos() -> Vector2:
	return Vector2(x - face * 0.1, y + 1.25)


func step_pos() -> Vector2:
	return Vector2(x + face * 0.95, y + 0.55)


## Close enough, and standing, to climb aboard. js/main.js nearExc().
func can_mount(px: float, py: float, grounded: bool) -> bool:
	return absf(px - x) < 2.6 and py > y - 1.0 and py < y + 2.4 and grounded
