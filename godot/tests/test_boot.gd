extends Node
## The one gate this skeleton has: the project boots headless, AssetRegistry
## parses real data/manifest.json, and the placeholder scene builds a status
## string without erroring. Nothing about gameplay — there is none yet.
##
## Run: godot --headless --path godot res://tests/test_boot.tscn

var _pass := 0
var _fail := 0


func _ready() -> void:
	var bail := Timer.new()
	bail.wait_time = 30.0
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

	print("\n%d passed, %d failed" % [_pass, _fail])
	if _fail > 0:
		get_tree().quit(1)
	else:
		print("ALL GREEN")
		get_tree().quit(0)


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_pass += 1
		print("  ok  - %s" % label)
	else:
		_fail += 1
		print("  FAIL - %s%s" % [label, ("  (%s)" % detail) if detail else ""])
