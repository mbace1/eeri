extends Node
## Boot gate: the project stands up, the data seam parses, and — the part
## that actually earns its place — every live 3D model IMPORTS and still
## carries the contract the game drives it by.
##
## That last group exists because all seven models silently failed to import
## before the dequantize pass was added to tools/sync-data.mjs, and nothing
## caught it: the manifest still parsed, the scene still rendered, the boot
## still "passed". A gate that only reads JSON cannot see a broken importer.
##
## Run: godot --headless --path godot res://tests/test_boot.tscn

var _pass := 0
var _fail := 0

## The rigid-node machines: what assets.js looks up and excavator.js drives.
const NODE_CONTRACTS := {
	"excavator": ["house", "boom", "stick", "bucket", "seat", "step", "wheels", "beacon"],
}
## The skinned cast: driven by CLIP name, not node name (assets/README.md).
const CLIP_CONTRACTS := {
	"eeri": ["idle", "walk", "run", "jump", "climb", "stomp", "hurt"],
}


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 60.0
	bail.one_shot = true
	bail.timeout.connect(func():
		print("BOOT FAIL: timed out")
		get_tree().quit(1))
	add_child(bail)
	bail.start()

	print("── Eeri Godot skeleton — boot gate ──")

	check("AssetRegistry autoload exists", AssetRegistry != null)
	check("manifest loaded", AssetRegistry.loaded, AssetRegistry.load_error)

	if AssetRegistry.loaded:
		var counts := AssetRegistry._count_leaves()
		check("at least one live asset found", counts.get("live", 0) > 0,
			"live=%d placeholder=%d" % [counts.get("live", 0), counts.get("placeholder", 0)])
		check("eeri (the kid) is registered", not AssetRegistry.get_model("eeri").is_empty())
		check("unknown id returns empty, not null", AssetRegistry.get_model("nope_not_real").is_empty())

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	check("main.tscn loads", main_scene != null)
	if main_scene:
		var inst := main_scene.instantiate()
		add_child(inst)
		check("main scene status label is non-empty", inst.get_node("UI/Status").text.length() > 0)
		inst.queue_free()

	check("GameState autoload exists", GameState != null)

	_check_models()

	print("\n%d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		get_tree().quit(1)
	else:
		print("ALL GREEN")
		get_tree().quit(0)


## Every live .glb the manifest names must actually load, and the ones with a
## declared contract must still satisfy it.
func _check_models() -> void:
	if not AssetRegistry.loaded:
		return
	print("  -- live models --")
	var checked := 0
	for group in ["models", "pieces"]:
		var entries: Dictionary = AssetRegistry.manifest.get(group, {})
		for id in entries.keys():
			var e: Dictionary = entries[id]
			if e.get("status", "placeholder") != "live":
				continue
			var f = e.get("file", "")
			if typeof(f) != TYPE_STRING or not f.ends_with(".glb"):
				continue
			checked += 1
			var path: String = "res://data/" + str(f)
			var ps := load(path) as PackedScene
			# A failed glTF import leaves NO resource — this is the check that
			# would have caught KHR_mesh_quantization on day one.
			check("%s imports" % id, ps != null, path)
			if ps == null:
				continue
			var inst := ps.instantiate()
			if NODE_CONTRACTS.has(id):
				var names := _node_names(inst)
				var missing: Array[String] = []
				for want in NODE_CONTRACTS[id]:
					if not names.has(want):
						missing.append(want)
				check("%s keeps its node contract" % id, missing.is_empty(),
					"missing: " + ", ".join(missing))
			if CLIP_CONTRACTS.has(id):
				var clips := _clip_names(inst)
				var missing_c: Array[String] = []
				for want in CLIP_CONTRACTS[id]:
					if not clips.has(want):
						missing_c.append(want)
				check("%s keeps its clip contract" % id, missing_c.is_empty(),
					"has: " + ", ".join(clips))
			inst.queue_free()
	check("every live model was checked (not silently zero)", checked > 0,
		"checked=%d" % checked)


func _node_names(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n.name)
		for c in n.get_children():
			stack.push_back(c)
	return out


func _clip_names(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			for lib_name in n.get_animation_library_list():
				var lib: AnimationLibrary = n.get_animation_library(lib_name)
				for a in lib.get_animation_list():
					out.append(a)
		for c in n.get_children():
			stack.push_back(c)
	return out


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("  ok  - %s" % label)
	else:
		_fail += 1
		print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
