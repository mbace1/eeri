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
## SELECT on the drawn pad. Cycles the on-device render bisect (see play.gd)
## -- the owner tests through a client where editing the URL is impractical,
## so the diagnostic has to be reachable with a thumb.
signal select_pressed
signal start_pressed_pad

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
	_debug.offset_right = -20
	_debug.offset_top = 58
	# Errors are long and a phone is narrow -- wrap rather than run off the
	# right edge, which is where the useful half of a shader error lives.
	_debug.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
# PORTED FROM THE BROWSER BUILD'S OWN MEASURED CSS (index.html, "the six hit
# areas" block), not re-measured from the picture -- the art lane already
# did that work and shipped it. Two corrections this made to the 2026-08-26
# fix above (kept as history, replaced below):
#
# 1. **The band is sized off VIEWPORT WIDTH, not a fixed height.** index.html:
#    "466/1024 of a 109%-wide box is ~50% of the viewport width in height" --
#    the plate is 109.2% of the screen's width (deliberately wider than the
#    screen and shifted left, because the drawn plate's own centre sits 6%
#    right of the image's centre) and its height FOLLOWS from that by the
#    cropped image's own aspect ratio. A fixed "220" (in whatever unit
#    get_viewport().get_visible_rect().size happens to be reporting) was
#    fragile for a reason found later, below.
# 2. **`get_visible_rect().size` is not device CSS pixels here.** Project
#    settings use `window/stretch/mode=canvas_items` + `aspect=expand`, and
#    `?debug`'s own render line proved it on a real export: a 420x900
#    browser window reported a Godot viewport size of roughly 1280x2385, not
#    420x900 -- Godot expands the LOGICAL 2D coordinate space to keep the
#    project's base resolution (1280x720) as a width floor, not the real
#    pixel count. (`toko-drop-godot`'s own PORT_STATUS.md hit the identical
#    thing for its HUD layer and named it first.) A HARD-CODED "220" is 220
#    of *that* space, not 220 CSS pixels, and the two are nowhere near the
#    same fraction of the screen. Expressing everything below as a fraction
#    of `viewport_size.x` (whatever unit it is) sidesteps the question
#    entirely: the ratio is the same regardless of which space it is measured
#    in, since canvas_items+expand does not distort aspect, only relabel it.
#
# The plate PNG (1024x590) also carries a yellow top strip (y 0..124) the
# browser crops out via `aspect-ratio: 1024/466; overflow: hidden` -- cropped
# here with an AtlasTexture region so the drawn art matches what the percent
# table below was measured against.

const PLATE_SRC := Vector2(1024.0, 590.0)
## The cropped box every hit-area percentage below is measured against --
## index.html: "y 75...588, with its yellow top strip ending at y 121" and
## "590 - 124 = the yellow gone".
const PLATE_CROP_TOP := 124.0
const PLATE_CROP_H := 466.0
## index.html: `#pad { left: -11%; right: 1.8%; }` with no explicit width --
## the resulting box is 100% - (-11%) - 1.8% = 109.2% of the viewport, and
## the left shift corrects for the plate's own drawn centre sitting 6%
## right of the image's centre.
const PLATE_WIDTH_FRAC := 1.092
const PLATE_LEFT_FRAC := -0.11
## index.html "the six hit areas": center (left%, top%) and size (width%,
## height%), all percentages of the CROPPED plate box (PLATE_CROP_H tall).
const HIT := {
	"move_up":    {"c": Vector2(0.318, 0.461), "s": Vector2(0.10, 0.16)},
	"move_down":  {"c": Vector2(0.318, 0.641), "s": Vector2(0.10, 0.16)},
	"move_left":  {"c": Vector2(0.266, 0.551), "s": Vector2(0.09, 0.18)},
	"move_right": {"c": Vector2(0.371, 0.551), "s": Vector2(0.09, 0.18)},
	"jump":       {"c": Vector2(0.852, 0.419), "s": Vector2(0.14, 0.24)},
	"action":     {"c": Vector2(0.725, 0.546), "s": Vector2(0.14, 0.24)},
	# SELECT / START, from index.html's own plated rules:
	#   #tSel { left: 47.5%; top: 88%; width: 11%; height: 13% }
	#   #tSt  { left: 59.5%; top: 88%; width: 11%; height: 13% }
	# They are drawn on the plate and were never wired here. SELECT now
	# drives the render bisect; START is the pause the pad always implied.
	"select":     {"c": Vector2(0.475, 0.880), "s": Vector2(0.11, 0.13)},
	"start":      {"c": Vector2(0.595, 0.880), "s": Vector2(0.11, 0.13)},
}

