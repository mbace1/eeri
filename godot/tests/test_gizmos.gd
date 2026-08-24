extends Node
## The gizmos — "the third source of variety, and they cost the least"
## (DESIGN §2). Belt, tarp, water and the hoist.
##
## Run: godot --headless --path godot res://tests/test_gizmos.tscn
const DT := 1.0 / 60.0
const EXPECTED := 19
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0; bail.one_shot = true
	bail.timeout.connect(func(): print("GIZMO FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — the gizmos ──")
	_legend()
	_hoist()
	_wade()
	_pipes()
	_finish()

## Every gizmo except the hoist and pipe is "what is under your boot", so the
## legend IS the mechanic. A wrong character silently removes one from a level.
func _legend() -> void:
	print("  -- the tile legend --")
	var l := LevelData.load_slug("eeri-4-1")     # the belt level
	check("a belt level loads", l != null)
	if l == null: return
	check("climb is H, not the solid '='", l.climb_char == "H", l.climb_char)
	check("belts are Cc", l.belt_chars == "Cc", l.belt_chars)
	check("tarp is T and water is ~",
		l.tarp_char == "T" and l.water_char == "~")
	# 'C' carries right and 'c' left — a belt that ran the wrong way would
	# still "work" and quietly reverse a level's route
	var found_c := false
	for r in l.h:
		for c in l.w:
			if l.cell(c, r) == "C":
				found_c = true
				check("a 'C' belt carries RIGHT", l.belt_at(c + 0.5, r + 1.0) == 1,
					"got %d" % l.belt_at(c + 0.5, r + 1.0))
				break
		if found_c: break
	check("the belt level really contains belts", found_c)

func _hoist() -> void:
	print("  -- the hoist --")
	var l := LevelData.load_slug("eeri-2-3")
	check("a hoist level loads", l != null and l.hoists.size() > 0,
		"%d hoists" % (l.hoists.size() if l else -1))
	if l == null or l.hoists.is_empty(): return
	var h := Hoist.new(l.hoists[0])
	var lo := INF
	var hi := -INF
	var speeds: Array[float] = []
	for i in int(h.period / DT) + 4:
		h.step(DT)
		lo = minf(lo, h.top()); hi = maxf(hi, h.top())
		if absf(h.vy) > 0.01: speeds.append(absf(h.vy))
	check("it travels its shaft", hi - lo > 0.5, "%.2f..%.2f" % [lo, hi])
	check("…between the authored ends", absf(lo - h.cy0) < 0.2 and absf(hi - h.cy1) < 0.2,
		"%.2f..%.2f vs %.0f..%.0f" % [lo, hi, h.cy0, h.cy1])
	# A TRIANGLE, NOT A SINE: constant speed, so the arrival is predictable
	# and waiting for it is fair.
	var slowest := INF
	var fastest := -INF
	for v in speeds:
		slowest = minf(slowest, v); fastest = maxf(fastest, v)
	check("it moves at a CONSTANT speed (a triangle, not a sine)",
		fastest - slowest < fastest * 0.15,
		"%.2f..%.2f u/s" % [slowest, fastest])
	# reduced motion must PARK it, never freeze it mid-shaft
	var r := Hoist.new(l.hoists[0])
	r.reduced_motion = true
	for i in 200: r.step(DT)
	check("reduced motion parks it at the bottom, not mid-shaft",
		absf(r.top() - r.cy0) < 0.01, "y=%.2f" % r.top())

	# the platform pass: a rising hoist must not be sunk through
	var k := Kid.new(l, h.x, h.cy0)
	k.platforms = [h]
	var carried := false
	for i in 400:
		h.step(DT)
		k.step(DT, {})
		if k.carrier == h and h.vy > 0.1:
			carried = true
			break
	check("a RISING hoist carries him rather than passing through", carried)

func _wade() -> void:
	print("  -- wading --")
	var l := LevelData.load_slug("eeri-2-1")
	check("a water level loads", l != null and l.water.size() > 0,
		"%d" % (l.water.size() if l else -1))
	if l == null: return
	# DESIGN: wading caps the RUN and must NEVER touch the jump, or every room
	# the prover already passed silently breaks.
	check("wading caps the run below the dry run", Kid.RUN * Kid.WADE < Kid.RUN)
	check("…but the jump is untouched", Kid.JUMP_V == 12.6, "%.2f" % Kid.JUMP_V)

## A pair of places plus the trip between them. The rules that matter are
## that you must be STANDING at a mouth (a pipe you fall into by accident
## takes the level away from you) and that the far mouth must not read as a
## fresh entrance the instant you arrive.
func _pipes() -> void:
	print("  -- the pipes --")
	var l := LevelData.load_slug("eeri-2-2")
	check("a pipe level loads", l != null and l.pipes.size() > 0,
		"%d" % (l.pipes.size() if l else -1))
	if l == null or l.pipes.is_empty(): return
	var q = l.pipes[0]
	var a = q.get("a")
	var b = q.get("b")
	check("a pipe is a PAIR of places", a != null and b != null)
	check("…and they are somewhere else from each other",
		absf(float(a.get("c", 0)) - float(b.get("c", 0))) > 1.0,
		"%s -> %s" % [a.get("c"), b.get("c")])
	# both mouths must stand on real ground, or one end is unreachable
	var a_ok: bool = l.solid_cell(int(a.get("c", 0)), int(a.get("cy", 0)) - 1)
	var b_ok: bool = l.solid_cell(int(b.get("c", 0)), int(b.get("cy", 0)) - 1)
	check("both mouths sit on solid ground", a_ok and b_ok,
		"a=%s b=%s" % [a_ok, b_ok])


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
