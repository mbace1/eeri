class_name PickupArt
extends RefCounted
## Bake the existing catalog prop into a shared mesh once, then instance it
## with MultiMesh. Hundreds of pickups keep two draw groups, not 100 scenes.

static func mesh_for(id: String) -> Mesh:
	var entry := AssetRegistry.get_model(id)
	var path := "res://data/" + String(entry.get("file", ""))
	if entry.get("status", "") != "live" or not ResourceLoader.exists(path):
		return _fallback()
	var packed := load(path) as PackedScene
	if packed == null: return _fallback()
	var root := packed.instantiate()
	var pieces := []
	_collect(root, Transform3D.IDENTITY, pieces)
	var bounds := AABB()
	var first := true
	for piece in pieces:
		var box: AABB = piece["transform"] * piece["mesh"].get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if pieces.is_empty() or bounds.size.y <= 0.0:
		root.free()
		return _fallback()
	var scale := float(entry.get("height", bounds.size.y)) / bounds.size.y
	var normalize := Transform3D(Basis().scaled(Vector3.ONE * scale), -bounds.get_center() * scale)
	var result := ArrayMesh.new()
	for piece in pieces:
		var mesh: Mesh = piece["mesh"]
		for surface in mesh.get_surface_count():
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.append_from(mesh, surface, normalize * piece["transform"])
			var material := mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				material = material.duplicate()
				material.metallic = 0.0
				material.roughness = 1.0
				material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			tool.set_material(material)
			tool.commit(result)
	result.set_meta("eeri_asset", path)
	root.free()
	return result


static func _collect(node: Node, parent: Transform3D, pieces: Array) -> void:
	var transform := parent
	if node is Node3D: transform = parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		pieces.append({"mesh": node.mesh, "transform": transform})
	for child in node.get_children(): _collect(child, transform, pieces)


static func _fallback() -> Mesh:
	var hex := CylinderMesh.new()
	hex.radial_segments = 6
	hex.top_radius = 0.26
	hex.bottom_radius = 0.26
	hex.height = 0.12
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(hex, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	tool.set_material(Craft.mat(Craft.MACHINE))
	return tool.commit()
