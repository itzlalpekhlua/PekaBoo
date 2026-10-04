shader_type spatial;
// Pre-lit surface (see baked.gdshader). Specialised variant with no branches: phones are slow at them.
render_mode unshaded, cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float dim = 1.0;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform float normal_strength = 0.55;
void fragment() {
	vec2 nxy = texture(normal_tex, UV * uv_scale).rg * 2.0 - 1.0;
	vec3 n = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
	float relief = clamp(dot(n, vec3(0.3437, 0.4419, 0.8287)) / 0.82, 0.0, 1.4);
	ALBEDO = albedo.rgb * COLOR.rgb * (2.0 * dim * mix(1.0, relief * 1.22, normal_strength));
}
