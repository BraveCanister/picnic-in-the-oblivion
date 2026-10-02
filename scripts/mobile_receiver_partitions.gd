extends RefCounted

# Offline resources only. Schema and manifest digest are pinned to this candidate.
const RECEIVERS = {
	"assets/levels/galosh_art/props_texgr3": {"pieces":11,"source_triangles":72,"triangles":72,"vertices":144,"preserved":11},
	"assets/levels/galosh_art/props_texobj1": {"pieces":14,"source_triangles":379,"triangles":379,"vertices":805,"preserved":14},
	"assets/levels/galosh_art/props_texobj2": {"pieces":25,"source_triangles":550,"triangles":582,"vertices":1016,"preserved":13},
}
const RESOURCE_ROOT = "res://assets/levels/galosh_art/mobile_receivers/"
const MANIFEST_PATH = RESOURCE_ROOT + "manifest.json"
const MANIFEST_SHA256 = "306e749d7c32e75497846bd470a47aa48977ed5e98ac0eaf8bd4f13f9362d015"

static func _eligible(android: bool, renderer: String, model: String) -> bool:
	return android and renderer == "mobile" and RECEIVERS.has(model)

static func apply(root: MeshInstance3D, model: String) -> bool:
	if not _eligible(OS.has_feature("android"), RenderingServer.get_current_rendering_method(), model):
		return false
	return _attach(root, model)

static func _fallback(model: String, reason: String) -> bool:
	push_warning("[Mobile Receivers] Missing/invalid partition resources for " + model + " (" + reason + "); retaining original mesh")
	return false

static func _attach(root: MeshInstance3D, model: String) -> bool:
	if not RECEIVERS.has(model): return false
	if not FileAccess.file_exists(MANIFEST_PATH) or FileAccess.get_sha256(MANIFEST_PATH) != MANIFEST_SHA256:
		return _fallback(model, "manifest fingerprint")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not manifest is Dictionary or manifest.get("schema") != 2 or manifest.get("engine") != "4.7.2.stable.official.ed1daf0bf":
		return _fallback(model, "manifest schema")
	if not manifest.get("assets") is Dictionary or not manifest.assets.get(model) is Dictionary:
		return _fallback(model, "manifest asset")
	return _attach_declared(root, model, manifest.assets[model])

static func _whole(value, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and float(value) == floor(float(value))

static func _vector(value) -> bool:
	if not value is Array or value.size() != 3: return false
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)): return false
	return true

static func _attach_declared(root: MeshInstance3D, model: String, declaration: Dictionary) -> bool:
	if not RECEIVERS.has(model): return false
	var policy: Dictionary = RECEIVERS[model]
	if root.mesh == null or root.material_override == null or root.mesh.get_surface_count() != 1:
		return _fallback(model, "source root")
	if root.mesh.surface_get_array_len(0) != policy.vertices or root.mesh.surface_get_array_index_len(0) != policy.source_triangles * 3 or root.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return _fallback(model, "source counts")
	if declaration.get("source_vertices") != policy.vertices or declaration.get("source_triangles") != policy.source_triangles or declaration.get("source_format") != root.mesh.surface_get_format(0) or declaration.get("triangles") != policy.triangles:
		return _fallback(model, "source declaration")
	if not declaration.get("pieces") is Array or declaration.pieces.size() != policy.pieces:
		return _fallback(model, "piece count")
	var meshes: Array[ArrayMesh] = []
	var total_indices = 0
	for index in int(policy.pieces):
		var row = declaration.pieces[index]
		var expected_path = RESOURCE_ROOT + model.get_file() + "/piece-%02d.res" % index
		var kind = "packed_preserved" if index < int(policy.preserved) else "subdivided"
		if not row is Dictionary or row.get("index") != index or row.get("path") != expected_path or row.get("topology") != kind or row.get("material_policy") != "root_override":
			return _fallback(model, "piece %d identity" % index)
		for field in ["vertices", "indices", "triangles"]:
			if not _whole(row.get(field), 1): return _fallback(model, "piece %d counts" % index)
		if row.indices != row.triangles * 3 or row.get("primitive") != Mesh.PRIMITIVE_TRIANGLES or not _whole(row.get("format"), 1):
			return _fallback(model, "piece %d topology" % index)
		if kind == "packed_preserved" and (row.vertices != policy.vertices or row.format != root.mesh.surface_get_format(0)):
			return _fallback(model, "piece %d preserved format" % index)
		if not row.get("bounds") is Dictionary or not _vector(row.bounds.get("position")) or not _vector(row.bounds.get("size")):
			return _fallback(model, "piece %d bounds declaration" % index)
		var p = row.bounds.position
		var s = row.bounds.size
		var expected_bounds = AABB(Vector3(p[0],p[1],p[2]),Vector3(s[0],s[1],s[2]))
		if s[0] < 0 or s[1] < 0 or s[2] < 0 or expected_bounds.size.length_squared() <= 0:
			return _fallback(model, "piece %d empty bounds" % index)
		if not row.get("sha256") is String or row.sha256.length() != 64 or not FileAccess.file_exists(expected_path) or FileAccess.get_sha256(expected_path) != row.sha256:
			return _fallback(model, "piece %d fingerprint" % index)
		if not ResourceLoader.exists(expected_path, "ArrayMesh"):
			return _fallback(model, "piece %d missing resource" % index)
		var mesh = ResourceLoader.load(expected_path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 1 or mesh.get_blend_shape_count() != 0:
			return _fallback(model, "piece %d resource" % index)
		if mesh.surface_get_array_len(0) != row.vertices or mesh.surface_get_array_index_len(0) != row.indices or mesh.surface_get_primitive_type(0) != row.primitive or mesh.surface_get_format(0) != row.format:
			return _fallback(model, "piece %d metadata mismatch" % index)
		if not mesh.custom_aabb.position.is_finite() or not mesh.custom_aabb.size.is_finite() or mesh.custom_aabb != expected_bounds:
			return _fallback(model, "piece %d bounds mismatch" % index)
		var material = mesh.surface_get_material(0)
		if not row.has("surface_material") or (row.surface_material == null and material != null) or (row.surface_material != null and (not row.surface_material is String or material == null or material.resource_path != row.surface_material)):
			return _fallback(model, "piece %d material mismatch" % index)
		total_indices += mesh.surface_get_array_index_len(0)
		meshes.append(mesh)
	if total_indices != policy.triangles * 3:
		return _fallback(model, "total triangle count")
	# Mutation begins only after every resource passed. Root/collider/notifier stay.
	for index in meshes.size():
		var piece = MeshInstance3D.new()
		piece.name = "MobileReceiver%02d" % index
		piece.mesh = meshes[index]
		piece.material_override = root.material_override
		piece.layers = root.layers
		piece.cast_shadow = root.cast_shadow
		piece.gi_mode = root.gi_mode
		piece.extra_cull_margin = root.extra_cull_margin
		root.add_child(piece)
	root.mesh = null
	print("[Mobile Receivers] Applied " + model + "; pieces=" + str(meshes.size()))
	return true
