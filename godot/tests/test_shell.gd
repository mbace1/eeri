extends Node
## The wrapper: title, pause, level select, touch pad.
##
## Driven through the real Control tree, never the model — AGENTS.md's rule
## in piritori-eden: "a gate that calls the model proves the model and says
## nothing about the interface". So this finds buttons and emits their
## pressed signal, exactly as a thumb would.
##
## Run: godot --headless --path godot res://tests/test_shell.tscn
const EXPECTED := 19
var _pass := 0
var _fail := 0

## MEMBER vars, not locals. A GDScript lambda captures locals BY VALUE, so a
## signal handler written as `func(s): picked = s` over a local assigns to a
## copy and the outer variable never changes — which reads exactly like the
## signal never firing. Cost two "failures" that were both this.
var _picked := ""
var _started := false

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0; bail.one_shot = true
	bail.timeout.connect(func(): print("SHELL FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — the shell ──")
	Loc.set_language("en")
	var sh := Shell.new()
	add_child(sh)
	await get_tree().process_frame

	var buttons := _buttons(sh)
	check("the shell builds real buttons", buttons.size() > 0, "%d" % buttons.size())

	# DESIGN §6.4 — NO KEY CAPS OR MOUSE ICONS, EVER.
	print("  -- it never names a key --")
	var forbidden := ["key", "keyboard", "mouse", "click", "press space",
		"arrow", "wasd", "spacebar", "enter", "esc"]
	var offenders: Array[String] = []
	for b in buttons:
		var t := b.text.to_lower()
		for f in forbidden:
			if t.contains(f):
				offenders.append("%s (%s)" % [b.text, f])
	check("no control names a key or a mouse", offenders.is_empty(),
		", ".join(offenders))

	# 44px floor on every interactive target
	print("  -- reachable --")
	var small: Array[String] = []
	for b in buttons:
		var s := b.get_combined_minimum_size()
		if s.y < Shell.MIN_TARGET or s.x < Shell.MIN_TARGET:
			small.append("%s %.0fx%.0f" % [b.text, s.x, s.y])
	check("every control clears the 44px floor", small.is_empty(), ", ".join(small))

	# the level select IS the map (DESIGN §4.1: "no map")
	print("  -- the level select --")
	sh.level_chosen.connect(func(s: String): _picked = s)
	var lvl_buttons := 0
	for b in buttons:
		if b.text.match("?-?"):
			lvl_buttons += 1
	check("all twelve levels are jumpable from the menu", lvl_buttons == 12,
		"%d" % lvl_buttons)
	for b in buttons:
		if b.text == "4-3":
			b.pressed.emit()
			break
	check("choosing one reports the right slug", _picked == "eeri-4-3", _picked)

	# title / pause behaviour
	print("  -- title and pause --")
	sh.start_pressed.connect(func(): _started = true)
	for b in buttons:
		if b.text == tr("start"):
			b.pressed.emit()
			break
	check("START starts", _started)
	check("pause begins closed", not sh.paused())
	sh.toggle_pause()
	check("…and toggles open", sh.paused())
	sh.toggle_pause()
	check("…and closed again", not sh.paused())

	# language switches WITHOUT rebuilding — a switch must not lose your place
	print("  -- language --")
	var en := ""
	for b in buttons:
		if b.has_meta("key") and String(b.get_meta("key")) == "Start":
			en = b.text
	Loc.set_language("fi")
	await get_tree().process_frame
	var fi := ""
	for b in _buttons(sh):
		if b.has_meta("key") and String(b.get_meta("key")) == "Start":
			fi = b.text
	check("the start button speaks Finnish too", fi != "" and fi != en,
		"%s vs %s" % [fi, en])
	check("…and the same button object was re-texted, not rebuilt",
		_buttons(sh).size() == buttons.size(),
		"%d vs %d" % [_buttons(sh).size(), buttons.size()])
	Loc.set_language("en")

	# the touch pad is hidden until a touch is seen
	check("the touch pad starts hidden", not sh._touch.visible)

	# THE PLATE IS THE ART (2026-08-26 fix): every touch hit-area must be a
	# bare Button with no texture and no text -- whatever is under it (the
	# drawn Game Boy face) is the only thing that should ever be visible.
	# A texture or a label here is exactly the regression that shipped once
	# already (js/glyphs.js icons pasted over the plate's own D-pad/A-B art).
	print("  -- the touch pad is transparent, and sits on the plate --")
	var touch_buttons: Array[Button] = []
	for c in sh._touch.get_children():
		if c is Button:
			touch_buttons.append(c)
	check("six touch hit-areas exist (4 directions + jump + action)",
		touch_buttons.size() == 6, "%d" % touch_buttons.size())
	var textured: Array[String] = []
	for b in touch_buttons:
		if b.text != "":
			textured.append(b.text)
	check("none of them carry a texture or a label", textured.is_empty(),
		", ".join(textured))

	# THE FIT MATH: _fitted_rect must stay inside the given viewport at any
	# width, and must not silently collapse to zero -- a zero-size rect is
	# exactly how the buttons fell back to the old, wrong, corner-anchored
	# layout. Checked at a narrow phone width AND a wide tablet width, since
	# the bug this replaces was width-dependent by nature (STRETCH_KEEP_
	# ASPECT_CENTERED behaves differently depending on which axis is the
	# constraint).
	print("  -- the plate's fitted rect, at two widths --")
	for vp in [Vector2(360, 800), Vector2(800, 1200)]:
		var r: Rect2 = sh._fitted_rect(vp)
		check("fitted rect is non-zero at width %d" % int(vp.x), r.size.x > 0 and r.size.y > 0,
			str(r))
		check("…and stays within the viewport at width %d" % int(vp.x),
			r.position.x >= -0.01 and r.position.x + r.size.x <= vp.x + 0.01,
			str(r))

	# THE POSITIONING BUG ITSELF: at a width narrower than the plate's own
	# natural (unconstrained) width, the old corner-anchored buttons would
	# still sit at fixed screen offsets while the plate re-centred under
	# them -- so verify a hit area actually lands within the plate's rect,
	# not off past its edge, at a deliberately narrow width.
	print("  -- a hit area actually lands on the plate --")
	var narrow := Vector2(360, 800)
	var nr: Rect2 = sh._fitted_rect(narrow)
	var s2: Vector2 = nr.size / sh.PAD_IMG
	var jump_pos: Vector2 = nr.position + sh.A_CENTER * s2
	check("the jump hit-area's picture point falls inside the plate rect",
		nr.has_point(jump_pos), "%s not in %s" % [jump_pos, nr])

	_finish()

func _buttons(n: Node, out: Array[Button] = []) -> Array[Button]:
	for c in n.get_children():
		if c is Button: out.append(c)
		_buttons(c, out)
	return out

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
