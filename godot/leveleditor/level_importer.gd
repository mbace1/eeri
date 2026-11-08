class_name EeriLevelImporter
extends RefCounted
## Editable references are built from the generated campaign data. Sources
## remain JS; the scene is a saved draft and preview, never an implicit edit
## to the twelve shipping levels.

func build(slug: String) -> Node3D:
	var level := LevelData.load_slug(slug)
	if level == null:
		return null
	var root := Node3D.new()
	root.name = slug
	root.set_meta("eeri_slug", slug)
	root.set_meta("eeri_name", level.display_name)
	root.set_meta("eeri_index", level.index)
	root.set_meta("eeri_world", level.world_id())
	var grid := GridMap.new()
	grid.name = "Terrain"
	grid.mesh_library = load("res://leveleditor/tiles.meshlib")
	grid.cell_size = Vector3.ONE
	var legend := {}
	for id in grid.mesh_library.get_item_list():
		var label := grid.mesh_library.get_item_name(id)
		legend[label.substr(label.rfind("(") + 1, 1)] = id
	for row in level.h:
		for x in level.w:
			var ch := level.grid[row].substr(x, 1)
			if legend.has(ch):
				grid.set_cell_item(Vector3i(x, level.h - 1 - row, 0), legend[ch])
	root.add_child(grid)
	grid.owner = root
	var entities := Node3D.new()
	entities.name = "Entities"
	root.add_child(entities)
	entities.owner = root
	var kid: Dictionary = level.spawn.get("kid", {})
	_add(entities, EeriKidSpawn.new(), "KidSpawn", _xy(kid))
	if level.flag != null:
		var flag := EeriFlag.new()
		flag.big = bool(level.flag.get("big", false))
		_add(entities, flag, "Flag", _xy(level.flag))
	if level.gate != null:
		_add(entities, EeriGate.new(), "Gate", _xy(level.gate))
	else:
		_add(entities, EeriExit.new(), "Exit", _xy(level.exit_at))
	if level.checkpoint != null:
		_add(entities, EeriCheckpoint.new(), "Checkpoint", _xy(level.checkpoint))
	# One run per row keeps the scene tree readable without changing any bolt.
	var bolt_rows := {}
	for bolt in level.bolts:
		var r := int(bolt[0])
		if not bolt_rows.has(r):
			bolt_rows[r] = []
		bolt_rows[r].append(int(bolt[1]))
	for r in bolt_rows:
		var columns: Array = bolt_rows[r]
		columns.sort()
		var at := 0
		while at < columns.size():
			var end := at
			while end + 1 < columns.size() and columns[end + 1] == columns[end] + 1:
				end += 1
			var run := EeriBoltRun.new()
			run.length = end - at + 1
			_add(entities, run, "Bolts", Vector3(columns[at] + 0.5, level.h - 1 - r + 0.5, 0))
			at = end + 1
	for golden in level.golden:
		_add(entities, EeriGolden.new(), "GoldenBolt", _cell(golden, level.h))
	if level.blueprint != null:
		_add(entities, EeriBlueprint.new(), "Blueprint", _cell(level.blueprint, level.h))
	for spec in level.machines:
		var machine := EeriMachineSpawn.new()
		machine.kind = EeriMachineSpawn.Kind.keys().find(String(spec["type"]).to_upper())
		var spawn: Dictionary = level.spawn.get(spec["type"], {"x": spec["x"], "y": level.ground})
		machine.track_left = float(spec["track"][0]) - float(spawn["x"])
		machine.track_right = float(spec["track"][1]) - float(spawn["x"])
		machine.arm_reach = float(spec.get("arm", 2.6))
		_add(entities, machine, "Machine", _xy(spawn))
	for spec in level.robots:
		var robot := EeriRobot.new()
		robot.kind = EeriRobot.Kind.keys().find(String(spec["kind"]).to_upper())
		robot.span_width = float(spec["c1"]) - float(spec["c0"])
		robot.on_deck = spec.get("cy") != null
		robot.deck_y = float(spec["cy"]) if robot.on_deck else float(level.ground)
		_add(entities, robot, "Robot", Vector3(float(spec["c0"]), robot.deck_y, 0))
	for spec in level.hoists:
		var hoist := EeriHoist.new()
		hoist.span_width = float(spec["c1"]) - float(spec["c0"])
		hoist.cy1 = float(spec["cy1"])
		hoist.period = float(spec["period"])
		_add(entities, hoist, "Hoist", Vector3(float(spec["c0"]), float(spec["cy0"]), 0))
	for spec in level.pits:
		if _is_flood(spec, level.flooded):
			continue
		var pit := EeriPit.new()
		pit.span_width = float(spec["c1"]) - float(spec["c0"])
		pit.back_x = float(spec["backX"])
		_add(entities, pit, "Pit", Vector3(float(spec["c0"]), level.ground, 0))
	for spec in level.water:
		if not bool(spec.get("deep", false)) or _is_flood(spec, level.flooded):
			continue
		var water := EeriWaterRegion.new()
		water.deep = true
		water.span_width = float(spec["c1"]) - float(spec["c0"])
		_add(entities, water, "DeepWater", Vector3(float(spec["c0"]), level.ground - 1, 0))
	if level.flooded != null:
		var trench := EeriFloodedTrench.new()
		trench.span_width = float(level.flooded["c1"]) - float(level.flooded["c0"])
		_add(entities, trench, "FloodedTrench", Vector3(float(level.flooded["c0"]), float(level.flooded["cy"]), 0))
	for spec in level.planks:
		var plank := EeriPlank.new()
		plank.span_width = float(spec["c1"]) - float(spec["c0"])
		_add(entities, plank, "Plank", Vector3(float(spec["c0"]), float(spec["cy0"]), 0))
	for spec in level.hazards:
		_add(entities, EeriHazardVent.new(), "SteamVent", Vector3(float(spec["x"]), level.ground, 0))
	for pair in level.pipes:
		var a := EeriPipeMouth.new()
		var b := EeriPipeMouth.new()
		_add(entities, a, "PipeA", Vector3(float(pair["a"]["c"]), float(pair["a"]["cy"]), 0))
		_add(entities, b, "PipeB", Vector3(float(pair["b"]["c"]), float(pair["b"]["cy"]), 0))
		a.linked_to = NodePath("../" + String(b.name))
		b.linked_to = NodePath("../" + String(a.name))
	if level.girder != null:
		var spec: Dictionary = level.girder
		_add(entities, EeriGirderStack.new(), "GirderStack", Vector3(float(spec["stackX"]), level.ground, 0))
		var gap := EeriGirderGap.new()
		gap.span_width = float(spec["gap"]["c1"]) - float(spec["gap"]["c0"])
		gap.span_length = float(spec["spanLen"])
		_add(entities, gap, "GirderGap", Vector3(float(spec["gap"]["c0"]), float(spec["gap"]["cy"]), 0))
		var seat := EeriGirderSeat.new()
		seat.span_width = float(spec["seat"]["x1"]) - float(spec["seat"]["x0"])
		_add(entities, seat, "GirderSeat", Vector3(float(spec["seat"]["x0"]), level.ground, 0))
	for spec in level.shots:
		var shot := EeriCameraShot.new()
		shot.width = float(spec["x1"]) - float(spec["x0"])
		shot.dolly_z = float(spec["z"])
		shot.height_offset = float(spec.get("y", shot.height_offset))
		shot.lead = float(spec.get("lead", shot.lead))
		shot.floor_y = float(spec.get("floor", shot.floor_y))
		_add(entities, shot, "CameraShot", Vector3(float(spec["x0"]), 0, 0))
	var data := SceneryData.load_data()
	var rows: Array = level.scenery if level.scenery is Array else data.rows_for(level.world_id())
	var base := []
	var base_indices := []
	for row_index in rows.size():
		var row: Dictionary = rows[row_index]
		if row["prop"] == "lamp":
			var lamp := EeriLamp.new()
			lamp.radius = float(row.get("r", 6.0))
			lamp.intensity = float(row.get("i", 1.0))
			lamp.light_colour = Color(String(row.get("colour", "#ffd9a0")))
			lamp.flicker = float(row.get("flicker", 0.0))
			lamp.set_meta("eeri_layer", String(row.get("layer", "play")).to_upper())
			lamp.set_meta("eeri_scenery_index", row_index)
			_add(entities, lamp, "Lamp", Vector3(float(row["x"]), float(row.get("y", 0)), float(row.get("z", -1.2))))
			continue
		if not data.art.has(row["prop"]):
			base.append(row.duplicate(true))
			base_indices.append(row_index)
			continue
		var art := EeriArtCutout.new()
		art.prop_key = String(row["prop"])
		art.art_height = float(row.get("h", data.art[art.prop_key]["h"]))
		art.art_flip = bool(row.get("flip", false))
		art.art_opacity = float(row.get("o", 1.0))
		art.set_meta("eeri_layer", String(row.get("layer", "play")).to_upper())
		art.set_meta("eeri_scenery_index", row_index)
		_add(entities, art, art.prop_key, Vector3(float(row["x"]), float(row.get("y", 0)),
			float(row.get("z", data.z_for(String(row.get("layer", "play")))))))
	root.set_meta("eeri_scenery_base", base)
	root.set_meta("eeri_scenery_base_indices", base_indices)
	root.set_meta("eeri_scenery_source", data.rows_for(level.world_id()).duplicate(true))
	return root


func _add(parent: Node3D, marker: EeriMarker, label: String, at: Vector3) -> void:
	marker.name = label
	marker.position = at
	parent.add_child(marker, true)
	marker.owner = parent.get_parent()


func _xy(point: Dictionary) -> Vector3:
	return Vector3(float(point.get("x", 0)), float(point.get("y", 4)), 0)


func _cell(point: Array, height: int) -> Vector3:
	return Vector3(float(point[1]) + 0.5, height - 1 - float(point[0]) + 0.5, 0)


func _is_flood(point: Dictionary, flooded) -> bool:
	return flooded != null and point["c0"] == flooded["c0"] and point["c1"] == flooded["c1"]
