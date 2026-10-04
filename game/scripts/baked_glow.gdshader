shader_type spatial;
// Pre-lit surface (see baked.gdshader). Specialised variant with no branches: phones are slow at them.
render_mode unshaded, cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float dim = 1.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
void fragment() {
	ALBEDO = albedo.rgb * (has_tex ? texture(albedo_tex, UV).rgb : vec3(1.0));
}
