extends Node
## fi / en / ja — DESIGN §4.4.
##
## The strings are GENERATED from js/lang.js by tools/export-locale.mjs into
## locale/ui.csv. Nothing here re-authors a translation, and nothing should:
## the game is played by a Finnish six-year-old, and a second hand-kept copy
## of the Finnish is exactly the thing that drifts. Both toko/ and
## piritori-eden record shipping English-only entries with every gate green,
## because per-key fallback is correct behaviour AND completely silent.
##
## Owner's line, and the Finnish is the SOURCE, not a translation of the
## English: "seikkailee työkoneiden ja robottien maailmassa".

const LANGS := ["fi", "en", "ja"]
const SAVE_KEY := "user://eeri-lang.txt"

signal language_changed(code: String)


func _ready() -> void:
	set_language(_load_saved())


## Browser-detected on first run, then remembered — the same shape js/lang.js
## uses. A Finnish browser lands in Finnish.
func _load_saved() -> String:
	if FileAccess.file_exists(SAVE_KEY):
		var f := FileAccess.open(SAVE_KEY, FileAccess.READ)
		var c := f.get_as_text().strip_edges()
		f.close()
		if c in LANGS:
			return c
	var sys := OS.get_locale_language()
	return sys if sys in LANGS else "en"


func current() -> String:
	var l := TranslationServer.get_locale()
	return l.substr(0, 2)


func set_language(code: String) -> void:
	if code not in LANGS:
		code = "en"
	TranslationServer.set_locale(code)
	var f := FileAccess.open(SAVE_KEY, FileAccess.WRITE)
	if f:
		f.store_string(code)
		f.close()
	language_changed.emit(code)


## Cycle, for a single button — DESIGN §6.4 forbids naming a key, and a
## language MENU is a lot of UI for three options.
func next_language() -> String:
	var i := LANGS.find(current())
	var code: String = LANGS[(i + 1) % LANGS.size()]
	set_language(code)
	return code
