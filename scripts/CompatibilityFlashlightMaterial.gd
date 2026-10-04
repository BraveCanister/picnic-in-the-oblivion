extends ShaderMaterial

# Disposable Compatibility fallback for ordinary opaque, non-emissive world
# surfaces. Keep the loader's material property interface for day/night changes.
const BODY = preload("res://shaders/compatibility_flashlight.gdshader")
static var variants: Dictionary = {}
var original: StandardMaterial3D
var shading_mode: int:
	get:
		return original.shading_mode if original != null else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	set(value):
		if original != null:
			original.shading_mode = value
			_sync()

static func wrap(material: Material, model: String = "") -> Material:
	if not material is StandardMaterial3D:
		return material
	var source := material as StandardMaterial3D
	var foliage := model in ["assets/models/tree_faced", "assets/models/forest_1"]
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and not (foliage and source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS):
		return material
	if source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED and not (foliage and source.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y):
		return material
	if source.emission_enabled or source.normal_enabled or source.proximity_fade_enabled or source.metallic != 0.0 or source.metallic_specular != 0.0 or source.diffuse_mode != BaseMaterial3D.DIFFUSE_TOON or source.albedo_texture == null:
		return material
	var result = load("res://scripts/CompatibilityFlashlightMaterial.gd").new()
	result.original = source
	result._sync()
	return result

func _sync() -> void:
	var modes := "diffuse_toon, specular_disabled"
	if original.cull_mode == BaseMaterial3D.CULL_DISABLED:
		modes += ", cull_disabled"
	elif original.cull_mode == BaseMaterial3D.CULL_FRONT:
		modes += ", cull_front"
	if original.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		modes += ", unshaded"
	var alpha := original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	if alpha:
		modes += ", depth_prepass_alpha"
	var billboard := original.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y
	var key := modes + str(billboard) + str(original.billboard_keep_scale)
	if not variants.has(key):
		var variant := Shader.new()
		variant.code = BODY.code.replace("render_mode diffuse_toon, specular_disabled;", "render_mode " + modes + ";")
		if alpha:
			variant.code = variant.code.replace("// FOLIAGE_ALPHA", "ALPHA = texture(texture_albedo, UV).a * color_albedo.a;")
		if billboard:
			# Match StandardMaterial3D's fixed-Y facing and scale preservation.
			var vertex_code := """
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
        vec4(0.0, 1.0, 0.0, 0.0),
        vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
        MODEL_MATRIX[3]);
"""
			if original.billboard_keep_scale:
				vertex_code += """
    MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
        vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
        vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
        vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
        vec4(0.0, 0.0, 0.0, 1.0));
"""
			vertex_code += "MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);"
			variant.code = variant.code.replace("// FOLIAGE_BILLBOARD", vertex_code)
			variant.code = variant.code.replace("(MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz", "(INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz")
		variants[key] = variant
	shader = variants[key]
	set_shader_parameter("texture_albedo", original.albedo_texture)
	set_shader_parameter("color_albedo", original.albedo_color)
	set_shader_parameter("material_roughness", original.roughness)
