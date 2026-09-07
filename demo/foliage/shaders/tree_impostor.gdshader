shader_type spatial;

uniform vec3 albedo_modulate: source_color = vec3(1.);
uniform sampler2D albedo_tex: source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_roughness_tex: hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale: hint_range(-16.0, 16.0) = 1.0;
uniform float alpha_scissor_threshold = 0.5;

varying flat int instance_id;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	instance_id = INSTANCE_ID;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 uv = UV * 0.5;
	if (instance_id % 2 == 1) {
		uv += vec2(0.5, 0.0);
	}
	if ((instance_id / 2) % 2 == 1) {
		uv += vec2(0.0, 0.5);
	}
	vec4 albedo = texture(albedo_tex, uv);
	vec4 normal_roughness = texture(normal_roughness_tex, uv);
	vec3 normal = normal_roughness.rgb;
	float roughness = normal_roughness.a;

	ALBEDO = albedo.rgb * albedo_modulate;
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = roughness;
}