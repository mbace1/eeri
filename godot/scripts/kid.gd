class_name Kid
extends RefCounted
## Eeri's platforming body — a LITERAL port of js/kid.js's Player.
##
## Every constant below is copied, not retuned. They are not taste: DESIGN.md
## §4 fixes a reach budget (apex 2.65 tiles, run-jump 4.85 across, every gap
## proved with a full tile of slack, no pixel-precision jumps ever) and
## test/rooms.mjs proves all twelve authored rooms against exactly these
## numbers. Change one and 246 checks are describing a game that no longer
## exists — and the person who finds out is a six-year-old stuck at a jump.
##
## This is also why it is a RefCounted holding its own integration rather than
## a CharacterBody3D: move_and_slide is frame- and solver-dependent, and the
## prover's guarantees only hold over the arithmetic it was written against.
## Godot supplies the scene, the model and the camera; it does not supply the
## physics. See GODOT_PORT_ANALYSIS.md §3.2.

# --- the platforming body (Mario grammar: snappy, committed) --------------
const RUN := 6.2
const ACC := 42.0
const ACC_AIR := 20.0
const FRIC := 34.0
const GRAV := 30.0
const FALL_X := 1.35        # gravity multiplier while descending
const JUMP_V := 12.6
const TERMINAL := -22.0
## A stomp bounces you 80% of a jump: enough to feel like a reward and to
## chain along a row of them, never enough to reach somewhere a jump cannot —
## so no level's reach budget is quietly broken by an enemy standing there.
const BOUNCE_V := JUMP_V * 0.8
const COYOTE := 0.09
const BUFFER := 0.12
## Slower than the run, both ways, so a ladder reads as a decision not a lift.
const CLIMB_V := 3.6
const BELT := 2.6
const TARP_V := 17.5
## Shallow water caps the RUN, never the acceleration and never the jump —
## a jump that got shorter in water would silently break every room the
## prover has already passed.
const WADE := 0.55
## Below this he is walking, above it running (js/kid.js WALK_MAX).
const WALK_MAX := 3.4

const HW := 0.3     # half-width
const BH := 1.5     # height

var level: LevelData

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var grounded := false
var grounded_t := 0.0
var jump_buf_t := 0.0
var cut_jump := false
var climbing := false
var facing := 1
var t := 0.0
var squash := 0.0
var mercy_t := 0.0
var last_checkpoint = null
## Platforms that are not tiles — hoists. The player never learns what KIND
## of thing is carrying it.
var platforms: Array = []
## The one carrying him, kept ACROSS frames. That is the only way to tell
## landing from riding; see the platform pass in step().
var carrier = null

# one-frame events for sound/FX to hang off, exactly as js/kid.js exposes them
var just_jumped := false
var just_landed := false
var just_bounced := false
var just_struck := false


func _init(level_data: LevelData, spawn_x: float, spawn_y: float) -> void:
	level = level_data
	x = spawn_x
	y = spawn_y


## Bounced off something landed on — a stomp, or a tarp.
func bounce() -> void:
	vy = BOUNCE_V
	cut_jump = false
	squash = 0.14
	just_bounced = true


## Knocked back. DESIGN §4.1 is unusually blunt about this and it is the
## whole damage model: "Eeri is never hurt, never dies, has no health bar. A
## hit shoves him and grants mercy frames; a pit costs a respawn at the
## checkpoint. Nothing else ever happens to him."
##
## Returns false if the hit was eaten by mercy frames, so the caller can tell
## a real hit from a repeat and not count it twice.
func struck(from_x: float) -> bool:
	if mercy_t > 0.0:
		return false
	mercy_t = 1.3
	vx = (-1.0 if x < from_x else 1.0) * 7.5
	vy = 7.0
	just_struck = true
	return true


