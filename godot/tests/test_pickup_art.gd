extends Node
var passed := 0
var failed := 0

func check(label: String, value: bool) -> void:
	print("  %s - %s" % ["ok" if value else "FAIL", label])
	if value: passed += 1
	else: failed += 1

func _ready() -> void:
	var bolt := PickupArt.mesh_for("bolt")
	var golden := PickupArt.mesh_for("token_bolt")
	check("ordinary bolts use the catalog model", String(bolt.get_meta("eeri_asset", "")).ends_with("bolt_v1.glb"))
	check("golden bolts use the distinct wing-nut model", String(golden.get_meta("eeri_asset", "")).ends_with("token_bolt_v1.glb"))
	check("the ordinary pickup is a real mesh rather than a box", bolt.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 30)
	check("the golden model keeps its declared sub-tile height", absf(golden.get_aabb().size.y - 0.85) < 0.001)
	check("pickup geometry rotates about its center", bolt.get_aabb().get_center().length() < 0.001)
	check("pickup materials retain their painted texture", (bolt.surface_get_material(0) as StandardMaterial3D).albedo_texture != null)
	check("the instanced material remains matte", (bolt.surface_get_material(0) as StandardMaterial3D).metallic == 0)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = bolt
	instances.instance_count = 100
	check("one shared mesh supports a full level of ordinary pickups", instances.instance_count == 100 and instances.mesh == bolt)
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)
