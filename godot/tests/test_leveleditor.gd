extends Node
## The Godot-native level editor (leveleditor/) — proves the whole authoring
## pipeline the owner asked for on 2026-08-24 actually round-trips: paint
## terrain with a GridMap, drop marker prefabs, export, and get back a
## LevelData that plays exactly like a hand-authored level should.
##
## Deliberately does NOT touch export_level.gd (the EditorScript "Run"
## button) — Godot refuses to instantiate an EditorScript outside the editor
## itself, so this gate calls LevelExporter (the plain RefCounted the button
## wraps) directly, the same way a headless CI run has to.
##
## Run: godot --headless --path godot res://tests/test_leveleditor.tscn
const EXPECTED := 72
var _pass := 0
var _fail := 0

const TMP_SLUG := "eeri-e2e-gate-test"
const TMP_SCENE := "res://leveleditor/_gate_test_level.tscn"
const TMP_JSON := "res://data/levels/" + TMP_SLUG + ".json"


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("LEVELEDITOR FAIL: timed out"); get_tree().quit(1))
	add_child(bail); bail.start()

	print("── Eeri — the level editor ──")

	# --- the built palette and prefabs exist and match the legend ---------
	print("  -- built artifacts --")
	var lib := load("res://leveleditor/tiles.meshlib") as MeshLibrary
	check("tiles.meshlib exists and loads", lib != null)
	if lib != null:
		check("it has one item per legend character (10)", lib.get_item_list().size() == 10,
			"got %d" % lib.get_item_list().size())
	var kid_prefab := load("res://leveleditor/markers/eeri_kid_spawn.tscn")
	check("a marker prefab (kid spawn) exists and loads", kid_prefab != null)
	var template := load("res://leveleditor/level_template.tscn")
	check("level_template.tscn exists and loads", template != null)

	# --- the layer slider's data, not a fake range -------------------------
	# Names and z are scenery.json layerZ (Godot's copy). The diorama's
	# committed rects must agree, so a missing scenery file cannot invent a
	# different stack. The dock's main control is the HSlider that selects one.
	print("  -- layer rail --")
	await _check_layer_rail()

	# --- build a tiny hand-authored level in code, exactly as a level ------
	# --- author would in the viewport: paint tiles, drop marker prefabs. ---
	var root := _build_test_level()

	var result: Dictionary = LevelExporter.new().export_scene(root)
	check("export_scene() succeeds on a minimal valid level", not result.is_empty())
	if result.is_empty():
		root.queue_free(); _finish(); return
	check("a complete level reports no problems", (result["problems"] as Array).is_empty(),
		str(result["problems"]))

	var d := LevelData.load_slug(TMP_SLUG)
	check("LevelData loads the exported JSON back", d != null)
	if d == null:
		root.queue_free(); _cleanup(); _finish(); return

	# --- spawn round-trips ------------------------------------------------
	print("  -- round trip --")
	check("kid spawn position round-trips", d.spawn.has("kid")
		and absf(float(d.spawn["kid"]["x"]) - 1.5) < 0.001)

	# --- painted earth is solid --------------------------------------------
	check("a painted earth tile is solid collision", d.solid_cell(5, 3))

	# --- painted belt carries the right direction, and the row/col flip is
	# --- the right way round (this exact flip has been a real bug before) -
	check("a painted right-belt reads as carrying right", d.belt_at(10.5, 4.05) == 1)

	# --- painted ladder is climbable ---------------------------------------
	check("a painted ladder column is climbable", d.climbable(16.0, 4.0))

	# --- a bolt marker's [row, col] is the same top-down flip js/level.js --
	# --- does for every collectible ----------------------------------------
	check("a bolt marker exports the correct [row, col]",
		d.bolts.size() == 1 and d.bolts[0][0] == 12 and d.bolts[0][1] == 5,
		str(d.bolts))

	# --- exit / flag --------------------------------------------------------
	check("an EeriExit marker produces a non-empty exit", not d.exit_at.is_empty())
	check("an EeriFlag marker produces a flag", d.flag != null)

	# --- a level missing required markers is reported, not silently wrong -
	print("  -- validation catches an incomplete level --")
	var bare := Node3D.new()
	bare.name = "eeri-bare-gate-test"
	var gm2 := GridMap.new()
	gm2.mesh_library = lib
	bare.add_child(gm2)
	var incomplete: Dictionary = LevelExporter.new().export_scene(bare)
	check("a level with no spawn/exit/flag reports problems, not a crash",
		not incomplete.is_empty() and (incomplete["problems"] as Array).size() >= 3,
		str(incomplete.get("problems", "<empty result>")))
	bare.queue_free()
	if FileAccess.file_exists("res://data/levels/eeri-bare-gate-test.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			"res://data/levels/eeri-bare-gate-test.json"))

	root.queue_free()
	_cleanup()
	_finish()


## Paints a tiny terrain strip and drops one of each marker this test cares
## about — the same actions a level author does by hand in the viewport,
## just performed in code so the gate needs no editor session to run.
func _build_test_level() -> Node3D:
	var root := Node3D.new()
	root.name = TMP_SLUG
	root.set_meta("eeri_slug", TMP_SLUG)
	root.set_meta("eeri_name", "GATE TEST")

	var gm := GridMap.new()
	gm.mesh_library = load("res://leveleditor/tiles.meshlib")
	var earth := -1
	var belt := -1
	var ladder := -1
	for id in gm.mesh_library.get_item_list():
		var n: String = gm.mesh_library.get_item_name(id)
		if n.ends_with("(#)"): earth = id
		if n.ends_with("(C)"): belt = id
		if n.ends_with("(H)"): ladder = id
	for x in range(0, 20):
		gm.set_cell_item(Vector3i(x, 3, 0), earth)
	for x in range(10, 14):
		gm.set_cell_item(Vector3i(x, 4, 0), belt)
	for y in range(4, 7):
		gm.set_cell_item(Vector3i(16, y, 0), ladder)
	root.add_child(gm)

	var entities := Node3D.new()
	entities.name = "Entities"
	root.add_child(entities)

	var kid = preload("res://leveleditor/markers/eeri_kid_spawn.tscn").instantiate()
	kid.position = Vector3(1.5, 4, 0)
	entities.add_child(kid)

	var exit = preload("res://leveleditor/markers/eeri_exit.tscn").instantiate()
	exit.position = Vector3(18, 4, 0)
	entities.add_child(exit)

	var flag = preload("res://leveleditor/markers/eeri_flag.tscn").instantiate()
	flag.position = Vector3(18.5, 4, 0)
	entities.add_child(flag)

	var bolt = preload("res://leveleditor/markers/eeri_bolt.tscn").instantiate()
	bolt.position = Vector3(5, 5, 0)
	entities.add_child(bolt)

	return root



func _check_layer_rail() -> void:
	var rail := EeriLayerRail.layers()
	var by_name := {}
	var ordered := true
	var prev := -1e9
	for item in rail:
		var z := float(item["z"])
		if z < prev:
			ordered = false
		prev = z
		by_name[String(item["name"])] = z
	var scenery := SceneryData.load_data()
	var same := scenery.layer_z.size() == by_name.size() and ordered
	for key in scenery.layer_z.keys():
		if not by_name.has(String(key)):
			same = false
		elif absf(by_name[String(key)] - float(scenery.layer_z[key])) > 0.001:
			same = false
	check("layer names and z are scenery.json layerZ, back to front", same,
		str(rail))

	var diorama_ok := true
	for lane in Diorama.ORDER:
		var want := float(Diorama.RECTS[lane]["z"])
		var got = by_name.get(String(lane).to_upper(), null)
		if got == null or absf(float(got) - want) > 0.001:
			diorama_ok = false
	check("those z values match the diorama lanes already in Godot", diorama_ok)

	var kid = preload("res://leveleditor/markers/eeri_kid_spawn.tscn").instantiate()
	kid.position = Vector3(1.26, 4.2, 9.0)
	EeriLayerRail.place(kid, EeriLayerRail.index_of("NEAR"))
	check("a marker placed on NEAR snaps onto that layer",
		is_equal_approx(kid.position.x, 1.5)
		and is_equal_approx(kid.position.y, 4.0)
		and is_equal_approx(kid.position.z, float(by_name["NEAR"]))
		and String(kid.get_meta("eeri_layer", "")) == "NEAR",
		str(kid.position))
	EeriLayerRail.place(kid, EeriLayerRail.index_of("PLAY"))
	check("a marker placed on PLAY stays on the play plane (z = 0)",
		is_equal_approx(kid.position.z, 0.0)
		and String(kid.get_meta("eeri_layer", "")) == "PLAY"
		and is_equal_approx(kid.position.x, 1.5))
	kid.free()

	var dock := preload("res://leveleditor/editor_dock.gd").new()
	add_child(dock)
	var slider := dock.find_child("LayerSlider", true, false) as HSlider
	check("the dock's main control is an HSlider over the layer list",
		slider != null and slider.max_value == EeriLayerRail.layer_count() - 1
		and absf(slider.step - 1.0) < 0.001)
	dock.set_layer_index(EeriLayerRail.index_of("NEAR"))
	check("the slider selects the NEAR layer", dock.selected_layer_name() == "NEAR")
	dock.queue_free()

	var plain := Node3D.new()
	var bolt = preload("res://leveleditor/markers/eeri_bolt.tscn").instantiate()
	check("only marker prefabs take a layer",
		EeriLayerRail.is_marker(bolt) and not EeriLayerRail.is_marker(plain))
	bolt.free()
	plain.free()

	# Drop-snap is `place`. What was missing is a later move: x/y join the
	# same half-tile grid, z stays on the layer the drop chose. FORE is 2.2,
	# so a mistaken z-snap would land on 2.0 and fail this check. Pipe mouth
	# is an existing marker prefab, not a new prop.
	var pipe = preload("res://leveleditor/markers/eeri_pipe_mouth.tscn").instantiate()
	pipe.position = Vector3(3.2, 1.1, 0)
	EeriLayerRail.place(pipe, EeriLayerRail.index_of("FORE"))
	var fore_z: float = pipe.position.z
	# A pose saved off the grid must survive entering the tree. Snap starts
	# on the next moves, not on open. Two frames: the arm is deferred, and
	# that deferred call can land after the first process_frame.
	pipe.position = Vector3(3.2, 1.1, fore_z)
	add_child(pipe)
	await get_tree().process_frame
	await get_tree().process_frame
	check("opening a level does not re-snap a marker already placed",
		is_equal_approx(pipe.position.x, 3.2)
		and is_equal_approx(pipe.position.y, 1.1)
		and is_equal_approx(pipe.position.z, fore_z),
		str(pipe.position))
	pipe.position = Vector3(3.4, 1.4, fore_z)
	check("dragging a placed marker snaps x/y and stays on its layer",
		is_equal_approx(pipe.position.x, 3.5)
		and is_equal_approx(pipe.position.y, 1.5)
		and is_equal_approx(pipe.position.z, fore_z)
		and absf(fore_z - 2.2) < 0.001
		and String(pipe.get_meta("eeri_layer", "")) == "FORE",
		str(pipe.position))
	pipe.free()

	# treeSpruce is already a scenery.json prop, and mount_art already
	# draws its cutout. The prefab is an EeriMarker, so placing it is the
	# same call a drop makes. FAR is not the prop's own lane (near): the
	# slider is what chooses the layer. A later move snaps x/y only.
	var spruce = preload("res://leveleditor/markers/eeri_tree_spruce.tscn").instantiate()
	spruce.position = Vector3(6.26, 3.74, 1.0)
	var spruce_dock := preload("res://leveleditor/editor_dock.gd").new()
	add_child(spruce_dock)
	spruce_dock.set_layer_index(EeriLayerRail.index_of("FAR"))
	EeriLayerRail.place(spruce, spruce_dock.selected_index())
	var far_z: float = float(by_name["FAR"])
	check("placing the spruce on the selected layer snaps z and x/y",
		spruce_dock.selected_layer_name() == "FAR"
		and String(spruce.get_meta("eeri_prop", "")) == "treeSpruce"
		and is_equal_approx(spruce.position.x, 6.5)
		and is_equal_approx(spruce.position.y, 3.5)
		and is_equal_approx(spruce.position.z, far_z)
		and absf(far_z - (-14.0)) < 0.001
		and String(spruce.get_meta("eeri_layer", "")) == "FAR",
		str(spruce.position))
	spruce_dock.queue_free()
	add_child(spruce)
	await get_tree().process_frame
	await get_tree().process_frame
	var cut := spruce.get_node_or_null("Cutout") as MeshInstance3D
	var art_path := ""
	if cut != null and cut.material_override is StandardMaterial3D:
		var tex := (cut.material_override as StandardMaterial3D).albedo_texture
		if tex != null:
			art_path = tex.resource_path
	check("the spruce cutout is the art scenery.json already mounts",
		art_path.ends_with("2d/world3_tree_spruce_v1.webp"),
		art_path)
	spruce.position = Vector3(6.8, 3.2, far_z)
	check("dragging the spruce snaps x/y and stays on its layer",
		is_equal_approx(spruce.position.x, 7.0)
		and is_equal_approx(spruce.position.y, 3.0)
		and is_equal_approx(spruce.position.z, far_z)
		and String(spruce.get_meta("eeri_layer", "")) == "FAR",
		str(spruce.position))
	spruce.free()

	# treeOak and treeBirch are the next scenery.json rows whose cutouts
	# mount_art already mounts (2d/world3_tree_oak_v1.webp and
	# world3_tree_birch_v1.webp). Same drop and drag as the spruce: the
	# slider's layer, not the prop's own lane (near).
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_tree_oak.tscn",
		"treeOak", "2d/world3_tree_oak_v1.webp", "oak", "MID",
		Vector3(4.26, 2.74, 1.0), Vector3(4.5, 2.5, -6.0),
		Vector3(4.8, 2.2, -6.0), Vector3(5.0, 2.0, -6.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_tree_birch.tscn",
		"treeBirch", "2d/world3_tree_birch_v1.webp", "birch", "SKYLINE",
		Vector3(8.74, 5.26, 0.0), Vector3(8.5, 5.5, -30.0),
		Vector3(8.2, 5.8, -30.0), Vector3(8.0, 6.0, -30.0))

	# Keyed cutouts whose texture files already import. Log tunnel and stump
	# clearing are named in scenery.json, but Godot's importer marks those
	# files valid=false, so they are not mounted. Same drop and drag as the
	# trees: the slider's layer, not the prop's own lane.
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_dock_bay.tscn",
		"dockBay", "2d/world4_dock_bay_v1.webp", "dock bay", "NEAR",
		Vector3(11.26, 6.74, 0.0), Vector3(11.5, 6.5, -2.0),
		Vector3(11.8, 6.2, -2.0), Vector3(12.0, 6.0, -2.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_office.tscn",
		"office", "2d/world4_office_v1.webp", "site office", "SKY",
		Vector3(13.74, 7.26, 0.0), Vector3(13.5, 7.5, -48.0),
		Vector3(13.2, 7.8, -48.0), Vector3(13.0, 8.0, -48.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_cargo.tscn",
		"cargo", "2d/world4_cargo_v1.webp", "cargo stack", "FORE",
		Vector3(15.26, 2.74, 0.0), Vector3(15.5, 2.5, 2.2),
		Vector3(15.8, 2.2, 2.2), Vector3(16.0, 2.0, 2.2))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_worklamp.tscn",
		"worklamp", "2d/world4_worklamp_lib_v1.webp", "work lamp", "SKYLINE",
		Vector3(17.26, 8.74, 0.0), Vector3(17.5, 8.5, -30.0),
		Vector3(17.8, 8.2, -30.0), Vector3(18.0, 8.0, -30.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_cable_reel.tscn",
		"cableReel", "2d/world4_cable_reel_lib_v1.webp", "cable reel", "FAR",
		Vector3(19.74, 0.26, 0.0), Vector3(19.5, 0.5, -14.0),
		Vector3(19.2, 0.8, -14.0), Vector3(19.0, 1.0, -14.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_barrier_lamps.tscn",
		"barrierLamps", "2d/world4_barrier_lamps_lib_v1.webp", "lit barrier", "MID",
		Vector3(21.26, 3.26, 1.0), Vector3(21.5, 3.5, -6.0),
		Vector3(21.8, 3.8, -6.0), Vector3(22.0, 4.0, -6.0))

	# Buried finds. The PNGs are already in the repo and Godot imports them.
	# Gameplay markers stay the prefabs they already are. Same drop and drag.
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_root.tscn",
		"fRoot", "2d/f_root_v1.png", "root", "NEAR",
		Vector3(23.26, 4.74, 0.0), Vector3(23.5, 4.5, -2.0),
		Vector3(23.8, 4.2, -2.0), Vector3(24.0, 4.0, -2.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_pipe.tscn",
		"fPipe", "2d/f_pipe_v1.png", "buried pipe", "FAR",
		Vector3(25.74, 1.26, 0.0), Vector3(25.5, 1.5, -14.0),
		Vector3(25.2, 1.8, -14.0), Vector3(25.0, 2.0, -14.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_drum.tscn",
		"fDrum", "2d/f_drum_v1.png", "buried drum", "MID",
		Vector3(27.26, 2.74, 1.0), Vector3(27.5, 2.5, -6.0),
		Vector3(27.8, 2.2, -6.0), Vector3(28.0, 2.0, -6.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_brick.tscn",
		"fBrick", "2d/f_brick_v1.png", "brickwork", "SKY",
		Vector3(29.74, 6.26, 0.0), Vector3(29.5, 6.5, -48.0),
		Vector3(29.2, 6.8, -48.0), Vector3(29.0, 7.0, -48.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_stones.tscn",
		"fStones", "2d/f_stones_v1.png", "stones", "SKYLINE",
		Vector3(31.26, 8.74, 0.0), Vector3(31.5, 8.5, -30.0),
		Vector3(31.8, 8.2, -30.0), Vector3(32.0, 8.0, -30.0))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_stone.tscn",
		"fStone", "2d/f_stone_v1.png", "stone", "FORE",
		Vector3(33.74, 0.26, 0.0), Vector3(33.5, 0.5, 2.2),
		Vector3(33.2, 0.8, 2.2), Vector3(33.0, 1.0, 2.2))
	await _check_scenery_piece(
		"res://leveleditor/markers/eeri_f_bottle.tscn",
		"fBottle", "2d/f_bottle_v1.png", "bottle", "NEAR",
		Vector3(35.26, 5.26, 0.0), Vector3(35.5, 5.5, -2.0),
		Vector3(35.8, 5.8, -2.0), Vector3(36.0, 6.0, -2.0))




func _check_scenery_piece(scene_path: String, prop: String, art_suffix: String, label: String, layer_name: String, drop: Vector3, placed: Vector3, drag: Vector3, dragged: Vector3) -> void:
	var piece = load(scene_path).instantiate()
	piece.position = drop
	var dock := preload("res://leveleditor/editor_dock.gd").new()
	add_child(dock)
	dock.set_layer_index(EeriLayerRail.index_of(layer_name))
	EeriLayerRail.place(piece, dock.selected_index())
	check("placing the %s on the selected layer snaps z and x/y" % label,
		dock.selected_layer_name() == layer_name
		and String(piece.get_meta("eeri_prop", "")) == prop
		and is_equal_approx(piece.position.x, placed.x)
		and is_equal_approx(piece.position.y, placed.y)
		and is_equal_approx(piece.position.z, placed.z)
		and String(piece.get_meta("eeri_layer", "")) == layer_name,
		str(piece.position))
	dock.queue_free()
	add_child(piece)
	await get_tree().process_frame
	await get_tree().process_frame
	var cut := piece.get_node_or_null("Cutout") as MeshInstance3D
	var art_path := ""
	if cut != null and cut.material_override is StandardMaterial3D:
		var tex := (cut.material_override as StandardMaterial3D).albedo_texture
		if tex != null:
			art_path = tex.resource_path
	check("the %s cutout is the art scenery.json already mounts" % label,
		art_path.ends_with(art_suffix),
		art_path)
	piece.position = drag
	check("dragging the %s snaps x/y and stays on its layer" % label,
		is_equal_approx(piece.position.x, dragged.x)
		and is_equal_approx(piece.position.y, dragged.y)
		and is_equal_approx(piece.position.z, dragged.z)
		and String(piece.get_meta("eeri_layer", "")) == layer_name,
		str(piece.position))
	piece.free()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP_JSON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_JSON))


func _finish() -> void:
	var ran := _pass + _fail
	if ran != EXPECTED:
		_fail += 1
		print("  FAIL - %d checks ran, expected %d" % [ran, EXPECTED])
	print("")
	print("%d passed, %d failed" % [_pass, _fail])
	if _fail > 0: get_tree().quit(1)
	else:
		print("ALL GREEN"); get_tree().quit(0)


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1; print("  ok  - %s" % label)
	else:
		_fail += 1; print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
