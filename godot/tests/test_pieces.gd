extends Node
## The locks a ride machine exists to open: the brick wall and the girder.
##
## ART_BRIEF's rule, which these obey: DRAW THE CHANGE. A cracked wall keeps
## its full height and gains a crack; it does not become a shorter wall.
##
## Run: godot --headless --path godot res://tests/test_pieces.tscn
const DT := 1.0 / 60.0
const EXPECTED := 23
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0; bail.one_shot = true
	bail.timeout.connect(func(): print("PIECES FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()
	print("── Eeri — the locks ──")
	_wall()
	_girder()
	_swing()
	_finish()

func _wall() -> void:
	print("  -- the brick wall --")
	var l := LevelData.load_slug("eeri-1-3")
	check("the wall level loads", l != null and l.wall != null)
	if l == null or l.wall == null: return
	var w := Pieces.Wall.new(l.wall)
	check("it starts intact", w.state() == 0 and not w.cleared)
	check("…and it blocks the way", w.blocks())
	# the wall is solid in the GRID before anything hits it
	check("the grid really has bricks there",
		l.solid_cell(int(w.c0), int(w.cy0)), "cell=%s" % l.cell(int(w.c0), int(w.cy0)))

	w.strike()
	check("one swing cracks it", w.state() == 1, "state=%d" % w.state())
	# THE POINT: a cracked wall is still a wall
	check("…and a cracked wall is STILL a wall", w.blocks() and not w.cleared)
	w.strike()
	check("the second brings it down", w.cleared and w.state() == 2)
	check("…and it stops blocking", not w.blocks())
	check("striking rubble does nothing", not w.strike())

	# clearing edits the map, so collision cannot disagree with the picture
	for r in w.rows:
		l.clear_row(int(w.c0), int(w.c1), int(w.cy0) + r)
	check("clearing the wall really opens the grid",
		not l.solid_cell(int(w.c0), int(w.cy0)), "cell=%s" % l.cell(int(w.c0), int(w.cy0)))

func _girder() -> void:
	print("  -- the girder --")
	var l := LevelData.load_slug("eeri-1-2")
	check("the girder level loads", l != null and l.girder != null)
	if l == null or l.girder == null: return
	var g := Pieces.Girder.new(l.girder)
	check("it starts stacked", g.state() == 0)
	check("you cannot seat what you are not carrying", not g.seat(g.seat_x0 + 0.1))
	check("…and cannot sling it from across the room", not g.sling(g.stack_x + 30.0))
	check("parked at the stack, the bucket takes it", g.sling(g.stack_x))
	check("…and it is slung", g.state() == 1)
	check("it cannot be seated from the wrong place",
		not g.can_seat(g.seat_x0 - 8.0))
	check("…but can be from the authored seat window",
		g.can_seat((g.seat_x0 + g.seat_x1) * 0.5))
	check("lowering it in seats the span",
		g.seat((g.seat_x0 + g.seat_x1) * 0.5) and g.state() == 2)

	# the span is walked on: it has to become real floor
	var gap_open_before := not l.solid_cell(int(g.gap_c0), int(g.gap_cy))
	l.fill_row(int(g.gap_c0), int(g.gap_c1), int(g.gap_cy))
	check("the seated span becomes real floor",
		gap_open_before and l.solid_cell(int(g.gap_c0), int(g.gap_cy)))

func _swing() -> void:
	print("  -- the wrecking ball telegraphs --")
	var l := LevelData.load_slug("eeri-1-3")
	if l == null: return
	var m := Machine.new(l, 60.0, 4.0, "crane")
	check("the crane is slower than the excavator",
		Machine.SPEC["crane"]["top"] < Machine.SPEC["excavator"]["top"])
	check("it rests, not swinging", m.swing == "rest" and not m.striking())
	m.heave()
	var danger_at := -1.0
	var t := 0.0
	for i in 400:
		m.step_swing(DT)
		t += DT
		if m.striking():
			danger_at = t
			break
	check("the ball only becomes dangerous after a real wind-up",
		danger_at > 0.8, "%.2fs" % danger_at)

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
