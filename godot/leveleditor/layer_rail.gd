class_name EeriLayerRail
extends RefCounted
## Which depth layer a level-editor marker is placed on.
##
## The names and z values are the ones Godot already has. `data/scenery.json`
## `layerZ` is what `SceneryData` reads (SKY / SKYLINE / FAR / MID / NEAR /
## PLAY / FORE). That file is generated, so if it is missing the same lanes
## fall back to `Diorama.RECTS` — the depths committed in this project — plus
## PLAY at z = 0, which is the plane `EeriMarker` already treats as gameplay.
##
## This is not a second paint plane. `LevelExporter` reads GridMap cell x/y
## and ignores cell z, and marker export reads x/y only. The field a layer
## actually changes is the marker's `position.z`. x/y snap to the half-tile
## grid because authored markers already sit on both cell corners (an exit
## at x = 18) and cell centres (a kid spawn at x = 1.5); a whole-tile snap
## would move the centres.
##
## Dropping calls `place` (layer z + x/y snap). Dragging an already placed
## marker calls `snap_xy` only: same grid, same z, same `eeri_layer`. The
## slider still does not move markers that are already in the scene.

const SNAP := 0.5


static func layers() -> Array:
	var from_data := _from_scenery()
	if not from_data.is_empty():
		return from_data
	return _from_diorama()


static func layer_count() -> int:
	return layers().size()


static func layer_at(index: int) -> Dictionary:
	var all := layers()
	if all.is_empty():
		return {"name": "PLAY", "z": 0.0}
	return all[clampi(index, 0, all.size() - 1)]


static func index_of(layer_name: String) -> int:
	var want := layer_name.to_upper()
	var all := layers()
	for i in all.size():
		if String(all[i]["name"]).to_upper() == want:
			return i
	return 0


## Only level-editor markers take a layer. Terrain stays the GridMap.
static func is_marker(node: Node) -> bool:
	return node is EeriMarker


## Snap x/y onto the half-tile grid and put the marker on the layer's z.
## `eeri_layer` records the name next to the transform so a later read does
## not have to reverse-lookup z (FORE is 2.2, which is not a grid line).
static func place(marker: Node3D, index: int) -> void:
	if marker == null:
		return
	var layer := layer_at(index)
	var p := marker.position
	marker.position = Vector3(p.x, p.y, float(layer["z"]))
	snap_xy(marker)
	marker.set_meta("eeri_layer", String(layer["name"]))


## Snap x/y onto the half-tile grid. Depth is left alone, including FORE at
## 2.2, which is not a grid line. `eeri_layer` is left alone too.
static func snap_xy(marker: Node3D) -> void:
	if marker == null:
		return
	var p := marker.position
	var x: float = snapped(p.x, SNAP)
	var y: float = snapped(p.y, SNAP)
	if is_equal_approx(p.x, x) and is_equal_approx(p.y, y):
		return
	marker.position = Vector3(x, y, p.z)


static func _from_scenery() -> Array:
	var data := SceneryData.load_data()
	if data.layer_z.is_empty():
		return []
	var out: Array = []
	for key in data.layer_z.keys():
		out.append({"name": String(key), "z": float(data.layer_z[key])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["z"]) < float(b["z"]))
	return out


static func _from_diorama() -> Array:
	var out: Array = []
	for lane in Diorama.ORDER:
		var rect: Dictionary = Diorama.RECTS[lane]
		out.append({"name": String(lane).to_upper(), "z": float(rect["z"])})
	out.append({"name": "PLAY", "z": 0.0})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["z"]) < float(b["z"]))
	return out
