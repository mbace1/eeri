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
	_retext()


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
var _banner: Label
var _debug: Label
var _banner_t := 0.0
var show_debug := false


## THE HUD, MATCHED TO THE BROWSER BUILD.
##
## index.html puts the whole readout in ONE top-right block and nothing in the
## top-left. The port had it split across both corners with different words, so
## the two builds disagreed about what the screen says. Three lines, right
## aligned, in the browser's own sizes and colours:
##
##     EERI          800 18px, white
##     1-2 . LEVEL 2 -- THE SCAFFOLD    700 12px, #d9efff
##     [] 3/12  * 0/3                   700 15px, #ffe9bd / #ffc63f
##
## Sizes are scaled up from the browser's CSS pixels because this build is read
## on a tablet at arm's length rather than a phone at 30cm.
const HUD_SCALE := 1.7
const C_TITLE := Color.WHITE
const C_SITE := Color("#d9efff")
const C_BOLTS := Color("#ffe9bd")
const C_GOLD := Color("#ffc63f")

var _hud_box: VBoxContainer
var _hud_title: Label
var _hud_site: Label
var _hud_bolts: Label
var _hud_gold: Label
var _hud_bp: Label
var _bp_icon: Control
var _hint: Label
var _hint_box: PanelContainer


func _build_hud() -> void:
	_hud_box = VBoxContainer.new()
	# ANCHOR FIRST, THEN OFFSET. set_anchors_preset REWRITES the offsets, so a
	# position assigned before it is silently thrown away -- which is how the
	# right-hand readout once ended up off the side of the screen.
	_hud_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hud_box.offset_right = -20
	_hud_box.offset_top = 14
	_hud_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hud_box.add_theme_constant_override("separation", 2)
	_hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_box)

	_hud_title = _hud_label(HORIZONTAL_ALIGNMENT_RIGHT, int(18 * HUD_SCALE), C_TITLE, _hud_box)
	_hud_title.text = "EERI"

	_hud_site = _hud_label(HORIZONTAL_ALIGNMENT_RIGHT, int(12 * HUD_SCALE), C_SITE, _hud_box)

	# The two counters share a line, as they do in index.html, but keep their
	# own colours -- so they are two labels rather than one string.
	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_END
	counts.add_theme_constant_override("separation", int(10 * HUD_SCALE))
	counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_box.add_child(counts)
	var icon_px := 15.0 * HUD_SCALE
	counts.add_child(HudIcon.new("hex", C_BOLTS, icon_px))
	_hud_bolts = _hud_label(HORIZONTAL_ALIGNMENT_RIGHT, int(15 * HUD_SCALE), C_BOLTS, counts)
	counts.add_child(HudIcon.new("star", C_GOLD, icon_px))
	_hud_gold = _hud_label(HORIZONTAL_ALIGNMENT_RIGHT, int(15 * HUD_SCALE), C_GOLD, counts)
	# BLUEPRINTS ONLY APPEAR ONCE YOU HAVE ONE, so the icon hides with the text.
	_bp_icon = HudIcon.new("sheet", C_GOLD, icon_px)
	_bp_icon.visible = false
	counts.add_child(_bp_icon)
	_hud_bp = _hud_label(HORIZONTAL_ALIGNMENT_RIGHT, int(15 * HUD_SCALE), C_GOLD, counts)
	_hud_bp.visible = false

	# THE HINT, index.html #hint: bottom centre, on a dark pill so it stays
	# readable over both a bright sky and a dark cut.
	_hint_box = PanelContainer.new()
	_hint_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_box.offset_bottom = -20
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.102, 0.078, 0.063, 0.5)   # rgba(26,20,16,0.5)
	pill.set_corner_radius_all(8)
	pill.content_margin_left = 14; pill.content_margin_right = 14
	pill.content_margin_top = 9; pill.content_margin_bottom = 9
	_hint_box.add_theme_stylebox_override("panel", pill)
	add_child(_hint_box)
	_hint = _hud_label(HORIZONTAL_ALIGNMENT_CENTER, int(13 * HUD_SCALE), Color.WHITE, _hint_box)
	_hint_box.visible = false

	# The banner: LEVEL CLEAR, CHECKPOINT, BLUEPRINT. index.html centres it in
	# the viewport (`inset: 0; place-content: center`), not near the top.
	_banner = _hud_label(HORIZONTAL_ALIGNMENT_CENTER, int(34 * HUD_SCALE), Color.WHITE)
	# set_anchors_preset(FULL_RECT) alone left the Label sized to its own text
	# (PRESET_MODE_MINSIZE, the default) rather than filling the screen, so the
	# centred text drew pinned to the top-left instead. Anchors AND offsets
	# both have to be pushed out to actually cover the viewport.
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.offset_left = 0; _banner.offset_top = 0
	_banner.offset_right = 0; _banner.offset_bottom = 0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.visible = false

	_debug = _hud_label(HORIZONTAL_ALIGNMENT_LEFT, 15, Color.WHITE)
	_debug.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_debug.offset_left = 20
	_debug.offset_right = -20
	_debug.offset_top = 58
	# Errors are long and a phone is narrow -- wrap rather than run off the
	# right edge, which is where the useful half of a shader error lives.
	_debug.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug.visible = false


