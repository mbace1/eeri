extends Node
## Saved editor art must survive scene reload, JSON export, and the runtime
## renderer. This catches the old success-with-no-scenery export failure.
var passed := 0
var failed := 0
const SLUG := "eeri-art-gate-test"
const SCENE := "res://leveleditor/_gate_art.tscn"


func check(label: String, condition: bool) -> void:
	print("  %s - %s" % ["ok" if condition else "FAIL", label])
	if condition:
		passed += 1
	else:
		failed += 1


func _ready() -> void:
	var root := Node3D.new()
	root.name = "SavedArt"
	root.set_meta("eeri_slug", SLUG)
	root.set_meta("eeri_world", "grove")
	root.set_meta("eeri_scenery_base", [{"prop": "lamp", "x": 2.0, "y": 4.0}])
	add_child(root)
	var terrain := GridMap.new()
	terrain.name = "Terrain"
	terrain.mesh_library = load("res://leveleditor/tiles.meshlib")
	root.add_child(terrain)
	terrain.owner = root
	var spawn := EeriKidSpawn.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(1.5, 4, 0)
	root.add_child(spawn)
	spawn.owner = root
	var flag := EeriFlag.new()
	flag.name = "Flag"
	flag.position = Vector3(20, 4, 0)
	root.add_child(flag)
	flag.owner = root
	var tree := EeriTreeSpruce.new()
	tree.name = "Tree"
	root.add_child(tree)
	tree.owner = root
	EeriLayerRail.place(tree, EeriLayerRail.index_of("FAR"))
	tree.position.x = 7.0
	tree.position.y = 4.0
	tree.art_height = 3.2
	tree.art_flip = true
	tree.art_opacity = 0.42
	await get_tree().process_frame
	var packed := PackedScene.new()
	check("the authored scene packs", packed.pack(root) == OK)
	check("the authored scene saves", ResourceSaver.save(packed, SCENE) == OK)
	root.queue_free()
	await get_tree().process_frame
	var reopened := load(SCENE).instantiate() as Node3D
	add_child(reopened)
	await get_tree().process_frame
	var saved := reopened.get_node("Tree") as EeriArtCutout
	check("height, flip and opacity survive scene reload", is_equal_approx(saved.art_height, 3.2)
		and saved.art_flip and is_equal_approx(saved.art_opacity, 0.42))
	check("the chosen scenery layer survives scene reload", saved.get_meta("eeri_layer") == "FAR"
		and is_equal_approx(saved.position.z, float(EeriLayerRail.layer_at(EeriLayerRail.index_of("FAR"))["z"])))
	var result := LevelExporter.new().export_scene(reopened)
	check("the saved scene exports without problems", result.get("written", false))
	var level := LevelData.load_slug(SLUG)
	check("unmodified procedural rows survive the art edit", level.scenery.size() == 2
		and level.scenery[0]["prop"] == "lamp")
	var row: Dictionary = level.scenery[1]
	check("the art identity, position and layer reach the playable data", row["prop"] == "treeSpruce"
		and row["x"] == 7.0 and row["y"] == 4.0 and row["layer"] == "far"
		and is_equal_approx(float(row["z"]), saved.position.z))
	check("the preview keeps its selected world", level.world_id() == "grove")
	var rendered := Node3D.new()
	add_child(rendered)
	check("the runtime mounts the saved cutout", SceneryData.load_data().mount_rows(rendered, level.scenery) == 1)
	var art := rendered.get_child(0) as MeshInstance3D
	check("runtime height, flip and opacity match the saved scene",
		is_equal_approx((art.mesh as QuadMesh).size.y, 3.2) and art.scale.x < 0.0
		and is_equal_approx((art.material_override as StandardMaterial3D).albedo_color.a, 0.42))
	check("the runtime uses the selected depth rather than the catalog default",
		is_equal_approx(art.position.z, saved.position.z))
	saved.queue_free()
	await get_tree().process_frame
	result = LevelExporter.new().export_scene(reopened)
	level = LevelData.load_slug(SLUG)
	check("deleting a placed cutout removes it from the next export", level.scenery.size() == 1)
	var empty := Node3D.new()
	check("an empty explicit art list does not restore the world's default cutouts",
		SceneryData.load_data().mount_rows(empty, []) == 0)
	empty.free()
	reopened.queue_free()
	rendered.queue_free()
	DirAccess.remove_absolute(SCENE)
	DirAccess.remove_absolute("res://data/levels/%s.json" % SLUG)
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)
