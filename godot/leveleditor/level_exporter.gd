class_name LevelExporter
extends RefCounted
## THE ACTUAL EXPORT LOGIC: walks a level scene's GridMap + marker children
## and writes the exact JSON LevelData.gd already reads — the same schema
## tools/export-levels.mjs writes from js/rooms.js. New levels authored this
## way and the twelve existing ones (still generated from the JS source, per
## the owner's direction that Godot is the future but nothing already proven
## gets rewritten for its own sake) end up in the identical format, so
## nothing downstream — LevelData, the play scene, any of the 233 gate
## checks — needs to know or care which a given level came from.
##
## Kept OUT of export_level.gd (the EditorScript "Run" button) on purpose:
## `EditorScript` can only be instantiated by the editor itself — Godot
## refuses even a `.new()` from a plain script — so any logic living there
## is untestable outside a human clicking Run. A plain RefCounted has no
## such restriction: this file is what a headless test/gate script calls
## directly, and export_level.gd is a two-line wrapper around it.

const OUT_DIR := "res://data/levels/"
## World and ground line, from js/parts.js. A hand-authored level uses the
## same fixed canvas the compiler does, so REACH's numbers (js/kid.js) still
## mean the same thing — a proved jump does not change size between rooms.
const W := 96
const H := 18
const GROUND := 4


## Writes <root>'s level JSON to disk and returns {"path", "out", "problems"},
## or {} if the scene is not a valid level (no usable slug, or no GridMap).
func export_scene(root: Node) -> Dictionary:
	var slug: String = root.get_meta("eeri_slug", "") if root.has_meta("eeri_slug") \
		else root.name.to_lower().replace(" ", "-")
	if not slug.begins_with("eeri-"):
		push_error("Scene root needs an 'eeri_slug' metadata (Node > Add Metadata) " +
			"or a name like 'eeri-5-1' -- got root name '%s'." % root.name)
		return {}

	var grid_map: GridMap = _find_grid_map(root)
	if grid_map == null:
		push_error("No GridMap found in the scene -- nothing to export as terrain.")
		return {}

	var legend := _load_legend()
	var grid := _export_grid(grid_map, legend)

	var out := {
		"index": -1,   # a hand-authored level has no fixed roster position yet
		"slug": slug,
		"name": String(root.get_meta("eeri_name", slug.to_upper())),
		"idea": null,
		"w": W, "h": H, "ground": GROUND,
		"grid": grid,
		"spawn": {}, "exit": {}, "checkpoint": null, "flag": null,
		"bolts": [], "golden": [], "blueprint": null,
		"pits": [], "ladders": [],
		"belts": [], "tarps": [], "water": [], "pipes": [], "hoists": [],
		"robots": [], "hazards": [], "machines": [], "obstacles": [],
		"shots": [], "bank": null, "wall": null, "girder": null,
		"finish": null, "gate": null,
	}

	var markers := _collect(root)
	_fill_from_markers(out, markers, grid_map, legend)

	var problems := _validate(out)

	var path := OUT_DIR + slug + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write " + path)
		return {}
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	return {"path": path, "out": out, "problems": problems}


# ---- the grid --------------------------------------------------------------

func _load_legend() -> Dictionary:
	# item name -> character, e.g. "earth  (#)" -> "#". Kept in sync with
	# leveleditor/build_meshlib.gd by construction: both read the same
	# TILES table shape, and this just reverses the name it wrote.
	var lib := load("res://leveleditor/tiles.meshlib") as MeshLibrary
	var legend := {}
	for id in lib.get_item_list():
		var item_name: String = lib.get_item_name(id)
		var ch := item_name.substr(item_name.rfind("(") + 1, 1)
		legend[id] = ch
	return legend


func _find_grid_map(n: Node) -> GridMap:
	if n is GridMap:
		return n
	for c in n.get_children():
		var f := _find_grid_map(c)
		if f != null:
			return f
	return null


## GridMap cell (x, y, 0) -> grid[row] character, row 0 = TOP — the same
## storage js/level.js and LevelData.gd both use. GridMap's own y axis
## already matches world y (up), so only the top-down FLIP needs doing here;
## LevelData does the same flip once, in cell(), never twice.
func _export_grid(gm: GridMap, legend: Dictionary) -> Array:
	var rows: Array = []
	rows.resize(H)
	for r in H:
		rows[r] = " ".repeat(W)
	var used := gm.get_used_cells()
	for cell in used:
		var c: int = cell.x
		var y: int = cell.y
		if c < 0 or c >= W or y < 0 or y >= H:
			continue
		var item := gm.get_cell_item(cell)
		var ch: String = legend.get(item, "#")
		var row := H - 1 - y
		var line: String = rows[row]
		rows[row] = line.substr(0, c) + ch + line.substr(c + 1)
	return rows


# ---- markers ----------------------------------------------------------------

func _collect(n: Node, out: Array = []) -> Array:
	if n is EeriMarker:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
	return out


