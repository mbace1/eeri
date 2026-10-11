extends Node
## The ladder hint promises "▲ ▼ CLIMB  Ⓐ JUMP OFF" (js/lang.js hLadder), and
## js/kid.js keeps it: a jump on the rungs lets go with JUMP_V * 0.85, because
## "a ladder is never a trap". This proves the port keeps the same promise.
##
## Run: godot --headless --path godot res://tests/test_ladder.tscn

const DT := 1.0 / 60.0
const EXPECTED := 4

var _pass := 0
var _fail := 0


func _ready() -> void:
	print("── Eeri — jumping off a ladder ──")
	var lvl := LevelData.load_slug("eeri-1-2")
	check("level 1-2 loads", lvl != null)
	if lvl == null:
		_finish()
		return
	# the tallest ladder in the room, so there is a mid-shaft to stand in
	var best_c := -1
	var best_r := -1
	var best_n := 0
	for c in lvl.w:
		var n := 0
		for r in lvl.h:
			if lvl.cell(c, r) == lvl.climb_char:
				n += 1
				if n > best_n:
					best_n = n
					best_c = c
					best_r = r - n + 1
			else:
				n = 0
	check("the room has a ladder at least three rungs tall", best_n >= 3, "%d" % best_n)
	if best_n < 3:
		_finish()
		return

	var kid := Kid.new(lvl, best_c + 0.5, best_r + 1.2)
	kid.step(DT, {"up_held": true})
	check("holding up on the rungs climbs", kid.climbing)
	kid.step(DT, {"jump_pressed": true, "jump_held": true})
	check("a jump lets go of the ladder with a real jump",
		not kid.climbing and kid.vy > 0.0,
		"climbing=%s vy=%.2f" % [kid.climbing, kid.vy])
	_finish()


func check(label: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
		print("  ok  - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label, ("  (" + detail + ")") if detail != "" else "")


func _finish() -> void:
	if _pass + _fail != EXPECTED:
		_fail += 1
		print("  FAIL - ran %d of %d checks" % [_pass + _fail - 1, EXPECTED])
	print("%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
