shader_type spatial;
// Pre-lit surface (see baked.gdshader). Specialised variant with no branches: phones are slow at them.
render_mode unshaded, cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float dim = 1.0;
void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb * (2.0 * dim);
}