func _fill_from_markers(out: Dictionary, markers: Array, gm: GridMap, legend: Dictionary) -> void:
	var bolts: Array = []
	var golden: Array = []
	var robots: Array = []
	var hoists: Array = []
	var pits: Array = []
	var water: Array = []
	var pipe_mouths: Array = []
	var shots: Array = []
	var girder_stack = null
	var girder_gap = null
	var girder_seat = null

	for m in markers:
		if m is EeriKidSpawn:
			out["spawn"]["kid"] = _xy(m)
		elif m is EeriMachineSpawn:
			out["spawn"][m.kind_string()] = _xy(m)
			out["machines"].append({"type": m.kind_string(), "x": m.position.x,
				"track": [m.position.x - 6, m.position.x + 6], "verbs": [], "arm": 2.6})
		elif m is EeriExit:
			out["exit"] = _xy(m)
		elif m is EeriBolt:
			bolts.append(_row_col(m))
		elif m is EeriBoltRun:
			var x: float = m.position.x
			while x < m.position.x + m.length:
				bolts.append(_row_col_at(x, m.position.y))
				x += 1.0
		elif m is EeriGolden:
			golden.append(_row_col(m))
		elif m is EeriBlueprint:
			out["blueprint"] = _row_col(m)
		elif m is EeriCheckpoint:
			out["checkpoint"] = _xy(m)
		elif m is EeriFlag:
			out["exit"] = _xy(m) if out["exit"].is_empty() else out["exit"]
			out["flag"] = {"x": m.position.x, "y": m.position.y, "big": m.big}
		elif m is EeriHazardVent:
			out["hazards"].append({"x": m.position.x, "type": "steam"})
		elif m is EeriRobot:
			var r := {"c0": m.c0(), "c1": m.c1(), "kind": m.kind_string()}
			if m.on_deck:
				r["cy"] = m.deck_y
			robots.append(r)
		elif m is EeriHoist:
			hoists.append({"c0": m.c0(), "c1": m.c1(), "cy0": m.position.y,
				"cy1": m.cy1, "period": m.period})
		elif m is EeriPit:
			pits.append({"c0": m.c0(), "c1": m.c1(), "backX": m.back_x})
		elif m is EeriWaterRegion:
			# DEEP water only, from a marker — shallow is derived straight from
			# painted '~' tiles below, matching the JSON's own asymmetry (a
			# shallow entry never carries "respawns"; a deep one always does).
			if m.deep:
				water.append({"c0": m.c0(), "c1": m.c1(), "deep": true, "respawns": true})
		elif m is EeriPipeMouth:
			pipe_mouths.append(m)
		elif m is EeriCameraShot:
			# EeriCameraShot extends EeriMarker (a POINT), not EeriSpanMarker —
			# it carries `width` directly rather than a c0()/c1() pair, so x1
			# is computed here instead of borrowed from the span base.
			shots.append({"x0": m.position.x, "x1": m.position.x + m.width,
				"z": m.dolly_z, "y": m.height_offset, "lead": m.lead,
				"floor": m.floor_y})
		elif m is EeriGirderStack:
			girder_stack = m
		elif m is EeriGirderGap:
			girder_gap = m
		elif m is EeriGirderSeat:
			girder_seat = m

	# Pipe mouths are collected once per PAIR — walk only the ones that link
	# forward, so an A<->B pair is not written twice.
	var seen := {}
	for m in pipe_mouths:
		if seen.has(m):
			continue
		if m.linked_to.is_empty():
			push_warning("EeriPipeMouth '%s' has no linked_to — skipped" % m.name)
			continue
		var other: Node = m.get_node_or_null(m.linked_to)
		if other == null or not (other is EeriPipeMouth):
			push_warning("EeriPipeMouth '%s' linked_to does not resolve — skipped" % m.name)
			continue
		out["pipes"].append({"a": _pipe_pt(m), "b": _pipe_pt(other)})
		seen[m] = true
		seen[other] = true

	if girder_stack != null and girder_gap != null and girder_seat != null:
		out["girder"] = {
			"stackX": girder_stack.position.x,
			"gap": {"c0": girder_gap.c0(), "c1": girder_gap.c1(), "cy": girder_gap.position.y},
			"seat": {"x0": girder_seat.c0(), "x1": girder_seat.c1()},
			"spanLen": girder_gap.span_width,
		}
	elif girder_stack != null or girder_gap != null or girder_seat != null:
		push_warning("Girder needs all three of EeriGirderStack/Gap/Seat — found only some.")

	# bank / wall are DERIVED from the grid, never authored separately — the
	# rect the level designer painted with the 'B' or 'K' tile IS the bank or
	# wall, so there is no second place to keep its extent in step with.
	out["bank"] = _derive_rect(gm, legend, "B", "bank")
	out["wall"] = _derive_rect(gm, legend, "K", "wall")
	out["ladders"] = _derive_ladders(gm, legend)

	# Belts, tarps and shallow water are likewise DERIVED straight off the
	# painted 'C'/'c'/'T'/'~' tiles rather than authored twice — the physics
	# (LevelData.belt_at/tarp_at/water_at) already reads only the grid
	# character, so a second, hand-kept list would be a second source of
	# truth for exactly the thing the grid already says.
	out["belts"] = _derive_row_runs(gm, legend, "C", {"dir": 1}) \
		+ _derive_row_runs(gm, legend, "c", {"dir": -1})
	out["tarps"] = _derive_row_runs(gm, legend, "T", {})
	out["water"] = _derive_row_runs(gm, legend, "~", {"deep": false}) + water

	out["bolts"] = bolts
	out["golden"] = golden
	out["robots"] = robots
	out["hoists"] = hoists
	out["pits"] = pits
	out["shots"] = shots


