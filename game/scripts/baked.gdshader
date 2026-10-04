shader_type spatial;
// Pre-lit surfaces: colour = texture x baked light. The baked light comes from the vertex
// colours (house) or from a light probe passed in (characters and disguises), so the GPU never
// has to evaluate a real-time light. The normal map adds surface relief on top.
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_tex = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform float normal_strength = 0.55;
uniform vec2 uv_scale = vec2(1.0);
uniform float dim = 1.0;
uniform bool use_vertex_light = true;
uniform vec3 flat_light = vec3(0.5);
uniform float shape_shading = 0.0;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec4 base = albedo;
	if (has_tex) {
		base *= texture(albedo_tex, uv);
	}
	vec3 light = use_vertex_light ? COLOR.rgb * 2.0 : flat_light;
	if (shape_shading > 0.0) {
		// soft form shading for moving things: lit from above and a little from the front
		float f = 0.62 + 0.38 * clamp(world_normal.y * 0.6 + 0.55 + dot(world_normal, normalize(vec3(0.4, 0.0, 0.6))) * 0.25, 0.0, 1.0);
		light *= mix(1.0, f * 1.25, shape_shading);
	}
	if (has_normal) {
		// normal maps are stored with only two channels: rebuild the third
		vec2 nxy = texture(normal_tex, uv).rg * 2.0 - 1.0;
		vec3 n = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
		float relief = clamp(dot(n, normalize(vec3(0.35, 0.45, 0.82))) / 0.82, 0.0, 1.4);
		light *= mix(1.0, relief * 1.22, normal_strength);
	}
	ALBEDO = base.rgb * light * dim;
}
