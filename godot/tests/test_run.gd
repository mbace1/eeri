extends Node
## What turns a room into a LEVEL: bolts, golden bolts, the checkpoint, and a
## flag that builds itself and is activated by being run past.
##
## Run: godot --headless --path godot res://tests/test_run.tscn
const EXPECTED := 18
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0; bail.one_shot = true
	bail.timeout.connect(func(): print("RUN FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — bolts, checkpoint, flag ──")
	var lvl := LevelData.load_slug("eeri-1-1")
	check("the level loads", lvl != null)
	if lvl == null: _finish(); return

	# DESIGN §4.2 fixes these counts exactly
	var r := LevelRun.new(lvl)
	check("a hundred bolts is the completion figure", r.bolts_total == 100,
		"%d" % r.bolts_total)
	check("three golden bolts, hidden", r.golden_total == 3, "%d" % r.golden_total)
	check("nothing is collected before you move", r.bolts_got == 0 and r.golden_got == 0)

	# --- collecting -------------------------------------------------------
	print("  -- collecting --")
	var p := r.cell_to_xy(lvl.bolts[0])
	r.step(p.x, p.y - 0.75)
	check("walking onto a bolt collects it", r.bolts_got == 1, "%d" % r.bolts_got)
	check("…and it reports the event once", r.just_bolt)
	r.step(p.x, p.y - 0.75)
	check("…and standing there does not collect it twice", r.bolts_got == 1)
	check("…nor keeps firing the event", not r.just_bolt)

	var g := r.cell_to_xy(lvl.golden[0])
	r.step(g.x, g.y - 0.75)
	check("a golden bolt is its own tier", r.golden_got == 1 and r.just_golden)

	# --- the checkpoint ---------------------------------------------------
	print("  -- the checkpoint --")
	var c := LevelRun.new(lvl)
	var cx := float(lvl.checkpoint.get("x", 0))
	c.step(cx - 5.0, 4.0)
	check("it starts unlit", not c.checkpoint_lit)
	c.step(cx + 1.0, 4.0)
	check("running past lights it", c.checkpoint_lit and c.just_checkpoint)
	# DESIGN §4: dying costs the middle of the level, never all of it
	var back := c.respawn_for(cx + 20.0)
	check("…and a fall now returns him to it, not to the start",
		back.x >= cx - 0.5, "x=%.1f vs checkpoint %.1f" % [back.x, cx])

	# --- the flag ---------------------------------------------------------
	print("  -- the flag --")
	var f := LevelRun.new(lvl)
	var fx := float(lvl.flag.get("x", 0))
	f.step(fx - 40.0, 4.0)
	check("from far off it has not begun", f.flag_phase < 0, "phase=%d" % f.flag_phase)
	f.step(fx - 12.0, 4.0)
	check("coming up on it, it starts building", f.flag_phase >= 0,
		"phase=%d" % f.flag_phase)
	f.step(fx - 4.0, 4.0)
	check("…and it is fully built before you reach it", f.flag_phase >= 2,
		"phase=%d" % f.flag_phase)
	check("…but not raised yet — it takes running PAST", not f.flag_raised)
	f.step(fx + 1.0, 4.0)
	check("running past raises it, with no button", f.flag_raised and f.just_raised)
	check("…and that is the level finished", f.finished)
	_finish()

func _finish() -> void:
	var ran := _pass + _fail
	if ran != EXPECTED:
		_fail += 1
		print("  FAIL - %d checks ran, expected %d" % [ran, EXPECTED])
	print("")
	print("%d passed, %d failed" % [_pass, _fail])
	if _fail > 0: get_tree().quit(1)
	else: print("ALL GREEN"); get_tree().quit(0)

func check(label: String, condition: bool, detail: String = "") -> void:
	if condition: _pass += 1; print("  ok  - %s" % label)
	else: _fail += 1; print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
