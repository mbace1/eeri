extends Node
## The small machines, and the rules that make them fair.
##
## DESIGN.md §4.1 for a six-year-old: "telegraph >= 1.0s before anything can
## touch you", nothing malicious, everything readable. Those are checkable
## claims, so this checks them — against the CLOCK timings parts.js exports
## and the room prover reasons about.
##
## Run: godot --headless --path godot res://tests/test_robot.tscn

const DT := 1.0 / 60.0
const EXPECTED := 38

var _pass := 0
var _fail := 0
var _lvl: LevelData


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("ROBOT FAIL: timed out")
		get_tree().quit(1))
	add_child(bail)
	bail.start()

	print("── Eeri — the small machines ──")
	_lvl = LevelData.load_slug("eeri-1-1")
	check("a level to stand them on", _lvl != null)
	if _lvl == null:
		_finish()
		return

	_check_roster()
	_check_skitter_telegraph()
	_check_hopper()
	_check_roller()
	_check_bucket()
	_check_stomp()
	_check_vent()
	_finish()


func _mk(kind: String, a := 10.0, b := 20.0) -> Robot:
	return Robot.new(_lvl, {"kind": kind, "c0": a, "c1": b})


func _check_roster() -> void:
	print("  -- the roster --")
	for k in ["skitter", "hopper", "bucket", "roller"]:
		var r := _mk(k)
		check("a %s stands on the ground" % k, r.y > 0.0, "y=%.2f" % r.y)
	# The scale rule that ties the game together (DESIGN §1): big machines you
	# ride, small machines you dodge. Every one of these is small.
	check("a roller is not stompable (too flat — you jump it)", not _mk("roller").stompable)
	check("everything else IS stompable",
		_mk("skitter").stompable and _mk("hopper").stompable and _mk("bucket").stompable)


## The one that can actually reach out and touch you, so the one whose
## wind-up has to satisfy the >= 1.0s rule.
func _check_skitter_telegraph() -> void:
	print("  -- the skitter reads before it lunges --")
	var r := _mk("skitter", 10.0, 20.0)
	var kid := {"x": 15.0, "y": r.y, "grounded": true}
	check("it starts patrolling, not hunting", r.state == "patrol")
	check("…and a patrolling one is scenery you step over",
		not r.hits(15.0, r.y, 0.3, 1.5), "state=%s" % r.state)

	var saw_notice := false
	var saw_wind := false
	var elapsed := 0.0
	var touched_before_lunge := false
	for i in 600:
		r.step(DT, kid)
		if r.state == "notice":
			saw_notice = true
		if r.state == "wind":
			saw_wind = true
		if r.state == "lunge":
			break
		# nothing may touch the kid during the whole wind-up
		if r.hits(15.0, r.y, 0.3, 1.5):
			touched_before_lunge = true
		elapsed += DT
	check("it notices first", saw_notice)
	check("…then visibly winds up", saw_wind)
	check("it reached the lunge at all", r.state == "lunge", "state=%s" % r.state)
	check("nothing could touch the kid during the wind-up", not touched_before_lunge)
	# DESIGN §4.1 — the number, not a vibe
	check("the telegraph is at least 1.0s (DESIGN §4.1)", elapsed >= 1.0,
		"%.3fs" % elapsed)
	check("…which is notice + wind", absf(elapsed - (Robot.SKITTER_NOTICE + Robot.SKITTER_WIND)) < 0.05,
		"%.3fs vs %.3fs" % [elapsed, Robot.SKITTER_NOTICE + Robot.SKITTER_WIND])
	check("and only the lunge hurts", r.hits(r.x, r.y, 0.3, 1.5), "state=%s" % r.state)


func _check_hopper() -> void:
	print("  -- the hopper is a metronome --")
	var r := _mk("hopper", 10.0, 12.0)
	var kid := {"x": 30.0, "y": 4.0, "grounded": true}   # far away: it must not care
	var lo := INF
	var hi := -INF
	var start_x := r.x
	for i in int(Robot.HOP_CYCLE / DT) + 4:
		r.step(DT, kid)
		lo = minf(lo, r.y)
		hi = maxf(hi, r.y)
	check("it leaves the ground", hi - lo > 0.5, "rose %.2f" % (hi - lo))
	check("…by about HOP_RISE", absf((hi - lo) - Robot.HOP_RISE) < 0.15,
		"rose %.2f vs %.2f" % [hi - lo, Robot.HOP_RISE])
	check("it never chases — it holds its ground", absf(r.x - start_x) < 0.01,
		"moved %.3f" % absf(r.x - start_x))


