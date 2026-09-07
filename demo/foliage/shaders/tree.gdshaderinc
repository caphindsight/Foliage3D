global uniform float wind_power;
global uniform vec4 wind_sway_amplitudes;
global uniform vec4 wind_sway_frequencies;
global uniform float wind_turbulence;
global uniform vec2 wind_velocity;

group_uniforms vertex;
uniform bool wind_enabled = false;
uniform float wind_power_scale = 1.0;
uniform bool toon_normals = false;
uniform float wind_turbulence_scale = 1.0;
group_uniforms;

float prng1(vec2 world_pos) {
	return fract(sin(dot(world_pos, vec2(13.14521, 4.67112))) * 41115.67117);
}

float prng2(vec2 world_pos) {
	return fract(sin(dot(world_pos, vec2(17.91671, 5.61271))) * 32296.71851);
}

void tree_vertex(
	inout vec3 vertex,  // VERTEX
	out vec3 normal,  // NORMAL
	out float view_distance,  // varying float
	vec4 color, // COLOR
	mat4 model_matrix, // MODEL_MATRIX
	mat4 inv_view_matrix // INV_VIEW_MATRIX
) {
	vec3 world_pos = (model_matrix * vec4(vertex, 1.0)).xyz;
	vec3 world_cam = inv_view_matrix[3].xyz;
	view_distance = distance(world_pos, world_cam);
	if (wind_enabled) {
		vec2 wind_effective_velocity = wind_velocity + mix(
			vec2(0.),
			vec2(prng1(world_pos.xz), prng2(world_pos.xz)) * 2. - vec2(1.),
			wind_turbulence * wind_turbulence_scale
		) * length(wind_velocity);
		float wind_time = TIME - dot(world_pos.xz, wind_effective_velocity);
		float wind_amp1 = (
			wind_sway_amplitudes.x * sin(wind_time * wind_sway_frequencies.x) +
			wind_sway_amplitudes.y * sin(wind_time * wind_sway_frequencies.y) +
			wind_sway_amplitudes.z * sin(wind_time * wind_sway_frequencies.z)
		);
		float wind_amp2 = (
			wind_sway_amplitudes.y * sin(wind_time * wind_sway_frequencies.y) +
			wind_sway_amplitudes.z * sin(wind_time * wind_sway_frequencies.z) +
			wind_sway_amplitudes.w * sin(wind_time * wind_sway_frequencies.w)
		);
		vec2 delta = wind_power * wind_power_scale * wind_effective_velocity * (color.b * wind_amp1 + color.r * wind_amp2);
		if (vertex.y < 0.) delta = vec2(0.);
		world_pos += vec3(delta.x, 0., delta.y);
		vertex = (inverse(model_matrix) * vec4(world_pos, 1.0)).xyz;
	}
	if (toon_normals) {
		normal = vec3(0., 1., 0.);
	}
}