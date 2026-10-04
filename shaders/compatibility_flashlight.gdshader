shader_type spatial;
render_mode diffuse_toon, specular_disabled;

global uniform mat4 picnic_flashlight_inverse;
global uniform float picnic_flashlight_tangent;
global uniform float picnic_flashlight_size;
global uniform sampler2D picnic_flashlight_cookie : source_color, filter_linear, repeat_disable;
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform vec4 color_albedo : source_color = vec4(1.0);
uniform float material_roughness = 1.0;
uniform bool cookie_enabled = true;
varying vec3 world_position;

void vertex() {
    // FOLIAGE_BILLBOARD
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    ALBEDO = texture(texture_albedo, UV).rgb * color_albedo.rgb;
    // FOLIAGE_ALPHA
    ROUGHNESS = material_roughness;
    SPECULAR = 0.0;
}

void light() {
    // Only the camera flashlight carries this runtime tag. Other lights retain
    // their unfiltered contribution, including player/NPC muzzle lights.
    bool flashlight = !LIGHT_IS_DIRECTIONAL && abs(SPECULAR_AMOUNT - 0.274) < 0.002;
    float projector = 1.0;
    float size_bias = 0.0;
    if (flashlight) {
        vec3 local = (picnic_flashlight_inverse * vec4(world_position, 1.0)).xyz;
        float t = picnic_flashlight_size / max(length(local), 0.001);
        size_bias = max(0.0, 1.0 - inversesqrt(1.0 + t * t));
        if (cookie_enabled) {
            vec2 uv = local.xy / (max(-local.z, 0.001) * picnic_flashlight_tangent) * 0.5 + 0.5;
            uv.y = 1.0 - uv.y;
            projector = local.z < 0.0 && all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))
                ? texture(picnic_flashlight_cookie, uv).r : 0.0;
            // Native projectors sample an sRGB atlas into linear light. The
            // Compatibility sampler supplies encoded values; decode this light
            // filter explicitly rather than widening its dim outer halo.
            if (OUTPUT_IS_SRGB) {
                projector = projector <= 0.04045 ? projector / 12.92
                    : pow((projector + 0.055) / 1.055, 2.4);
            }
        }
    }
    float ndotl = min(size_bias + dot(NORMAL, LIGHT), 1.0);
    float diffuse = smoothstep(-ROUGHNESS, max(ROUGHNESS, 0.01), ndotl) / PI;
    DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * diffuse * projector;
}
