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
const EXPECTED := 15
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
