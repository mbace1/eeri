extends Node
## The sound kit — the voices js/audio.js synthesises, rendered ahead of time
## by tools/export-audio.mjs and played back as samples.
##
## The house rule is "synthesised, never sampled" and eeri/test/dev-menu.mjs
## enforces it with a gate. Godot inverts the economics — it streams samples
## well and synthesises awkwardly — so on the owner's call (2026-08-24,
## "whatever works, music is placeholder") the kit is still synthesised, just
## AHEAD OF TIME from the same voice table. Nobody recorded anything and there
## is no second definition of what a stomp sounds like.
##
## Everything routes through one bus so a mute is total and any voice added
## later inherits it — the same discipline js/audio.js keeps with its single
## master gain.

const VOICES := ["jump", "land", "bolt", "mount", "stomp", "dismount",
	"boom", "clank", "thunk", "warn", "splat"]
## Enough voices that a stomp during a bolt pickup does not cut either off.
const POLYPHONY := 8

var on := true

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for v in VOICES:
		var p := "res://data/audio/%s.wav" % v
		if ResourceLoader.exists(p):
			_streams[v] = load(p)
	for i in POLYPHONY:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)


func play(voice: String, pitch := 1.0, volume_db := -6.0) -> void:
	if not on or not _streams.has(voice):
		return
	var pl := _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = _streams[voice]
	pl.pitch_scale = clampf(pitch, 0.2, 4.0)
	pl.volume_db = volume_db
	pl.play()


## The bolt climbs the chain, exactly as js/audio.js does: 660 * 1.06^n,
## capped at twelve so it never leaves the top of the register.
func bolt(n: int) -> void:
	play("bolt", pow(1.06, float(mini(n, 12))))


func set_on(v: bool) -> void:
	on = v
	if not v:
		for pl in _players:
			pl.stop()