func _build_touch() -> void:
	_touch = Control.new()
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch.visible = false
	add_child(_touch)
	get_viewport().size_changed.connect(func(): _layout_touch(get_viewport().get_visible_rect().size))

	var pp: Dictionary = AssetRegistry.manifest.get("ui", {}).get("padplate_portrait", {})
	var has_plate := false
	if String(pp.get("status", "")) == "live":
		var t := load("res://data/" + String(pp.get("file", ""))) as Texture2D
		if t:
			var cropped := AtlasTexture.new()
			cropped.atlas = t
			cropped.region = Rect2(0, PLATE_CROP_TOP, PLATE_SRC.x, PLATE_CROP_H)
			var plate := TextureRect.new()
			plate.texture = cropped
			plate.stretch_mode = TextureRect.STRETCH_SCALE
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_touch.add_child(plate)
			_plate_control = plate
			has_plate = true

	if not has_plate:
		# No plate (placeholder/missing art): fall back to the old
		# corner-anchored layout so the game stays playable, at least.
		_touch_button_at("move_left", Vector2(24, -140), false)
		_touch_button_at("move_right", Vector2(140, -140), false)
		_touch_button_at("move_up", Vector2(82, -210), false)
		_touch_button_at("move_down", Vector2(82, -80), false)
		_touch_button_at("jump", Vector2(-180, -140), true)
		_touch_button_at("action", Vector2(-96, -200), true)
		return

	for action in HIT.keys():
		_touch_button_frac(action, HIT[action]["c"], HIT[action]["s"])
	_layout_touch(get_viewport().get_visible_rect().size)


## Recomputed on every resize/orientation change (cheap: a handful of Control
## rects), never assumed once at boot -- a phone that rotates mid-game must
## not strand the pad at the old aspect.
var _plate_control: TextureRect
var _touch_frac: Array = []   # [{node, action, c, s}] for _layout_touch

func _layout_touch(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var band_w: float = viewport_size.x * PLATE_WIDTH_FRAC
	var band_h: float = band_w * (PLATE_CROP_H / PLATE_SRC.x)
	var band_x: float = viewport_size.x * PLATE_LEFT_FRAC
	var band_y: float = viewport_size.y - band_h

	if _plate_control:
		_plate_control.position = Vector2(band_x, band_y)
		_plate_control.size = Vector2(band_w, band_h)

	for row in _touch_frac:
		var c: Vector2 = row["c"]
		var sz: Vector2 = row["s"]
		var center := Vector2(band_x + c.x * band_w, band_y + c.y * band_h)
		var want := Vector2(sz.x * band_w, sz.y * band_h)
		# THE FLOOR STILL APPLIES (DESIGN §5 / index.html's own note): on a
		# narrow phone the drawn switch is smaller than 44px, so the hit zone
		# is necessarily larger than the picture of it, not the other way round.
		want.x = maxf(want.x, MIN_TARGET)
		want.y = maxf(want.y, MIN_TARGET)
		var b: Button = row["node"]
		b.custom_minimum_size = want
		b.size = want
		b.position = center - want * 0.5


func _touch_button_frac(action: String, c: Vector2, sz: Vector2) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func(): _press(action, true))
	b.button_up.connect(func(): _press(action, false))
	_touch.add_child(b)
	_touch_frac.append({"node": b, "action": action, "c": c, "s": sz})


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
	# SELECT/START are UI, not gameplay verbs -- they have no InputMap action
	# and must not invent one, or a keyboard would silently gain a binding
	# nothing documents.
	if action == "select":
		if down: select_pressed.emit()
		return
	if action == "start":
		if down: start_pressed_pad.emit()
		return
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
