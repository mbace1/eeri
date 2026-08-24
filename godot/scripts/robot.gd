class_name Robot
extends RefCounted
## The small machines — a literal port of js/robots.js's Robot behaviour.
##
## DESIGN.md §3: never malicious, just site machines gone wandering. Each has
## exactly ONE behaviour and each is a different KIND of test:
##
##   hopper   a metronome on a fixed rhythm      — a timing test
##   roller   trundles its span, turns at edges  — a spacing test (too flat to
##            stomp comfortably, so you jump it)
##   bucket   sleeps, wakes when you LAND near   — a provocation test
##   skitter  patrols, notices, winds up, lunges — a reading test
##
## As in js/robots.js this is behaviour only. It carries no scene node and no
## mesh, so tests/test_robot.tscn can run every telegraph in bare headless
## Godot — the same split that lets kid.gd be simulated without a GPU.
##
## THE TIMINGS ARE THE DESIGN. parts.js exports them as CLOCK and the room
## prover reasons about them; they are copied here, not retuned. DESIGN §4.1
## fixes "telegraph >= 1.0s before anything can touch you", and for the
## skitter that is notice 0.45 + wind 0.62 = 1.07s of visible wind-up before
## the lunge can reach you.

# --- CLOCK, from js/parts.js -----------------------------------------------
const SKITTER_NOTICE := 0.45
const SKITTER_WIND := 0.62
const SKITTER_LUNGE := 0.5
const SKITTER_RECOVER := 0.7

const HOP_CYCLE := 1.35
const HOP_CROUCH := 0.28
const HOP_RISE := 1.25

const ROLL_SPEED := 2.4

const BKT_WAKE := 0.55
const BKT_CHASE := 2.2
const BKT_SPEED := 2.9
const BKT_SETTLE := 1.1
const BKT_HEAR := 3.4

# --- js/robots.js locals ---------------------------------------------------
const SEE := 5.2
const WALK := 1.5
const LUNGE_SPEED := 6.4

var level: LevelData
var kind := "skitter"
var c0 := 0.0
var c1 := 0.0
var deck                      # null, or a fixed y for a robot on a platform

var x := 0.0
var y := 0.0
var face := 1
var state := "patrol"
var t := 0.0
var hop := 0.0
var dead := false
var stompable := true
var shrug_t := 0.0
var was_air := false

var hw := 0.34
var h := 0.7


func _init(level_data: LevelData, span: Dictionary) -> void:
	level = level_data
	kind = String(span.get("kind", "skitter"))
	c0 = float(span.get("c0", 0))
	c1 = float(span.get("c1", 0))
	deck = span.get("cy", null)
	x = (c0 + c1 + 1.0) * 0.5

	# js/robots.js: the body sizes are per kind and they matter — a roller is
	# wide and flat, which is exactly why it is the one you jump instead.
	match kind:
		"roller":
			hw = 0.46
			h = 0.5
		"hopper":
			hw = 0.24
			h = 1.0
		"bucket":
			hw = 0.44
			h = 0.72
		_:
			hw = 0.34
			h = 0.7

	# A roller is too flat to land on cleanly, so it is NOT stompable — it
	# shrugs you off instead. That is what makes it a spacing test rather than
	# another timing test.
	stompable = kind != "roller"
	if kind == "bucket":
		state = "sleep"
	y = _floor_at(x)


func go(s: String) -> void:
	state = s
	t = 0.0


## Landed on and NOT stompable: it shoves you off, and for a moment it cannot
## also hit you for it. Without this beat, bouncing off a roller reads as
## bouncing off a roller AND walking into one in the same frame.
func shrug() -> void:
	shrug_t = 0.4


func kill() -> void:
	dead = true


func _floor_at(px: float) -> float:
	if deck != null:
		return float(deck)
	return level.ground_top(px, y + 1.2)