## `parent` matters: a Label handed straight to add_child() here cannot then
## be moved into a container -- Godot refuses to reparent a node that already
## has one -- which stacked all three HUD lines at 0,0 in the top-left corner.
func _hud_label(align: int, size: int, col := Color.WHITE, parent: Node = null) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.102, 0.078, 0.063))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent == null:
		parent = self
	parent.add_child(l)
	return l


## THE HUD ICONS ARE DRAWN, NOT TYPED.
##
## index.html can spend U+2B21 and U+2726 freely because a browser falls back
## across every font on the device. Godot ships ONE font, and a probe of it
## found exactly one of eighteen candidate symbols present -- so the hexagon,
## the spark and the blueprint would all have rendered as tofu, which is worse
## than the word they replaced. Twenty lines of draw calls cost nothing, carry
## the palette colour exactly, and cannot regress when the font changes.
class HudIcon extends Control:
	var kind := "hex"
	var col := Color.WHITE

	func _init(k: String, c: Color, px: float) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		var mid := size * 0.5
		match kind:
			"hex":
				# The bolt is a HEX NUT -- it is what the kid is collecting off
				# a worksite, and it is what index.html's U+2B21 stands for.
				var pts := PackedVector2Array()
				for i in 6:
					var a := TAU * (float(i) / 6.0) - PI * 0.5
					pts.append(mid + Vector2(cos(a), sin(a)) * r * 0.92)
				draw_colored_polygon(pts, col)
			"star":
				# A four-point spark, the shape U+2726 draws.
				var pts2 := PackedVector2Array()
				for i in 8:
					var a := TAU * (float(i) / 8.0) - PI * 0.5
					var rr: float = r if i % 2 == 0 else r * 0.36
					pts2.append(mid + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts2, col)
			"sheet":
				# The blueprint: a sheet with lines ruled on it.
				var rect := Rect2(mid - Vector2(r * 0.8, r * 0.92),
					Vector2(r * 1.6, r * 1.84))
				draw_rect(rect, col, false, maxf(1.0, r * 0.18))
				for i in 3:
					var y: float = rect.position.y + rect.size.y * (0.28 + 0.22 * float(i))
					draw_line(Vector2(rect.position.x + r * 0.3, y),
						Vector2(rect.end.x - r * 0.3, y), col, maxf(1.0, r * 0.14))


## `state` is the small dictionary play.gd already has to hand.
func set_hud(state: Dictionary) -> void:
	var addr := String(state.get("address", "")).strip_edges()
	var nm := String(state.get("name", "")).strip_edges()
	# index.html: "the address beside the name, so what is on screen is what
	# you can paste to somebody" -- 1-2 . LEVEL 2 -- THE SCAFFOLD
	_hud_site.text = ("%s  ·  %s" % [addr, nm]).to_upper() if nm != "" else addr.to_upper()
	_hud_bolts.text = "%d/%d" % [
		int(state.get("bolts", 0)), int(state.get("bolts_total", 0))]
	_hud_gold.text = "%d/%d" % [
		int(state.get("golden", 0)), int(state.get("golden_total", 0))]
	# BLUEPRINTS ONLY APPEAR ONCE YOU HAVE ONE. js/main.js: "a 0/4 on the HUD
	# from the first second is a chore printed on the screen; a count that
	# shows up the moment you find the first one is a discovery that stayed."
	var bp := int(state.get("blueprints", 0))
	_bp_icon.visible = bp > 0
	_hud_bp.visible = bp > 0
	if bp > 0:
		_hud_bp.text = "%d/4" % bp


