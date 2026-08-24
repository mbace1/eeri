extends Node
## Every level loads, and finishing one leads to the next.
##
## This is the eeri lesson applied to the port: test/rooms.mjs proves a room's
## GEOMETRY, test/playthrough.cjs proves it is PLAYABLE, and the prover passed
## a level nobody could finish. This is the loading half — the Godot
## playthrough belongs with the gizmos it does not have yet.
##
## Run: godot --headless --path godot res://tests/test_progress.tscn
const EXPECTED := 15
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 90.0; bail.one_shot = true
	bail.timeout.connect(func(): print("PROGRESS FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — all twelve rooms ──")
	var idx := LevelData.load_index()
	var levels: Array = idx.get("levels", [])
	check("the roster is the whole game", levels.size() == 12, "%d" % levels.size())

	var slugs := {}
	for e in levels:
		var slug := String(e.get("slug", ""))
		var l := LevelData.load_slug(slug)
		if l == null:
			check("%s loads" % slug, false)
			continue
		# every room must be finishable in principle: a spawn, a way out, and
		# ground under the kid at the start
		var k = l.spawn.get("kid", {})
		var ok_spawn: bool = l.solid_cell(int(floor(float(k.get("x", 0)))), int(float(k.get("y", 0))) - 1)
		var ok_flag: bool = l.flag != null
		var ok_grid: bool = l.grid.size() == l.h
		check("%s loads, spawns on ground, and has a flag" % slug,
			ok_spawn and ok_flag and ok_grid,
			"spawn=%s flag=%s grid=%s" % [ok_spawn, ok_flag, ok_grid])
		slugs[slug] = true

	check("every slug is distinct", slugs.size() == levels.size(),
		"%d unique of %d" % [slugs.size(), levels.size()])

	# the addressing scheme itself (DESIGN §4): world-major, 1-based, 3 per world
	var want := []
	for w in range(1, 5):
		for n in range(1, 4):
			want.append("eeri-%d-%d" % [w, n])
	var got := []
	for e in levels:
		got.append(String(e.get("slug", "")))
	check("the addresses are EERI W-L, four worlds of three", got == want,
		"first mismatch near %s" % (got[0] if got.size() > 0 else "?"))
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