## target = {x, y, grounded}
func step(dt: float, target: Dictionary) -> void:
	if dead:
		return
	t += dt
	shrug_t = maxf(0.0, shrug_t - dt)
	var tx := float(target.get("x", 0.0))
	var ty := float(target.get("y", 0.0))
	var dx := tx - x
	var near: bool = absf(dx) < SEE and absf(ty - y) < 2.2

	# ---- the two kinds that never react ----------------------------------
	# Neither hunts. A hopper is a metronome and a roller is a moving wall;
	# both are read from across the screen and neither can surprise you, which
	# is what makes them fair for a six-year-old.
	if kind == "hopper" or kind == "roller":
		if kind == "roller":
			x += face * ROLL_SPEED * dt
			if x < c0:
				x = c0
				face = 1
			if x > c1 + 1.0:
				x = c1 + 1.0
				face = -1
			state = "roll"
		else:
			# a fixed rhythm, and the CROUCH is the tell: it gathers visibly on
			# the ground for about a third of a second before it leaves
			var k: float = fmod(t, HOP_CYCLE)
			var p: float = 0.0
			if k >= HOP_CROUCH:
				p = (k - HOP_CROUCH) / maxf(0.001, HOP_CYCLE - HOP_CROUCH)
			hop = sin(p * PI) * HOP_RISE
			state = "crouch" if k < HOP_CROUCH else "hop"
			if signf(dx) != 0.0:
				face = int(signf(dx))
		y = _floor_at(x) + hop
		return

	# ---- the bucket: asleep until you LAND beside it ----------------------
	# Waking is a landing, not a proximity radius, and that is the whole design
	# of it: walking past a sleeping bucket has to be safe, or the beat becomes
	# "never go near the pipe mouth" and the pipe stops being the way across.
	if kind == "bucket":
		var heard: bool = absf(dx) < BKT_HEAR and absf(ty - y) < 2.4
		var grounded: bool = target.get("grounded", false)
		var landed: bool = grounded and was_air
		was_air = not grounded
		if state == "sleep":
			if heard and landed:
				if signf(dx) != 0.0:
					face = int(signf(dx))
				go("wake")
		elif state == "wake":
			# the head lifts and the lamp comes up: the telegraph, and it does
			# not move an inch during it
			if t >= BKT_WAKE:
				go("chase")
		elif state == "chase":
			if signf(dx) != 0.0:
				face = int(signf(dx))
			x += face * BKT_SPEED * dt
			x = clampf(x, c0 - 0.5, c1 + 1.5)
			if t >= BKT_CHASE:
				go("settle")
		elif state == "settle":
			if t >= BKT_SETTLE:
				go("sleep")
		y = _floor_at(x)
		return

	# ---- the skitter: patrol, notice, wind, lunge, recover ----------------
	if state == "patrol":
		x += face * WALK * dt
		if x < c0:
			x = c0
			face = 1
		if x > c1 + 1.0:
			x = c1 + 1.0
			face = -1
		if near:
			if signf(dx) != 0.0:
				face = int(signf(dx))
			go("notice")
	elif state == "notice":
		if t >= SKITTER_NOTICE:
			go("wind")
	elif state == "wind":
		x -= face * 0.9 * dt                     # it draws back
		if t >= SKITTER_WIND:
			go("lunge")
	elif state == "lunge":
		x += face * LUNGE_SPEED * dt
		# it will not leave its own floor, ever
		x = clampf(x, c0 - 0.6, c1 + 1.6)
		if t >= SKITTER_LUNGE:
			go("recover")
	elif state == "recover":
		if t >= SKITTER_RECOVER:
			go("wind" if near else "patrol")

	y = _floor_at(x)


# ---- the predicates main.js resolves a collision with --------------------

func landed_on(px: float, py: float, phw: float, pvy: float) -> bool:
	if dead or pvy >= 0.0:
		return false
	if absf(px - x) > phw + hw + 0.18:
		return false
	return py >= y + h * 0.35 and py <= y + h + 0.85


func stomped_by(px: float, py: float, phw: float, pvy: float) -> bool:
	if not stompable or not landed_on(px, py, phw, pvy):
		return false
	kill()
	return true


## For the SKITTER only the lunge hurts — one patrolling about is scenery you
## step over, and that is what makes it a provocation test. A hopper or a
## roller has no lunge, so touching one is the cost: they are read by timing
## and spacing instead, and the way past both is over the top.
func hits(px: float, py: float, phw: float, ph: float) -> bool:
	if shrug_t > 0.0 or dead:
		return false
	var overlap: bool = absf(px - x) < phw + hw and py < y + h and py + ph > y
	if kind == "bucket":
		# ASLEEP IS HARMLESS. Otherwise the tell is decoration: something you
		# cannot walk past teaches nothing by lifting its head first.
		if state == "sleep" or state == "wake":
			return false
		return overlap
	if kind == "hopper" or kind == "roller":
		return overlap
	return state == "lunge" and overlap
