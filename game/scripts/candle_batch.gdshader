shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D glow_texture : filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0, 0.55, 0.22);
uniform float brightness = 0.4;
uniform bool halo = false;
varying float near_fade;

void vertex() {
	float phase = TIME * 9.0 + INSTANCE_CUSTOM.x;
	float flicker = 1.0 + sin(phase) * 0.06 + sin(phase * 2.3) * 0.05;
	vec2 extent = INSTANCE_CUSTOM.yz;
	if (halo) {
		extent *= 0.92 + 0.08 * flicker;
	} else {
		extent *= vec2(0.8 * flicker, 1.4 * flicker * flicker);
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= extent;
	near_fade = smoothstep(0.4, 1.6, length(MODELVIEW_MATRIX[3].xyz));
}

void fragment() {
	// Continuous fade avoids a costly per-pixel random discard on transparent sprites.
	ALBEDO = texture(glow_texture, UV).rgb * tint * brightness * near_fade;
	ALPHA = 1.0;
}
