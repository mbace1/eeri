extends Node
## The manifest reader — the same seam js/assets.js owns in the browser build.
##
## `../assets/manifest.json` (the canon copy, one level above `godot/`) is
## copied into `res://data/manifest.json` by `tools/sync-data.mjs`, along with
## every asset file it marks `"live"`, because Godot can only load from res://
## and two hand-kept copies of canon is how a second lineage starts (see
## assets/README.md upstream, and EERI_GODOT_HANDOFF.md §3 in this repo).
##
## Most of the roster is already live — `eeri_v5.glb`, `excavator_v1.glb` and
## both shipped worlds' full layer sets among them (51 live entries against
## 26 placeholders as of the split). This registry does not render any of it
## yet; it only proves the seam parses and reports what is actually there,
## same as `main.gd`'s placeholder scene does on screen.

const MANIFEST_PATH := "res://data/manifest.json"

var manifest: Dictionary = {}
var loaded := false
var load_error := ""


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		load_error = "missing %s — run tools/sync-data.mjs first" % MANIFEST_PATH
		push_warning(load_error)
		return
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "manifest did not parse as a JSON object"
		push_warning(load_error)
		return
	manifest = parsed
	loaded = true


## Look a node/clip-rig model up by id under "models" or "pieces". Returns an
## empty Dictionary (never null) for an id that is not registered, mirroring
## assets.js: a caller checks .is_empty() rather than a null crash.
func get_model(id: String) -> Dictionary:
	for group in ["models", "pieces"]:
		if manifest.has(group) and manifest[group].has(id):
			return manifest[group][id]
	return {}


func is_live(id: String) -> bool:
	var entry := get_model(id)
	return entry.get("status", "placeholder") == "live"


## Every {status, file|files} leaf anywhere in the manifest, status counted
## regardless of which top-level group (models / pieces / layers / textures /
## ui) it sits under — a world's live count lives four keys deep inside
## "layers" and a flat models/pieces walk misses it entirely.
func _count_leaves() -> Dictionary:
	var counts := {"live": 0, "placeholder": 0}
	var stack: Array = [manifest]
	while not stack.is_empty():
		var node = stack.pop_back()
		if typeof(node) != TYPE_DICTIONARY:
			continue
		if node.has("status") and (node.has("file") or node.has("files")):
			var status: String = node.get("status", "placeholder")
			counts[status] = counts.get(status, 0) + 1
		else:
			for k in node.keys():
				if typeof(k) == TYPE_STRING and k.begins_with("_"):
					continue
				stack.push_back(node[k])
	return counts


## A quick one-line summary for the placeholder scene / smoke test — never
## meant to be read by game logic.
func summary() -> String:
	if not loaded:
		return load_error
	var counts := _count_leaves()
	return "manifest v%s — %d live assets, %d placeholder" % [
		manifest.get("v", "?"), counts["live"], counts["placeholder"]
	]
