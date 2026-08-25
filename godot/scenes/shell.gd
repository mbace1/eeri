class_name Shell
extends CanvasLayer
## The wrapper around the game: title, HUD, pause + level select, and the
## touch pad. Ported from js/intro.js and js/menu.js.
##
## TWO RULES GOVERN EVERY CONTROL HERE.
##
##   DESIGN §6.4 — no key caps or mouse icons, EVER. The buttons carry the
##   figure glyphs (a running Eeri, a climbing Eeri) exported from
##   js/glyphs.js, because the player is six and the game must read the same
##   on a pad, a keyboard and a thumb.
##
##   44 logical pixels is the floor on every interactive target, and the
##   house convention across this whole family of projects.

signal start_pressed
signal resume_pressed
signal restart_pressed
signal level_chosen(slug: String)

const MIN_TARGET := 44.0

var _title: Control
var _hud: Label
var _pause: Control
var _touch: Control
var _glyphs := {}


func _ready() -> void:
	layer = 10
	_load_glyphs()
	_build_hud()
	_build_title()
	_build_pause()
	_build_touch()
	Loc.language_changed.connect(func(_c): _retext())


func _load_glyphs() -> void:
	for n in ["left", "right", "up", "down", "jump", "action", "menu"]:
		var p := "res://data/glyphs/%s.svg" % n
		if ResourceLoader.exists(p):
			_glyphs[n] = load(p)


# ---- the title -----------------------------------------------------------
# js/intro.js: shown before the scene builds, and `?skip` walks past it —
# every gate uses that, which is why it stays a separate switch rather than
# something the tests have to click through.
func _build_title() -> void:
	_title = _panel(Color(0.29, 0.66, 0.91, 1.0))
	# A CenterContainer, not PRESET_CENTER on the box: the preset places a
	# control's CORNER at the centre, which anchored the whole title screen
	# into the bottom-right quadrant and ran it off the frame.
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(mid)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	mid.add_child(box)

	var logo := TextureRect.new()
	var lp: Dictionary = AssetRegistry.manifest.get("ui", {}).get("logo", {})
	if String(lp.get("status", "")) == "live":
		var t := load("res://data/" + String(lp.get("file", ""))) as Texture2D
		if t:
			logo.texture = t
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			logo.custom_minimum_size = Vector2(560, 220)
			box.add_child(logo)

	var brief := Label.new()
	brief.name = "Brief"
	brief.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief.add_theme_font_size_override("font_size", 20)
	box.add_child(brief)

	var start := _button("Start", func(): start_pressed.emit())
	start.custom_minimum_size = Vector2(220, 56)
	box.add_child(start)

	var lang := _button("Lang", func(): Loc.next_language())
	box.add_child(lang)
	_retext()


func show_title(v: bool) -> void:
	_title.visible = v


# ---- the HUD -------------------------------------------------------------
# What a six-year-old needs to read at a glance, and nothing else. The counts
# are DESIGN §4.2's: a hundred bolts is the level's completion figure and the
# three golden ones are the reason to come back. Every word comes through
# tr(), because §4.4 makes fi the language this is actually played in.
#
# The debug line lives behind a switch. It was the HUD for most of this port
# and it was the right thing while nothing else existed, but a readout of
# x/y and robot counts is not something you hand to a child.
var _hud_left: Label
var _hud_right: Label
var _banner: Label
var _debug: Label
var _banner_t := 0.0
var show_debug := false


func _build_hud() -> void:
	# ANCHOR FIRST, THEN OFFSET. set_anchors_preset REWRITES the offsets, so a
	# position assigned before it is silently thrown away — which is how the
	# right-hand readout ended up off the side of the screen.
	_hud_left = _hud_label(HORIZONTAL_ALIGNMENT_LEFT, 26)
	_hud_left.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_left.offset_left = 20
	_hud_left.offset_top = 14

	_hud_right = _hud_label(HORIZONTAL_ALIGNMENT_RIGHT, 22)
	_hud_right.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_right.offset_right = -20
	_hud_right.offset_top = 14

	# The banner: LEVEL CLEAR, CHECKPOINT, BLUEPRINT. Big, centred, brief.
	_banner = _hud_label(HORIZONTAL_ALIGNMENT_CENTER, 44)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 120
	_banner.visible = false

	_debug = _hud_label(HORIZONTAL_ALIGNMENT_LEFT, 15)
	_debug.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_debug.offset_left = 20
	_debug.offset_top = 58
	_debug.visible = false


