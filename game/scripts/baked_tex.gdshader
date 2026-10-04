shader_type spatial;
// Pre-lit surface (see baked.gdshader). Specialised variant with no branches: phones are slow at them.
render_mode unshaded, cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float dim = 1.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV * uv_scale).rgb * COLOR.rgb * (2.0 * dim);
}
