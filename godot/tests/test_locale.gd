extends Node
## fi / en / ja (DESIGN §4.4), and the silence that makes it dangerous.
##
## Run: godot --headless --path godot res://tests/test_locale.tscn
const EXPECTED := 10
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0; bail.one_shot = true
	bail.timeout.connect(func(): print("LOCALE FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — three languages ──")
	var before := Loc.current()

	for code in ["en", "fi", "ja"]:
		Loc.set_language(code)
		check("it can speak %s" % code, Loc.current() == code, Loc.current())

	# The owner's own line, and the FINNISH IS THE SOURCE — DESIGN §4.4 and
	# js/intro.js. If this ever comes back in English the pack has lost it.
	Loc.set_language("fi")
	var brief := tr("brief")
	check("the Finnish brief is the owner's line",
		brief.contains("työkoneiden") and brief.contains("robottien"), brief)

	# PER-KEY FALLBACK IS CORRECT AND COMPLETELY SILENT, which is why the
	# exporter refuses a missing key rather than letting it paper over. What
	# this can check from in here is that nothing came back as a bare key.
	print("  -- nothing falls through --")
	var sample := ["title", "start", "mResume", "mHome", "mLevels", "ctlMenu"]
	for code in ["en", "fi", "ja"]:
		Loc.set_language(code)
		var missed: Array[String] = []
		for k in sample:
			var v := tr(k)
			if v == k or v.strip_edges() == "":
				missed.append(k)
		check("%s translates every sampled key" % code, missed.is_empty(),
			"missing: " + ", ".join(missed))

	# fi and ja must not merely echo English — the trap toko/ and
	# piritori-eden both record shipping with every gate green.
	Loc.set_language("en")
	var en_title := tr("mLevels")
	Loc.set_language("fi")
	check("Finnish is not just English again", tr("mLevels") != en_title,
		"%s vs %s" % [tr("mLevels"), en_title])
	Loc.set_language("ja")
	check("Japanese is not just English again", tr("mLevels") != en_title,
		"%s vs %s" % [tr("mLevels"), en_title])

	# CJK has to actually render, not come back as tofu — the check
	# piritori-eden's locale gate exists for.
	var jp := tr("mResume")
	check("Japanese carries real CJK glyphs", jp.length() > 0 and jp.unicode_at(0) > 0x3000,
		jp)

	Loc.set_language(before)
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
