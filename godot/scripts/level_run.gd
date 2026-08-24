class_name LevelRun
extends RefCounted
## What turns a room into a LEVEL: the things you collect, the checkpoint that
## makes failing cheap, and the flag that ends it.
##
## Ported from js/main.js's per-site state and js/flag.js.
##
## DESIGN §4.2 fixes the counts and they are not decoration:
##   bolts x/100      the breadcrumb trail that teaches the route
##   golden 3/3       hidden, a reason to come back
##   blueprint 1      per world, and it unlocks concept art — the cheapest and
##                    most honest unlockable this project could have
##
## DESIGN §4.1: infinite retries, no lives, no game over. "The checkpoint is
## the only cost of failing, and the only currency is time."

## Tiles ahead of the flag at which each section lands (js/flag.js PHASE_AT).
const PHASE_AT := [15.0, 10.0, 5.5]
const PICKUP_R := 0.62

var level: LevelData

var bolts_got := 0
var bolts_total := 0
var golden_got := 0
var golden_total := 0
var blueprint_got := false

## Which entries are still out there. Index-aligned with the level's arrays.
var _bolt_taken: Array[bool] = []
var _golden_taken: Array[bool] = []

var checkpoint_lit := false
var checkpoint = null            # Vector2 once lit

var flag_phase := -1
var flag_raised := false
var finished := false

## One-frame events, for the caller to hang sound and banners off.
var just_bolt := false
var just_golden := false
var just_blueprint := false
var just_checkpoint := false
var just_phase := false
var just_raised := false


func _init(level_data: LevelData) -> void:
	level = level_data
	bolts_total = level.bolts.size()
	golden_total = level.golden.size()
	_bolt_taken.resize(bolts_total)
	_golden_taken.resize(golden_total)


## A collectible entry is [GRID ROW, col], and the row is TOP-DOWN — the same
## storage the tile grid uses. js/level.js does exactly this flip:
##
##     boltCells = def.bolts.map(([r, c]) => ({x: c + 0.5, y: (H - 1 - r) + 0.5}))
##
## Skipping it does not throw and does not look obviously broken: the bolts
## simply hang in the sky in mirror-image rows, a level that reads as merely
## badly authored. A screenshot found it; no assertion would have.
static func _cell_to_xy_h(e, h: int) -> Vector2:
	return Vector2(float(e[1]) + 0.5, float(h - 1 - int(e[0])) + 0.5)


func cell_to_xy(e) -> Vector2:
	return _cell_to_xy_h(e, level.h)


func step(px: float, py: float) -> void:
	just_bolt = false
	just_golden = false
	just_blueprint = false
	just_checkpoint = false
	just_phase = false
	just_raised = false

	var centre := Vector2(px, py + 0.75)     # the kid's middle, not his feet

	for i in bolts_total:
		if _bolt_taken[i]:
			continue
		if centre.distance_to(cell_to_xy(level.bolts[i])) < PICKUP_R + 0.25:
			_bolt_taken[i] = true
			bolts_got += 1
			just_bolt = true

	for i in golden_total:
		if _golden_taken[i]:
			continue
		if centre.distance_to(cell_to_xy(level.golden[i])) < PICKUP_R + 0.35:
			_golden_taken[i] = true
			golden_got += 1
			just_golden = true

	if not blueprint_got and level.blueprint != null:
		if centre.distance_to(cell_to_xy(level.blueprint)) < PICKUP_R + 0.35:
			blueprint_got = true
			just_blueprint = true

	# ---- the checkpoint --------------------------------------------------
	# Mario World's gate. Running past it lights it; dying sends you THERE,
	# not to the start, because a level is 60-90 seconds and losing all of it
	# to one hole is the cost this game promised never to charge.
	if not checkpoint_lit and level.checkpoint != null:
		var cx := float(level.checkpoint.get("x", 0))
		if px > cx:
			checkpoint_lit = true
			checkpoint = Vector2(cx, float(level.checkpoint.get("y", 0)))
			just_checkpoint = true

	_step_flag(px)


## The flag BUILDS ITSELF in three phases as you come up on it and activates
## by being RUN PAST — no button, no stopping (DESIGN §4.2).
func _step_flag(px: float) -> void:
	if level.flag == null:
		return
	var fx := float(level.flag.get("x", 0))
	var d := fx - px
	var want := -1
	for a in PHASE_AT:
		if d <= a:
			want += 1
	if want > flag_phase:
		flag_phase = want
		just_phase = true
	if not flag_raised and flag_phase >= 2 and px > fx:
		flag_raised = true
		just_raised = true
		finished = true


func flag_big() -> bool:
	return level.flag != null and bool(level.flag.get("big", false))


## Where a fall puts him back. The checkpoint if one is lit, else the level's
## own answer — never a number left here by a debugging session.
func respawn_for(x: float) -> Vector2:
	return level.fall_respawn(x, checkpoint)


func bolt_alive(i: int) -> bool:
	return not _bolt_taken[i]


func golden_alive(i: int) -> bool:
	return not _golden_taken[i]
