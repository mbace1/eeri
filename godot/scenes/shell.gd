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
# THE PLATE IS THE ART. js/main.js's own comment says it plainly: "the
# controls are a drawn backboard and the DOM buttons are transparent hit
# areas over it" -- assets/manifest.json's padplate_portrait note names the
# same picture (a Game Boy DMG face: d-pad, A/B on a slant, SELECT/START,
# the grill). Godot has no DOM, so the "hit areas" are real Controls, but
# they must stay exactly as transparent as the browser's -- nothing drawn on
# them -- or the plate's own D-pad/A/B artwork gets a second, competing set
# of buttons pasted on top of it.
#
# THIS WAS WRONG until 2026-08-26: the buttons carried the figure-glyph
# textures from js/glyphs.js (fill="#20242b", drawn for LIGHT panels like
# the pause menu) as their visible face, and their positions were fixed
# pixel offsets from the screen's own corners. Two bugs, one screenshot: the
# glyphs read as near-black smudges with nothing behind them, and because
# STRETCH_KEEP_ASPECT_CENTERED draws the plate image CENTERED in its band
# rather than filling it, the corner-anchored buttons were never actually
# sitting over the d-pad/A/B art at any screen width to begin with -- they
# were positioned relative to the SCREEN, not to the PICTURE.
#
# Fixed by computing the plate's own drawn rect (the same aspect-fit math
# STRETCH_KEEP_ASPECT_CENTERED does internally, since Godot does not expose
# it) and placing each hit area at a FRACTION of that rect, measured once
# against the actual artwork (see PAD_ART below). Only shown when a touch is
# actually seen -- a pad on a desktop screen is clutter.

## The source picture's own pixel size and the hit-zone centres/radii
## measured directly against it (assets/2d/padplate_v2.webp, 1024x590).
## Everything below is a FRACTION of these, so it never depends on what
## width phone this happens to run on.
const PAD_IMG := Vector2(1024.0, 590.0)
const PAD_BAND_H := 220.0   # the band's height when nothing constrains width
const DPAD_CENTER := Vector2(324.0, 316.0)
const DPAD_R := 128.0
const A_CENTER := Vector2(871.0, 258.0)
const A_R := 70.0
const B_CENTER := Vector2(741.0, 324.0)
const B_R := 68.0
## How far out from the d-pad's own centre each direction's hit zone sits,
## as a fraction of DPAD_R -- 0.55 lands solidly on that arrow, not the hub.
const DPAD_ARM := 0.55

func _build_touch() -> void:
	_touch = Control.new()
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch.visible = false
	add_child(_touch)

	var pp: Dictionary = AssetRegistry.manifest.get("ui", {}).get("padplate_portrait", {})
	var plate_rect := Rect2()
	if String(pp.get("status", "")) == "live":
		var t := load("res://data/" + String(pp.get("file", ""))) as Texture2D
		if t:
			var plate := TextureRect.new()
			plate.texture = t
			plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Anchors AND offsets set together, explicitly, in one pass --
			# set_anchors_preset() alone computes offsets from whatever size
			# the control has at that exact call (zero, before it is even
			# parented), which is the same class of bug already fixed once
			# in this file for the pause panel.
			plate.anchor_left = 0.0; plate.anchor_right = 1.0
			plate.anchor_top = 1.0; plate.anchor_bottom = 1.0
			plate.offset_left = 0.0; plate.offset_right = 0.0
			plate.offset_top = -PAD_BAND_H; plate.offset_bottom = 0.0
			_touch.add_child(plate)
			plate_rect = _fitted_rect(get_viewport().get_visible_rect().size)

	if plate_rect.size == Vector2.ZERO:
		# No plate (placeholder/missing art): fall back to the old
		# corner-anchored layout so the game stays playable, at least.
		_touch_button_at("move_left", Vector2(24, -140), false)
		_touch_button_at("move_right", Vector2(140, -140), false)
		_touch_button_at("move_up", Vector2(82, -210), false)
		_touch_button_at("move_down", Vector2(82, -80), false)
		_touch_button_at("jump", Vector2(-180, -140), true)
		_touch_button_at("action", Vector2(-96, -200), true)
		return

	# Every hit zone is the measured picture point, scaled by the plate's
	# ACTUAL on-screen size (not assumed -- see _fitted_rect), then offset
	# from the plate's own drawn corner. This is what makes it correct at
	# any phone width instead of only the one it happened to be tuned on.
	var s: Vector2 = plate_rect.size / PAD_IMG
	var o: Vector2 = plate_rect.position

	var dpad_screen: Vector2 = o + DPAD_CENTER * s
	var dpad_r_screen: float = DPAD_R * s.x
	_touch_button_abs("move_up", dpad_screen + Vector2(0, -dpad_r_screen * DPAD_ARM))
	_touch_button_abs("move_down", dpad_screen + Vector2(0, dpad_r_screen * DPAD_ARM))
	_touch_button_abs("move_left", dpad_screen + Vector2(-dpad_r_screen * DPAD_ARM, 0))
	_touch_button_abs("move_right", dpad_screen + Vector2(dpad_r_screen * DPAD_ARM, 0))
	_touch_button_abs("jump", o + A_CENTER * s)
	_touch_button_abs("action", o + B_CENTER * s)


## The rect STRETCH_KEEP_ASPECT_CENTERED actually draws the texture into,
## given the band's own size. Godot does not expose this (it is computed at
## draw time inside the renderer), so it is worked out by hand here: fit
## PAD_IMG's aspect into (band_w x PAD_BAND_H), centred either way.
func _fitted_rect(viewport_size: Vector2) -> Rect2:
	var band_w := viewport_size.x
	var img_aspect := PAD_IMG.x / PAD_IMG.y
	var w := PAD_BAND_H * img_aspect
	var h := PAD_BAND_H
	if w > band_w:
		w = band_w
		h = band_w / img_aspect
	var x := (band_w - w) * 0.5
	var y := viewport_size.y - PAD_BAND_H + (PAD_BAND_H - h) * 0.5
	return Rect2(Vector2(x, y), Vector2(w, h))


## A fully transparent hit area -- no texture, no visible face of any kind.
## Whatever is under it (the plate's own drawn D-pad/A/B) IS the button.
func _touch_button_abs(action: String, center: Vector2) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(MIN_TARGET, MIN_TARGET)
	b.size = Vector2(MIN_TARGET, MIN_TARGET)
	b.position = center - b.size * 0.5
	b.button_down.connect(func(): _press(action, true))
	b.button_up.connect(func(): _press(action, false))
	_touch.add_child(b)


## Fallback only: no plate art, so the old glyph-faced corner buttons come
## back rather than leaving the player with nothing to press at all.
func _touch_button_at(action: String, at: Vector2, from_right: bool) -> void:
	var glyph := action.trim_prefix("move_")
	var b := TextureButton.new()
	if _glyphs.has(glyph):
		b.texture_normal = _glyphs[glyph]
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
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
