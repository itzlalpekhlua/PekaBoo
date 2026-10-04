shader_type spatial;
// Characters and disguises: lit by the room's light probe, with soft form shading worked out
// per vertex (cheap) instead of per pixel.
render_mode unshaded, cull_back;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 flat_light = vec3(0.8);
uniform float shape_shading = 0.5;
varying float shade;
void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float f = 0.62 + 0.38 * clamp(n.y * 0.6 + 0.55 + dot(n, vec3(0.5547, 0.0, 0.8321)) * 0.25, 0.0, 1.0);
	shade = mix(1.0, f * 1.25, shape_shading);
}
void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb * flat_light * shade;
}