## `input` is a Dictionary: {ax: float, jump_pressed: bool, jump_held: bool,
## up_held: bool, down_held: bool}. Edge consumption is the caller's job, the
## same split js/input.js and js/kid.js keep — take() there, take() there.
func step(dt: float, input: Dictionary) -> void:
	t += dt
	just_jumped = false
	just_landed = false
	just_bounced = false
	just_struck = false
	if mercy_t > 0.0:
		mercy_t -= dt
	if squash > 0.0:
		squash = max(0.0, squash - dt * 1.6)

	var was_grounded := grounded
	var ax := float(input.get("ax", 0.0))
	var up_held: bool = input.get("up_held", false)
	var down_held: bool = input.get("down_held", false)
	var jump_pressed: bool = input.get("jump_pressed", false)
	var jump_held: bool = input.get("jump_held", false)

	# ---- the ladder ------------------------------------------------------
	# Checked before the run, because a ladder overrides horizontal control.
	var on_ladder := level.climb_at(x, y) or level.climb_at(x, y + BH * 0.5)
	if on_ladder and (up_held or down_held):
		climbing = true
	elif climbing and (grounded or not on_ladder):
		climbing = false

	if climbing:
		var up := 0.0
		if up_held:
			up = 1.0
		elif down_held:
			up = -1.0
		vy = up * CLIMB_V
		vx = 0.0
		# Pinned to the rungs and climbing straight — within half a tile looks
		# like holding air beside the ladder rather than holding the ladder.
		var mid: float = floor(x) + 0.5
		x += (mid - x) * min(1.0, 12.0 * dt)
		var top := level.climb_top(x, y)
		var my_c := level.move_y(x, y, HW, BH, vy * dt)
		y = my_c["y"]
		# top out with the feet ON the deck, never a rung above it
		if top >= 0.0 and y > top:
			y = top
			vy = 0.0
		grounded = level.is_grounded(x, y, HW)
		grounded_t = COYOTE if grounded else 0.0
		_check_fall()
		return

	# ---- horizontal: accelerate hard, stop hard --------------------------
	# tap = a step, hold = a run.
	var acc: float = ACC if grounded else ACC_AIR
	# Wading caps the top speed, not the acceleration: you get up to speed as
	# sharply as ever and simply cannot go as fast, which reads as heavy water
	# rather than as sluggish controls.
	var top_speed := RUN
	if grounded and _water_at(x, y):
		top_speed = RUN * WADE
	if ax != 0.0:
		vx += ax * acc * dt
		vx = clampf(vx, -top_speed, top_speed)
		facing = 1 if ax > 0.0 else -1
	elif grounded:
		var s := signf(vx)
		vx -= s * FRIC * dt
		if signf(vx) != s:
			vx = 0.0

	# ---- jump: buffered + coyote, variable height on release -------------
	if jump_pressed:
		jump_buf_t = BUFFER
	else:
		jump_buf_t -= dt
	if jump_buf_t > 0.0 and grounded_t > 0.0:
		vy = JUMP_V
		jump_buf_t = 0.0
		grounded_t = 0.0
		just_jumped = true
		cut_jump = true          # his jump, so his to cut short
	if cut_jump and not jump_held and not up_held and vy > 4.0:
		vy = 4.0

	vy -= GRAV * (FALL_X if vy < 0.0 else 1.0) * dt
	vy = max(vy, TERMINAL)

	var mx := level.move_x(x, y, HW, BH, vx * dt)
	x = mx["x"]
	if mx["hit"]:
		vx = 0.0

	var was_at := y                       # ...for the platform pass
	var my := level.move_y(x, y, HW, BH, vy * dt)
	y = my["y"]
	if my["hit"]:
		# A TARP ANSWERS A LANDING WITH A BIGGER ONE, and it is checked BEFORE
		# the landing is zeroed, because the bounce IS the landing.
		if my["grounded"] and level.tarp_at(x, my["y"]) and vy < -1.0:
			vy = TARP_V
			cut_jump = false        # …and this one is the tarp's, not his
			squash = 0.14
			just_bounced = true
		else:
			if my["grounded"] and vy < -9.0:
				squash = 0.12       # hard landing
			vy = 0.0
	grounded = my["grounded"] or level.is_grounded(x, y, HW)

	# ---- THE PLATFORM PASS ----------------------------------------------
	# The one place in this game where the floor is not a tile. It runs AFTER
	# the tile pass, so a tile always wins: standing on solid ground is never
	# overridden by a hoist passing underneath.
	#
	# Two ways to be on one, and they are genuinely different questions:
	#
	#   LANDING — falling, and the feet CROSSED the deck between last frame
	#   and this one. Tested as a crossing rather than an overlap, or a fast
	#   fall tunnels straight through a platform one tile thick.
	#
	#   RIDING — already carried, still over it, not jumping. This is what a
	#   RISING hoist needs: it comes UP into the feet, so the crossing test
	#   can never fire, and without this branch the player sinks through a
	#   lift that is travelling towards them.
	var on_deck = null
	for h in platforms:
		if not h.overlaps(x, HW):
			continue
		var deck: float = h.top(x)
		var landing: bool = vy <= 0.0 and was_at >= deck - 0.02 and y <= deck + 0.02
		var riding: bool = carrier == h and vy <= 0.01 and absf(y - deck) < 0.7
		if landing or riding:
			on_deck = h
			break
	if on_deck != null:
		y = on_deck.top(x)
		vy = 0.0
		grounded = true
	carrier = on_deck

	# THE BELT MOVES THE FLOOR, so it is applied after the move and does not
	# touch vx — you still run at your own speed, on ground that disagrees
	# with you.
	if grounded:
		var belt := level.belt_at(x, y)
		if belt != 0:
			x = level.move_x(x, y, HW, BH, float(belt) * BELT * dt)["x"]

	grounded_t = COYOTE if grounded else grounded_t - dt
	if grounded and not was_grounded:
		just_landed = true

	_check_fall()


func _water_at(px: float, py: float) -> bool:
	return level.water_at(px, py)


func _check_fall() -> void:
	# The pit floor is dressing, not ground.
	if y < 0.9:
		var r := level.fall_respawn(x, last_checkpoint)
		x = r.x
		y = r.y
		vx = 0.0
		vy = 0.0


## What the visual should be doing — the same state names js/kid.js maps to
## clips (CLIP_FOR), so the model side can stay ignorant of the body.
func visual_state() -> String:
	if climbing:
		return "climb"
	if not grounded:
		return "air"
	if absf(vx) < 0.1:
		return "idle"
	return "walk" if absf(vx) < WALK_MAX else "run"
