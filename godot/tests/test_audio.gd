extends Node
## The sound kit. Synthesised ahead of time, not recorded — so what this can
## check is that every voice the game asks for actually exists and plays, and
## that a mute is total.
##
## Run: godot --headless --path godot res://tests/test_audio.tscn
const EXPECTED := 6
var _pass := 0
var _fail := 0

func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0; bail.one_shot = true
	bail.timeout.connect(func(): print("AUDIO FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — the sound kit ──")
	var missing: Array[String] = []
	for v in Audio.VOICES:
		if not Audio._streams.has(v):
			missing.append(v)
	check("every voice rendered", missing.is_empty(),
		"missing: " + ", ".join(missing))
	check("the kit is the one js/audio.js defines", Audio.VOICES.size() == 11,
		"%d" % Audio.VOICES.size())

	# Polyphony: a stomp during a bolt pickup must not cut either off.
	check("it is polyphonic", Audio.POLYPHONY > 1, "%d" % Audio.POLYPHONY)

	# The bolt climbs the chain (660 * 1.06^n), capped at twelve so it never
	# leaves the top of the register.
	Audio.bolt(1)
	var p1 := _pitch()
	Audio.bolt(8)
	var p8 := _pitch()
	check("the bolt rises with the chain", p8 > p1, "%.2f vs %.2f" % [p8, p1])
	Audio.bolt(40)
	check("…and is capped, never runaway", _pitch() <= pow(1.06, 12) + 0.01,
		"%.2f" % _pitch())

	# A mute must be TOTAL — the same reason js/audio.js routes every voice
	# through one master gain rather than to the destination directly.
	Audio.set_on(false)
	Audio.play("stomp")
	var any := false
	for pl in Audio._players:
		if pl.playing: any = true
	check("muting silences everything", not any)
	Audio.set_on(true)
	_finish()

func _pitch() -> float:
	var i := (Audio._next - 1 + Audio._players.size()) % Audio._players.size()
	return Audio._players[i].pitch_scale

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