func _hud_label(align: int, size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


## `state` is the small dictionary play.gd already has to hand.
func set_hud(state: Dictionary) -> void:
	_hud_left.text = "%s  %d/%d" % [tr("bolts"),
		int(state.get("bolts", 0)), int(state.get("bolts_total", 100))]
	var g := "%s  %d/%d" % [tr("golden"),
		int(state.get("golden", 0)), int(state.get("golden_total", 3))]
	# The level's own address (DESIGN §4) — it is what makes a room nameable
	# and a link shareable, so it belongs on screen rather than in a menu.
	_hud_right.text = "%s
%s" % [String(state.get("address", "")).to_upper(), g]


## One line, briefly, for the beats worth naming.
func banner(key: String) -> void:
	_banner.text = tr(key)
	_banner.visible = true
	_banner_t = 1.8


func set_debug(text: String) -> void:
	_debug.text = text
	_debug.visible = show_debug


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.visible = false


# ---- pause + level select ------------------------------------------------
# DESIGN §4.1: "No map. Levels run 1 -> 12 in order, and any unlocked level
# can be jumped to from a menu." So this IS the map, and CLAUDE.md §5 makes it
# a debug affordance as well: a level nobody can reach in under 30 seconds is
# not finished.
func _build_pause() -> void:
	_pause = _panel(Color(0.05, 0.07, 0.10, 0.86))
	_pause.visible = false
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(mid)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	mid.add_child(box)

	box.add_child(_button("Resume", func(): resume_pressed.emit()))
	box.add_child(_button("Restart", func(): restart_pressed.emit()))
	box.add_child(_button("Lang", func(): Loc.next_language()))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for e in LevelData.load_index().get("levels", []):
		var slug := String(e.get("slug", ""))
		var b := Button.new()
		b.text = slug.replace("eeri-", "")
		b.custom_minimum_size = Vector2(72, MIN_TARGET)
		b.pressed.connect(func(): level_chosen.emit(slug))
		grid.add_child(b)


func toggle_pause() -> bool:
	_pause.visible = not _pause.visible
	return _pause.visible


func paused() -> bool:
	return _pause.visible


func set_paused(v: bool) -> void:
	_pause.visible = v


# ---- the touch pad -------------------------------------------------------
# Rebuilt as real Control nodes over the painted plate (owner's call). The
# browser build draws a Game Boy face and lays transparent DOM hit areas on
# it; Godot has no DOM, so the buttons ARE Controls and the plate sits behind
# them. Only shown when a touch is actually seen — a pad on a desktop screen
# is clutter.
func _build_touch() -> void:
	_touch = Control.new()
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch.visible = false
	add_child(_touch)

	var plate := TextureRect.new()
	var pp: Dictionary = AssetRegistry.manifest.get("ui", {}).get("padplate_portrait", {})
	if String(pp.get("status", "")) == "live":
		var t := load("res://data/" + String(pp.get("file", ""))) as Texture2D
		if t:
			plate.texture = t
			plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			plate.custom_minimum_size = Vector2(0, 220)
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_touch.add_child(plate)

	# left / right / up on the left, jump + action on the right
	_touch_button("left", "move_left", Vector2(24, -140))
	_touch_button("right", "move_right", Vector2(140, -140))
	_touch_button("up", "move_up", Vector2(82, -210))
	_touch_button("down", "move_down", Vector2(82, -80))
	_touch_button("jump", "jump", Vector2(-180, -140), true)
	_touch_button("action", "action", Vector2(-96, -200), true)


func _touch_button(glyph: String, action: String, at: Vector2, from_right := false) -> void:
	var b := TextureButton.new()
	if _glyphs.has(glyph):
		b.texture_normal = _glyphs[glyph]
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# 62px, comfortably over the 44 floor — a six-year-old's thumb is not a
	# stylus, and js/glyphs.js draws this set at exactly this size for touch.
	b.custom_minimum_size = Vector2(62, 62)
	b.size = Vector2(62, 62)
	if from_right:
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	else:
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.position = at
	b.button_down.connect(func(): _press(action, true))
	b.button_up.connect(func(): _press(action, false))
	_touch.add_child(b)


## Feed the InputMap rather than a private path, so nothing downstream ever
## learns whether a press came from a thumb, a pad or a key.
func _press(action: String, down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)


func show_touch(v: bool) -> void:
	_touch.visible = v


# ---- helpers -------------------------------------------------------------
func _panel(col: Color) -> Control:
	var c := ColorRect.new()
	c.color = col
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


func _button(key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.set_meta("key", key)
	b.custom_minimum_size = Vector2(200, MIN_TARGET)
	b.pressed.connect(cb)
	return b


## Re-text on a language change WITHOUT rebuilding, so a switch cannot lose
## where you were — the same rule piritori-eden's shell keeps.
func _retext() -> void:
	if _title == null:
		return
	for n in _all(self):
		if n is Button and n.has_meta("key"):
			var k := String(n.get_meta("key"))
			n.text = tr(_KEYS.get(k, k))
	var b := _title.find_child("Brief", true, false)
	if b is Label:
		(b as Label).text = tr("brief")


const _KEYS := {
	"Start": "start",
	"Resume": "mResume",
	"Restart": "mRestart",
	"Lang": "mLang",
}


func _all(n: Node, out: Array[Node] = []) -> Array[Node]:
	for c in n.get_children():
		out.append(c)
		_all(c, out)
	return out
