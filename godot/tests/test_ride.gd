extends Node
## The ride, and the rules that keep it a REWARD rather than a puzzle.
##
## DESIGN.md §1: "board at a marked point, ride a short authored stretch that
## no amount of jumping could cross, step off at the far end... The ride is a
## reward and a change of gear, not a puzzle."
##
## Run: godot --headless --path godot res://tests/test_ride.tscn

const DT := 1.0 / 60.0
const EXPECTED := 23

var _pass := 0
var _fail := 0
var _lvl: LevelData


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("RIDE FAIL: timed out")
		get_tree().quit(1))
	add_child(bail)
	bail.start()

	print("── Eeri — the ride ──")
	_lvl = LevelData.load_slug("eeri-1-1")
	check("a level with a machine in it", _lvl != null)
	if _lvl == null:
		_finish()
		return
	check("level 1-1 parks an excavator", _lvl.spawn.has("excavator"),
		str(_lvl.spawn.keys()))

	_check_untamed()
	_check_wary()
	_check_drive()
	_check_cliff()
	_check_mount_window()
	_finish()


## ART_BRIEF §1.2 — a machine is dangerous until it is yours, and the empty
## seat is how a player tells an unmanned machine from a tamed one.
func _check_untamed() -> void:
	print("  -- it is not yours yet --")
	var m := _mk()
	check("it starts untamed", not m.tamed)
	m.tame()
	check("mounting tames it", m.tamed)


## js/excavator.js work(): "the unmanned work cycle -- a slow dig it repeats
## forever. The bucket sweeping low IS the danger, and the lift is the
## window you mount in." Ported to Machine.work()/swinging()/
## unmanned_danger() -- this is what makes the "wary" hint (hWary: "wait for
## the bucket to lift") an actual threat rather than a sentence with nothing
## behind it.
func _check_wary() -> void:
	print("  -- nobody is driving it --")
	var m := _mk()
	check("starts safe: the bucket is not down yet", not m.swinging())
	check("and so is not a danger yet",
		not m.unmanned_danger(m.x, m.y + 1.0))
	var saw_danger := false
	var saw_safe_again := false
	for i in 900:                        # 15s -- long enough for a full cycle
		m.work(DT)
		if m.swinging():
			saw_danger = true
		elif saw_danger:
			saw_safe_again = true
	check("the cycle actually swings the bucket down", saw_danger)
	check("…and lifts it again -- the window js's hint promises", saw_safe_again)

	var m2 := _mk()
	# force the danger phase directly rather than waiting on the sine, so
	# this assertion does not depend on the exact period
	m2.boom = 0.1
	check("standing under it while it is down is struck",
		m2.unmanned_danger(m2.x, m2.y + 1.0))
	check("standing well clear of it is not",
		not m2.unmanned_danger(m2.x + 6.0, m2.y + 1.0))
	m2.tame()
	check("TAMED, the same position is never a danger — it is yours now",
		not m2.unmanned_danger(m2.x, m2.y + 1.0))

	var crane := Machine.new(_lvl, 20.0, 4.0, "crane")
	for i in 120:
		crane.work(DT)
	check("a crane only sways — it never carries the excavator's danger",
		not crane.swinging() and not crane.unmanned_danger(crane.x, crane.y + 1.0))


func _check_drive() -> void:
	print("  -- weight --")
	var m := _mk()
	for i in 240:
		m.step(DT, 1.0)
	check("it reaches its top speed", absf(m.vx - Machine.TOP) < 0.05,
		"vx=%.3f" % m.vx)
	# DESIGN §1's scale rule has a consequence worth asserting: the machine is
	# SLOWER than the kid. A ride that outran running would make the on-foot
	# 80% feel like the slow part of its own game.
	check("…and it is slower than the kid on foot", Machine.TOP < Kid.RUN,
		"machine %.1f vs kid %.1f" % [Machine.TOP, Kid.RUN])

	# a slung load halves the pace: carrying is a commitment, not a stroll
	var c := _mk()
	c.carrying = true
	for i in 240:
		c.step(DT, 1.0)
	check("carrying a load slows it", c.vx < m.vx - 0.5,
		"carrying %.2f vs free %.2f" % [c.vx, m.vx])

	# heavy EASE, not a switch — one frame must not reach top speed
	var e := _mk()
	e.step(DT, 1.0)
	check("it eases in rather than snapping to speed", e.vx < Machine.TOP * 0.25,
		"after one frame vx=%.3f" % e.vx)


## A machine refuses a cliff. This is what keeps a ride something you cannot
## simply lose by holding a direction.
func _check_cliff() -> void:
	print("  -- it refuses a cliff --")
	var m := _mk()
	var start_x := m.x
	for i in 2400:
		m.step(DT, 1.0)
	check("driving into the level never drops it off the world", m.y > 0.0,
		"y=%.2f" % m.y)
	check("…and it actually travelled", m.x > start_x + 1.0,
		"moved %.2f" % (m.x - start_x))


## Boarding is at a marked point, not merely "near a machine".
func _check_mount_window() -> void:
	print("  -- boarding --")
	var m := _mk()
	check("you can board standing beside it",
		m.can_mount(m.x + 1.5, m.y, true))
	check("…but not from across the room",
		not m.can_mount(m.x + 9.0, m.y, true))
	check("…and not in mid-air", not m.can_mount(m.x + 1.5, m.y, false))
	# the seat has to be somewhere real, or the rider is drawn inside the body
	var seat := m.seat_pos()
	check("the seat sits above the machine's feet", seat.y > m.y,
		"seat y=%.2f machine y=%.2f" % [seat.y, m.y])
	check("the step is on the machine's facing side",
		signf(m.step_pos().x - m.x) == signf(float(m.face)))


func _mk() -> Machine:
	var e = _lvl.spawn.get("excavator", {"x": 63, "y": 4})
	return Machine.new(_lvl, float(e.get("x", 63)), float(e.get("y", 4)))


func _finish() -> void:
	var ran := _pass + _fail
	if ran != EXPECTED:
		_fail += 1
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