func _check_roller() -> void:
	print("  -- the roller trundles its span --")
	var r := _mk("roller", 10.0, 14.0)
	var kid := {"x": 30.0, "y": 4.0, "grounded": true}
	var lo := INF
	var hi := -INF
	for i in 900:
		r.step(DT, kid)
		lo = minf(lo, r.x)
		hi = maxf(hi, r.x)
	check("it stays inside its span", lo >= 9.99 and hi <= 15.01,
		"%.2f..%.2f" % [lo, hi])
	check("…and it really does patrol the width of it", hi - lo > 3.0,
		"covered %.2f" % (hi - lo))


## The provocation test: safe to walk past, wakes when you LAND near it.
func _check_bucket() -> void:
	print("  -- the bucket sleeps until you land --")
	var r := _mk("bucket", 10.0, 14.0)
	check("it starts asleep", r.state == "sleep")

	# walk past, never leaving the ground: it must not wake
	var walking := {"x": 12.0, "y": r.y, "grounded": true}
	for i in 240:
		r.step(DT, walking)
	check("walking past does not wake it", r.state == "sleep", "state=%s" % r.state)
	check("…and a sleeping one cannot hurt you", not r.hits(12.0, r.y, 0.3, 1.5))

	# now LAND beside it — one airborne frame then grounded is the edge
	r.step(DT, {"x": 12.0, "y": r.y, "grounded": false})
	r.step(DT, {"x": 12.0, "y": r.y, "grounded": true})
	check("landing beside it wakes it", r.state == "wake", "state=%s" % r.state)
	var wake_x := r.x
	for i in int(Robot.BKT_WAKE / DT) - 2:
		r.step(DT, {"x": 12.0, "y": r.y, "grounded": true})
	check("it holds still while telegraphing", absf(r.x - wake_x) < 0.01,
		"moved %.3f" % absf(r.x - wake_x))


func _check_stomp() -> void:
	print("  -- the stomp --")
	var r := _mk("skitter", 10.0, 12.0)
	# coming down on it from above
	var stomped := r.stomped_by(r.x, r.y + r.h * 0.6, 0.3, -6.0)
	check("landing on one from above kills it", stomped)
	check("…and it is dead afterwards", r.dead)

	var rising := _mk("skitter", 10.0, 12.0)
	check("rising into one does NOT stomp it",
		not rising.stomped_by(rising.x, rising.y + rising.h * 0.6, 0.3, 6.0))

	var roll := _mk("roller", 10.0, 12.0)
	check("a roller cannot be stomped",
		not roll.stomped_by(roll.x, roll.y + roll.h * 0.6, 0.3, -6.0))
	check("…it shrugs you off instead, and cannot hit you while it does",
		_shrugged_is_harmless())


## DESIGN §3: hazards are "environmental, always telegraphed before they are
## lethal", and §4.1 puts a number on it — telegraph >= 1.0s.
func _check_vent() -> void:
	print("  -- the steam vent telegraphs --")
	var l := LevelData.load_slug("eeri-1-1")
	if l == null: return
	var v := SteamVent.new(l, 60.0, 0.0)
	check("it stands on the ground", v.y > 0.0, "y=%.2f" % v.y)
	check("it starts in its warning half, not blowing",
		v.warning() and not v.blowing())

	var lit := 0.0
	var t := 0.0
	var touched_while_warning := false
	for i in 600:
		v.step(DT)
		t += DT
		if v.blowing():
			break
		if v.warning():
			lit = t
		if v.hits(v.x, v.y, 0.3, 1.5):
			touched_while_warning = true
	check("nothing can touch you while it is only warning", not touched_while_warning)
	check("the tell lasts at least 1.0s (DESIGN §4.1)", lit >= 1.0, "%.2fs" % lit)
	check("…and then it really does blow", v.blowing())
	check("a blowing vent reaches the kid standing on it",
		v.hits(v.x, v.y, 0.3, 1.5))
	# and it must STOP: a hazard that is permanently on is a wall
	for i in 600:
		v.step(DT)
		if not v.blowing():
			break
	check("…and it stops again — a permanent hazard is a wall", not v.blowing())


func _shrugged_is_harmless() -> bool:
	var roll := _mk("roller", 10.0, 12.0)
	roll.shrug()
	return not roll.hits(roll.x, roll.y, 0.3, 1.5)


func _finish() -> void:
	var ran := _pass + _fail
	if ran != EXPECTED:
		_fail += 1
		# Fires BOTH ways on purpose: too few usually means a depended script
		# failed to compile and a whole block silently did not run; too many
		# means checks were added and this number was not, which makes the
		# guard itself stale and worthless.
		print("  FAIL - %d checks ran, expected %d — update EXPECTED, or find the block that did not run" % [ran, EXPECTED])
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