func _xy(m: EeriMarker) -> Dictionary:
	return {"x": m.position.x, "y": m.position.y}


## [row, col] — GRID ROW, top-down, the same flip js/level.js does for every
## collectible. Getting this backwards hangs every bolt in the sky in
## mirror-image rows; it happened once already in this port.
func _row_col(m: EeriMarker) -> Array:
	return _row_col_at(m.position.x, m.position.y)


func _row_col_at(x: float, y: float) -> Array:
	var col := int(floor(x))
	var row := H - 1 - int(floor(y))
	return [row, col]


func _pipe_pt(m: EeriPipeMouth) -> Dictionary:
	return {"c": m.position.x, "cy": m.position.y}


## Scan the GridMap for cells of `ch` and return the bounding rect + row
## count, or null if none are painted. A level with no bank/wall correctly
## exports null, matching js/parts.js compile() for a room with neither.
func _derive_rect(gm: GridMap, legend: Dictionary, ch: String, label: String):
	var id := -1
	for k in legend.keys():
		if legend[k] == ch:
			id = k
			break
	if id == -1:
		return null
	var min_c := INF
	var max_c := -INF
	var min_y := INF
	var max_y := -INF
	var found := false
	for cell in gm.get_used_cells_by_item(id):
		found = true
		min_c = minf(min_c, cell.x)
		max_c = maxf(max_c, cell.x)
		min_y = minf(min_y, cell.y)
		max_y = maxf(max_y, cell.y)
	if not found:
		return null
	return {"type": label, "c0": min_c, "c1": max_c, "cy0": min_y,
		"rows": int(max_y - min_y) + 1}


## A ladder is a vertical run of 'H' in ONE column. Scans column by column so
## two separate ladders never merge into one run.
func _derive_ladders(gm: GridMap, legend: Dictionary) -> Array:
	var id := -1
	for k in legend.keys():
		if legend[k] == "H":
			id = k
			break
	if id == -1:
		return []
	var by_col := {}
	for cell in gm.get_used_cells_by_item(id):
		var col: int = cell.x
		if not by_col.has(col):
			by_col[col] = []
		by_col[col].append(cell.y)
	var out := []
	for col in by_col.keys():
		var ys: Array = by_col[col]
		ys.sort()
		out.append({"c": col, "cy0": ys[0], "cy1": ys[ys.size() - 1]})
	return out


## Contiguous horizontal runs of one tile character, one run per (row, unbroken
## span) — the same shape bank/wall use, just width-only instead of a full
## rect, since belts/tarps/shallow-water have no row COUNT the way a dug bank
## does (they are one tile thick by definition). `extra` fields (e.g. a
## belt's "dir") are merged into every run this returns.
func _derive_row_runs(gm: GridMap, legend: Dictionary, ch: String, extra: Dictionary) -> Array:
	var id := -1
	for k in legend.keys():
		if legend[k] == ch:
			id = k
			break
	if id == -1:
		return []
	var by_row := {}
	for cell in gm.get_used_cells_by_item(id):
		var y: int = cell.y
		if not by_row.has(y):
			by_row[y] = []
		by_row[y].append(int(cell.x))
	var out := []
	for y in by_row.keys():
		var xs: Array = by_row[y]
		xs.sort()
		var run_start = xs[0]
		var prev = xs[0]
		for i in range(1, xs.size() + 1):
			var at_end := i == xs.size()
			var x = xs[i] if not at_end else null
			if at_end or x != prev + 1:
				var entry := {"c0": run_start, "c1": prev, "cy": y}
				for k in extra.keys():
					entry[k] = extra[k]
				out.append(entry)
				if not at_end:
					run_start = x
			if not at_end:
				prev = x
	return out


# ---- sanity, before writing a level nothing can finish ----------------------

func _validate(out: Dictionary) -> Array:
	var problems: Array = []
	if not out["spawn"].has("kid"):
		problems.append("no EeriKidSpawn — the level has nowhere to start")
	if out["exit"].is_empty():
		problems.append("no EeriExit or EeriFlag — the level has no end")
	if out["flag"] == null:
		problems.append("no EeriFlag — the level can never be marked finished")
	if out["machines"].size() > 0 and not out["spawn"].has(out["machines"][0]["type"]):
		problems.append("a machine is declared but has no matching spawn marker")
	return problems