## THE HINT TEXT ARRIVES WITH GLYPHS THE FONT DOES NOT CARRY. Same finding as
## HudIcon above: js/lang.js's hint strings are written for a browser, which
## falls back across every font on the device -- so "Ⓐ CLIMB IN" and
## "◀ ▶ RUN" cost it nothing. Godot ships one font, and it was probed for
## exactly these characters and has none of them. Swapping in plain ASCII
## keeps every hint LEGIBLE rather than showing tofu boxes in the middle of a
## sentence, which is worse than the glyph it replaced -- the same argument
## CLAUDE.md's Godot section already makes for MultiMesh colours and font
## coverage generally.
const _HINT_SAFE := {
	"◀": "<", "▶": ">", "▲": "^", "▼": "v", "Ⓐ": "A", "Ⓑ": "B",
}


## index.html #hint -- one short line, or nothing at all.
func set_hint(text: String) -> void:
	if _hint == null:
		return
	for glyph in _HINT_SAFE:
		text = text.replace(glyph, _HINT_SAFE[glyph])
	if _hint.text != text:
		_hint.text = text
	_hint_box.visible = text != ""


## `secs` matches js/main.js's own per-banner hold exactly: checkpoint 1.0s,
## golden 1.2s, blueprint 1.4s -- it used one number for all three before,
## which is a real (if small) timing mismatch with the build it matches.
func banner(key: String, secs := 1.8) -> void:
	_banner.text = tr(key)
	_banner.visible = true
	_banner_t = secs


## GOLDEN BOLT n/total -- js/main.js: `GOLDEN BOLT  ✦ ${goldenGot}/${total}`.
## Text only, no symbol: the bundled font was probed for U+2726 and does not
## carry it (see HudIcon above), and a missing glyph is worse than the word.
func banner_golden(got: int, total: int) -> void:
	_banner.text = "%s
%d/%d" % [tr("golden").to_upper(), got, total]
	_banner.visible = true
	_banner_t = 1.2


## THE WORLD'S CLOCK-OUT CARD. index.html #clear: title + a counts line,
## `⬡ total · ✦ total`. What is NOT ported: the built building itself
## (js/main.js buildWorldBuilding) -- that needs per-world part geometry and
## a parts-collected count this build does not track yet (play.gd's own
## _step_advance already says so: "the clock-out beat... is not built"). So
## this card is real but shorter than the browser's by exactly that one line
## -- named here rather than silently dropped.
func clock_out(bolts: int, golden: int) -> void:
	_banner.text = "%s
%d / %d" % [tr("clockOut"), bolts, golden]
	_banner.visible = true
	_banner_t = 999.0   # held until the scene tears down or the next one shows


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
## js/menu.js's own name for what this is: "not a settings screen... carry
## on, start this bit again, go to a level, change the language, go home. No
## sliders, no toggles that need reading." Same five verbs here, same shape:
## title, Resume, Restart, a LEVELS row, a LANGUAGE row, Home.
const LANG_NAME := {"en": "English", "fi": "suomi", "ja": "日本語"}

var _pause_title: Label
var _pause_levels_label: Label
var _pause_lang_label: Label
var _lang_buttons := {}      # code -> Button, so language_changed can re-highlight
var _level_buttons := {}     # slug -> Button, so re-entering re-highlights "here"
var _pause_first: Button     # what a controller/keyboard focuses on open


