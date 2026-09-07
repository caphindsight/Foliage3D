shader_type spatial;
render_mode cull_disabled, specular_disabled;

global uniform float wind_power;
global uniform vec4 wind_sway_amplitudes;
global uniform vec4 wind_sway_frequencies;
global uniform float wind_turbulence;
global uniform vec2 wind_velocity;

uniform vec3 albedo_modulate: source_color = vec3(1.);
uniform sampler2D albedo_tex: source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex: hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale: hint_range(-16.0, 16.0) = 1.0;
uniform float alpha_scissor_threshold = 0.5;
uniform bool wind_enabled = true;
uniform float wind_power_scale = 1.0;
uniform float wind_characteristic_height = 1.0;
uniform bool toon_normals = true;
uniform float fade_start_distance = 28.0;
uniform float fade_end_distance = 64.0;

varying float fade;

float prng1(vec2 world_pos) {
	return fract(sin(dot(world_pos, vec2(13.14521, 4.67112))) * 41115.67117);
}

float prng2(vec2 world_pos) {
	return fract(sin(dot(world_pos, vec2(17.91671, 5.61271))) * 32296.71851);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_cam = INV_VIEW_MATRIX[3].xyz;
	float view_distance = distance(world_pos, world_cam);
	float fade_unrestricted = clamp(view_distance, fade_start_distance, fade_end_distance);
	fade = (fade_end_distance - fade_unrestricted) / (fade_end_distance - fade_start_distance);
	VERTEX *= smoothstep(0.0, 1.0, fade);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_cam = INV_VIEW_MATRIX[3].xyz;
	view_distance = distance(world_pos, world_cam);
	if (wind_enabled) {
		vec2 wind_effective_velocity = wind_velocity + mix(
			vec2(0.),
			vec2(prng1(world_pos.xz), prng2(world_pos.xz)) * 2. - vec2(1.),
			wind_turbulence
		) * length(wind_velocity);
		float wind_time = TIME - dot(world_pos.xz, wind_effective_velocity);
		float wind_amp = (
			wind_sway_amplitudes.x * sin(wind_time * wind_sway_frequencies.x) +
			wind_sway_amplitudes.y * sin(wind_time * wind_sway_frequencies.y) +
			wind_sway_amplitudes.z * sin(wind_time * wind_sway_frequencies.z) +
			wind_sway_amplitudes.w * sin(wind_time * wind_sway_frequencies.w)
		);
		vec2 delta = wind_power * wind_power_scale * wind_effective_velocity * wind_amp * VERTEX.y * VERTEX.y / wind_characteristic_height;
		if (VERTEX.y < 0.) delta = vec2(0.);
		world_pos += vec3(delta.x, 0., delta.y);
		VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
	}
	if (toon_normals) {
		NORMAL = vec3(0., 1., 0.);
	}
}

void fragment() {
	if (fade < 0.01) discard;

	vec4 albedo = texture(albedo_tex, UV);
	vec3 normal = texture(normal_tex, UV).rgb;

	if (toon_normals && !FRONT_FACING) NORMAL = -NORMAL;

	ALBEDO = albedo.rgb * albedo_modulate;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_scale;
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold; // mix(1.0, alpha_scissor_threshold, smoothstep(0.0, 1.0, fade));
}