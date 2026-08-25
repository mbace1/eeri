extends Node
## The dig — the verb that makes the ride a verb rather than transport.
##
## Run: godot --headless --path godot res://tests/test_dig.tscn
const DT := 1.0 / 60.0
const EXPECTED := 12
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("DIG FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — the dig ──")
	var lvl := LevelData.load_slug("eeri-1-1")
	check("level 1-1 declares a bank", lvl != null and lvl.bank != null)
	if lvl == null or lvl.bank == null:
		_finish(); return
	var b := Bank.new(lvl, lvl.bank)
	check("it has rows to take down", b.rows > 0, "rows=%d" % b.rows)

	# --- reach is about the MACHINE, not the arm -------------------------
	print("  -- reach --")
	check("parked beside it, it is in reach", b.in_reach(b.centre()))
	check("…and across the room it is not", not b.in_reach(b.centre() + 40.0))

	# --- it says it is diggable BEFORE you press anything -----------------
	b.step(DT, b.centre(), false)
	check("in reach it ARMS itself, unpressed", b.armed)
	check("…and holding the verb out of reach does nothing",
		not _dug(lvl, b.centre() + 40.0))

	# --- the stroke ------------------------------------------------------
	print("  -- the stroke --")
	var s := Bank.new(lvl, lvl.bank)
	var bites := 0
	var moved := false
	var rest_boom := s.boom
	for i in int(Bank.STROKE / DT) + 2:
		s.step(DT, s.centre(), true)
		if s.bit: bites += 1
		if absf(s.boom - rest_boom) > 0.05: moved = true
	check("one stroke takes exactly one bite", bites == 1, "bites=%d" % bites)
	check("…and the arm really moves through it", moved)
	check("…so a row is gone", s.remaining == s.rows - 1,
		"%d of %d" % [s.remaining, s.rows])

	# --- clearing it -----------------------------------------------------
	var c := Bank.new(lvl, lvl.bank)
	for i in int(Bank.STROKE / DT) * (c.rows + 2):
		c.step(DT, c.centre(), true)
	check("holding the verb clears the whole bank", c.cleared)
	check("…and it never digs below empty", c.remaining == 0, "remaining=%d" % c.remaining)
	# a cleared bank must stop advertising itself
	c.step(DT, c.centre(), false)
	check("…and a cleared bank stops arming", not c.armed)
	_finish()

func _dug(lvl: LevelData, at: float) -> bool:
	var b := Bank.new(lvl, lvl.bank)
	for i in int(Bank.STROKE / DT) * 3:
		b.step(DT, at, true)
	return b.remaining < b.rows

func _finish() -> void:
	var ran := _pass + _fail
	if ran != EXPECTED:
		_fail += 1
		print("  FAIL - %d checks ran, expected %d" % [ran, EXPECTED])
	print("")
	print("%d passed, %d failed" % [_pass, _fail])
	if _fail > 0: get_tree().quit(1)
	else:
		print("ALL GREEN"); get_tree().quit(0)

func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1; print("  ok  - %s" % label)
	else:
		_fail += 1; print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
