extends Node
## Import every campaign room, export a preview, and compare the content the
## player actually uses. An importer that silently drops a job is not usable.
var passed := 0
var failed := 0

func check(label: String, condition: bool, detail := "") -> void:
	print("  %s - %s%s" % ["ok" if condition else "FAIL", label,
		"" if condition else ": " + detail])
	if condition: passed += 1
	else: failed += 1

func _ready() -> void:
	var timeout := get_tree().create_timer(60.0)
	timeout.timeout.connect(func(): print("FAIL - campaign editor check timed out"); get_tree().quit(1))
	for entry in LevelData.load_index().get("levels", []):
		var slug := String(entry["slug"])
		var original := LevelData.load_slug(slug)
		var scene := EeriLevelImporter.new().build(slug)
		if scene == null:
			check(slug + " imports without a data error", false)
			get_tree().quit(1)
			return
		add_child(scene)
		await get_tree().process_frame
		var result := LevelExporter.new().export_scene(scene, "eeri-campaign-preview")
		check(slug + " imports and exports a valid preview", result.get("written", false),
			str(result.get("problems", [])))
		var edited := LevelData.load_slug("eeri-campaign-preview")
		if edited == null:
			scene.queue_free()
			continue
		check(slug + " terrain survives unchanged", edited.grid == original.grid)
		check(slug + " all collectibles survive", _same_points(edited.bolts, original.bolts)
			and _same_points(edited.golden, original.golden) and edited.blueprint == original.blueprint)
		check(slug + " machine identity, track and verbs survive", _equal(edited.machines, original.machines),
			str(edited.machines) + " / " + str(original.machines))
		check(slug + " jobs and moving pieces survive", _equal(edited.sheet, original.sheet)
			and _equal(edited.flooded, original.flooded) and _equal(edited.planks, original.planks)
			and _equal(edited.girder, original.girder), str(edited.girder) + " / " + str(original.girder))
		check(slug + " exits, flag and checkpoint survive", _equal(edited.flag, original.flag)
			and _equal(edited.gate, original.gate) and _equal(edited.checkpoint, original.checkpoint))
		if original.index % 3 == 0:
			var output := []
			var status := OS.execute("node", [ProjectSettings.globalize_path("res://tools/apply-scenery.mjs"),
				ProjectSettings.globalize_path("res://data/levels/eeri-campaign-preview.json")], output, true)
			var review = JSON.parse_string("".join(output))
			check(slug + " unchanged world art needs no source rewrite", status == 0
				and review is Dictionary and review.get("changed", true) == false, str(output))
		if slug == "eeri-2-1":
			var machine := scene.get_node("Entities/Machine") as EeriMachineSpawn
			machine.kind = EeriMachineSpawn.Kind.EXCAVATOR
			var invalid := LevelExporter.new().export_scene(scene, "eeri-campaign-preview", false)
			check("the pump job rejects a machine that cannot drain", str(invalid["problems"]).contains("flooded needs"))
			check("checking an invalid job preserves the valid preview", LevelData.load_slug("eeri-campaign-preview").machines[0]["type"] == "pump")
		scene.queue_free()
		await get_tree().process_frame
	DirAccess.remove_absolute("res://data/levels/eeri-campaign-preview.json")
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func _same_points(a: Array, b: Array) -> bool:
	var left := a.map(func(p): return str(int(p[0])) + ":" + str(int(p[1])))
	var right := b.map(func(p): return str(int(p[0])) + ":" + str(int(p[1])))
	left.sort()
	right.sort()
	return left == right

func _equal(a, b) -> bool:
	# Node3D positions use float32; sub-pixel seating windows such as 67.6
	# cannot round-trip as identical float64 JSON literals.
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.0001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _equal(a[i], b[i]): return false
		return true
	return a == b