func _build_pause() -> void:
	_pause = _panel(Color(0.05, 0.07, 0.10, 0.86))
	_pause.visible = false
	var mid := CenterContainer.new()
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(mid)
	var card := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color("#2b2118")
	pstyle.border_color = Color("#14100c")
	pstyle.set_border_width_all(4)
	pstyle.set_corner_radius_all(16)
	pstyle.content_margin_left = 22; pstyle.content_margin_right = 22
	pstyle.content_margin_top = 18; pstyle.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", pstyle)
	mid.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 320
	card.add_child(box)

	_pause_title = _hud_label(HORIZONTAL_ALIGNMENT_CENTER, 26, Color("#ffb01f"), box)
	_pause_title.text = "EERI"

	_pause_first = _button("Resume", func(): resume_pressed.emit())
	box.add_child(_pause_first)
	box.add_child(_button("Restart", func(): restart_pressed.emit()))

	_pause_levels_label = _row_label(box)
	var lgrid := GridContainer.new()
	lgrid.columns = 3
	lgrid.add_theme_constant_override("h_separation", 8)
	lgrid.add_theme_constant_override("v_separation", 8)
	box.add_child(lgrid)
	for e in LevelData.load_index().get("levels", []):
		var slug := String(e.get("slug", ""))
		var b := Button.new()
		b.text = slug.replace("eeri-", "")
		b.custom_minimum_size = Vector2(72, MIN_TARGET)
		b.pressed.connect(func(): level_chosen.emit(slug))
		lgrid.add_child(b)
		_level_buttons[slug] = b

	_pause_lang_label = _row_label(box)
	var ggrid := GridContainer.new()
	ggrid.columns = 3
	ggrid.add_theme_constant_override("h_separation", 8)
	ggrid.add_theme_constant_override("v_separation", 8)
	box.add_child(ggrid)
	for code in ["fi", "en", "ja"]:
		var lb := Button.new()
		lb.text = LANG_NAME.get(code, code)
		lb.custom_minimum_size = Vector2(0, MIN_TARGET)
		# THE LANGUAGE SWITCH REPAINTS rather than closing the menu -- js/menu.js:
		# "a menu that closes itself when you change the language is a menu
		# that argues [with you about what you just asked for]".
		lb.pressed.connect(func(): Loc.set_language(code))
		ggrid.add_child(lb)
		_lang_buttons[code] = lb

	box.add_child(_button("Home", func(): _go_home()))
	_retext_pause()


func _row_label(parent: Node) -> Label:
	return _hud_label(HORIZONTAL_ALIGNMENT_CENTER, 12, Color("#d9c9ab"), parent)


## js/main.js's `home: () => { location.href = '../'; }` -- one level up from
## the game to the hub page both cabinets are listed on. Only meaningful in
## the web export; elsewhere there is no hub to return to, so the button is
## hidden rather than doing nothing when pressed.
func _go_home() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.href = '../'", true)


func _retext_pause() -> void:
	var here := Loc.current()
	for code in _lang_buttons.keys():
		var b: Button = _lang_buttons[code]
		b.disabled = code == here
		b.modulate = Color("#ffb01f") if code == here else Color.WHITE
	if _pause_levels_label:
		_pause_levels_label.text = tr("mLevels")
	if _pause_lang_label:
		_pause_lang_label.text = tr("mLang")


## Marks the level the player is actually in, same "aria-current" role
## js/menu.js gives the browser build's own grid.
func mark_current_level(slug: String) -> void:
	for s in _level_buttons.keys():
		var b: Button = _level_buttons[s]
		b.modulate = Color("#ffb01f") if s == slug else Color.WHITE


func toggle_pause() -> bool:
	_pause.visible = not _pause.visible
	if _pause.visible:
		# GRAB FOCUS ON OPEN. Without this a controller or a keyboard opens the
		# menu onto nothing selected, and the d-pad has nothing to move --
		# reported directly: "Pause Menu on controller doesn't work". Godot's
		# ui_up/ui_down/ui_accept already carry joypad bindings by default; the
		# one thing missing was ever putting focus somewhere for them to move.
		_pause_first.grab_focus()
	return _pause.visible


func paused() -> bool:
	return _pause.visible


func set_paused(v: bool) -> void:
	_pause.visible = v
	if v:
		_pause_first.grab_focus()


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
	# Input.action_press/action_release, NOT parse_input_event(InputEventAction).
	#
	# THIS IS WHY THE TOUCH PAD DID NOTHING. parse_input_event dispatches an
	# event through _input/_unhandled_input, but it does NOT update the
	# internal action state that Input.is_action_pressed() reads -- and polling
	# that is exactly how the game loop asks for input (play.gd and play2d.gd
	# both call Input.is_action_pressed every fixed step, because a fixed
	# timestep must poll rather than react). So every thumb press was
	# delivered to a listener nobody had, and the buttons were dead.
	#
	# action_press/action_release write that state directly, which is what the
	# docs point at for synthesised input, and it keeps the rule this function
	# exists for: nothing downstream learns whether a press came from a thumb,
	# a pad or a key.
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


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
	"Home": "mHome",
}


func _all(n: Node, out: Array[Node] = []) -> Array[Node]:
	for c in n.get_children():
		out.append(c)
		_all(c, out)
	return out
