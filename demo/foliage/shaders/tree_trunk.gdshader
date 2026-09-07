shader_type spatial;

#include "tree.gdshaderinc"

group_uniforms fragment;
uniform vec3 albedo_modulate: source_color = vec3(1.);
uniform sampler2D albedo_tex: source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_roughness_tex: hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale: hint_range(-16.0, 16.0) = 1.0;
group_uniforms;

void vertex() {
	float view_distance;  // Unused.
	tree_vertex(VERTEX, NORMAL, view_distance, COLOR, MODEL_MATRIX, INV_VIEW_MATRIX);
}

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	vec4 normal_roughness = texture(normal_roughness_tex, UV);
	vec3 normal = normal_roughness.rgb;
	float roughness = normal_roughness.a;

	if (toon_normals && !FRONT_FACING) NORMAL = -NORMAL;

	ALBEDO = albedo.rgb * albedo_modulate;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = roughness;
}
