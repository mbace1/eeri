extends Node
## Proves the ported kinematics still clear the reach the twelve authored
## rooms were built against.
##
## TWO DIFFERENT NUMBERS LIVE HERE AND CONFUSING THEM COSTS AN HOUR.
##
##   The CLOSED FORM — js/parts.js REACH: jumpUp 2.646, jumpAcross 4.85.
##   Derived algebraically from the constants (v^2/2g etc). This is what the
##   room prover reasons with.
##
##   The DISCRETE reality — what the game actually does. Both builds integrate
##   semi-implicit Euler at a fixed step, which undershoots the closed form by
##   about v*dt/2: at 60Hz the real apex is 2.542, not 2.646.
##
## The discrete figure is the honest one and it is NOT a bug, because no room
## is authored to the ceiling: parts.js caps obstacles at step 2 and gap 4
## precisely so the difference between "measured" and "reliable under a thumb"
## is absorbed. So this file checks BOTH — the algebra (which catches someone
## retuning a constant) and the simulation against the AUTHORED ceilings
## (which catches the port actually being unplayable).
##
## Run: godot --headless --path godot res://tests/test_kid.tscn

const DT := 1.0 / 60.0

## What the authored rooms actually contain (js/parts.js REACH.step / .gap),
## and the slack parts.js calls the line between "measured" and "reliable
## under a thumb".
const AUTHORED_STEP := 2.0
const AUTHORED_GAP := 4.0
const MIN_SLACK := 0.5

## The discrete values at 60Hz, recorded from this port and matching the JS
## integration order frame for frame. Tight tolerance on purpose: this is the
## regression guard on the *integration*, where the algebra checks below are
## the guard on the *constants*. Loosen either and the port can drift.
const APEX_60 := 2.542
const ACROSS_60 := 4.753
const BASELINE_TOL := 0.03

## Every check this file intends to run. A compile error in a depended script
## once let four simulated checks silently not run while this still printed
## ALL GREEN — "a gate that cannot fail is a finding, not a pass". A skipped
## block is now a failure rather than a quieter success.
const EXPECTED := 19

var _pass := 0
var _fail := 0


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("KID FAIL: timed out")
		get_tree().quit(1))
	add_child(bail)
	bail.start()

	print("── Eeri — the ported reach budget ──")

	var lvl := LevelData.load_slug("eeri-1-1")
	check("level 1-1 loads", lvl != null)
	if lvl == null:
		_finish()
		return
	check("it is the room the roster names", lvl.display_name.contains("GROUNDWORKS"), lvl.display_name)
	check("the grid is the authored size", lvl.w == 96 and lvl.h == 18, "%dx%d" % [lvl.w, lvl.h])
	check("the ground row is solid under spawn", lvl.solid_cell(10, lvl.ground - 1))
	check("the air above it is not", not lvl.solid_cell(10, lvl.ground + 1))

	_check_constants()
	_check_jump_up(lvl)
	_check_jump_across(lvl)
	_check_respawn(lvl)

	_finish()


## The algebra, straight off the constants. Catches a retuned JUMP_V before a
## single frame is simulated.
func _check_constants() -> void:
	print("  -- the constants (algebra) --")
	var jump_up: float = (Kid.JUMP_V * Kid.JUMP_V) / (2.0 * Kid.GRAV)
	check("JUMP_V/GRAV still give REACH.jumpUp 2.646", absf(jump_up - 2.646) < 0.002,
		"got %.4f" % jump_up)
	var t_up: float = Kid.JUMP_V / Kid.GRAV
	var t_down: float = sqrt(2.0 * jump_up / (Kid.GRAV * Kid.FALL_X))
	var across: float = Kid.RUN * (t_up + t_down)
	check("RUN/GRAV/FALL_X still give REACH.jumpAcross 4.85", absf(across - 4.85) < 0.02,
		"got %.4f" % across)
	check("a stomp bounce cannot out-reach a jump", Kid.BOUNCE_V < Kid.JUMP_V,
		"bounce %.2f vs jump %.2f" % [Kid.BOUNCE_V, Kid.JUMP_V])


func _check_jump_up(lvl: LevelData) -> void:
	print("  -- a standing jump (simulated) --")
	var k := Kid.new(lvl, 10.5, float(lvl.ground))
	for i in 10:
		k.step(DT, {})
	var y0: float = k.y
	check("he starts grounded", k.grounded, "y=%.3f" % y0)

	var peak: float = y0
	k.step(DT, {"jump_pressed": true, "jump_held": true})
	for i in 400:
		k.step(DT, {"jump_held": true})
		peak = maxf(peak, k.y)
		if k.grounded and k.vy <= 0.0 and i > 5:
			break
	var rise: float = peak - y0
	check("the apex matches the 60Hz baseline (%.3f)" % APEX_60,
		absf(rise - APEX_60) < BASELINE_TOL, "rose %.3f" % rise)
	check("…which clears the authored 2-tile step with real slack",
		rise - AUTHORED_STEP >= MIN_SLACK, "slack %.3f tiles" % (rise - AUTHORED_STEP))
	check("…and he comes back down to the floor", absf(k.y - y0) < 0.05, "y=%.3f" % k.y)


func _check_jump_across(lvl: LevelData) -> void:
	print("  -- a running jump (simulated) --")
	var k := Kid.new(lvl, 6.5, float(lvl.ground))
	for i in 10:
		k.step(DT, {})
	for i in 60:
		k.step(DT, {"ax": 1.0})
	check("he reaches full run speed", absf(k.vx - Kid.RUN) < 0.05, "vx=%.3f" % k.vx)

	var y0: float = k.y
	var x0: float = k.x
	k.step(DT, {"ax": 1.0, "jump_pressed": true, "jump_held": true})
	var airborne := 0
	for i in 400:
		k.step(DT, {"ax": 1.0, "jump_held": true})
		airborne += 1
		if k.grounded and k.vy <= 0.0 and airborne > 5:
			break
	var across: float = k.x - x0
	check("the carry matches the 60Hz baseline (%.3f)" % ACROSS_60,
		absf(across - ACROSS_60) < BASELINE_TOL, "carried %.3f" % across)
	check("…which clears the authored 4-tile gap with real slack",
		across - AUTHORED_GAP >= MIN_SLACK, "slack %.3f tiles" % (across - AUTHORED_GAP))
	# It must ALSO not quietly reach further than the design allows, or a room
	# authored to be impassable on foot stops being so.
	check("…but a 5-tile gap still does not go", across < 5.0, "carried %.3f" % across)
	check("…and he lands back on the ground", absf(k.y - y0) < 0.05, "y=%.3f" % k.y)


func _check_respawn(lvl: LevelData) -> void:
	print("  -- falling out of the world --")
	var k := Kid.new(lvl, 40.0, 6.0)
	k.y = 0.5
	k.step(DT, {})
	check("he respawns rather than falling forever", k.y > 0.9, "y=%.3f" % k.y)
	check("…and not back at the level start", k.x > 5.0, "x=%.3f" % k.x)


func _finish() -> void:
	var ran := _pass + _fail
	if ran != EXPECTED:
		_fail += 1
		print("  FAIL - only %d of %d checks ran — a depended script probably failed to compile" % [ran, EXPECTED])
	print("")
	print("%d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		get_tree().quit(1)
	else:
		print("ALL GREEN")
		get_tree().quit(0)


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("  ok  - %s" % label)
	else:
		_fail += 1
		print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
