shader_type sky;
// Chill mode sky: deep blue-violet night, twinkling stars, a soft moon with a halo,
// a faint milky band and a shooting star whenever the script sets shoot_t.

global uniform float pekaboo_night_time;

uniform vec3 moon_dir = vec3(-0.5, 0.62, -0.6);
global uniform float shoot_t;            // 0..1 while a shooting star crosses, else < 0
uniform vec3 shoot_from = vec3(-0.6, 0.55, -0.55);
uniform vec3 shoot_to = vec3(0.1, 0.35, -0.9);
uniform sampler2D star_tex : filter_linear_mipmap; // stars drawn once by the script (rgb + twinkle phase in a)
uniform float cloud = 0.0;               // 0..1: overcast (rain / snow)

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// lighting / reflection pass: just the colours, no detail
		COLOR = mix(vec3(0.22, 0.12, 0.32), vec3(0.02, 0.025, 0.08), clamp(EYEDIR.y, 0.0, 1.0));
	} else {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -0.2, 1.0);
	// gradient: warm violet glow at the horizon into deep navy overhead
	vec3 horizon = vec3(0.22, 0.12, 0.32);
	vec3 mid = vec3(0.06, 0.06, 0.17);
	vec3 top = vec3(0.012, 0.016, 0.06);
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.25, up));
	col = mix(col, top, smoothstep(0.25, 0.9, up));
	if (d.y < 0.0) {
		col = mix(horizon, vec3(0.03, 0.025, 0.06), smoothstep(0.0, -0.15, d.y));
	}
	// faint milky way band
	float bd = dot(d, vec3(0.3537, 0.2526, 0.9095)) * 4.5;
	float band = 1.0 / (1.0 + bd * bd * 1.4);
	col += vec3(0.09, 0.07, 0.14) * band * smoothstep(0.0, 0.3, up);
	// stars: one look-up in a picture drawn at start-up (much cheaper than working them out)
	vec4 st = texture(star_tex, SKY_COORDS);
	float tw = 0.6 + 0.4 * sin(pekaboo_night_time * (1.5 + st.a * 3.0) + st.a * 40.0);
	col += st.rgb * tw * 2.4 * smoothstep(0.02, 0.2, up) * (1.0 + band * 0.6);
	// moon + halo
	float md_dot = dot(d, moon_dir);
	if (md_dot > 0.8) {
		float disk = smoothstep(0.99955, 0.99975, md_dot);
		float spots = 0.85 + 0.15 * hash(floor(d * 900.0));
		col = mix(col, vec3(1.0, 0.97, 0.88) * 2.2 * spots, disk);
		col += vec3(0.45, 0.42, 0.6) * pow(md_dot, 220.0) * 0.9;
		col += vec3(0.22, 0.2, 0.35) * pow(md_dot, 18.0) * 0.35;
	}
	// shooting star: a bright head with a fading tail
	if (shoot_t >= 0.0 && shoot_t <= 1.0) {
		vec3 a = normalize(shoot_from);
		vec3 b = normalize(shoot_to);
		vec3 head = normalize(mix(a, b, shoot_t));
		vec3 tail = normalize(mix(a, b, max(0.0, shoot_t - 0.22)));
		vec3 seg = head - tail;
		float len2 = max(dot(seg, seg), 1e-6);
		float k = clamp(dot(d - tail, seg) / len2, 0.0, 1.0);
		float dist = length(d - (tail + seg * k));
		float fade = sin(shoot_t * 3.14159);
		col += vec3(1.0, 0.92, 0.8) * smoothstep(0.004, 0.0, dist) * k * k * 3.0 * fade;
	}
	// clouds for rain / snow: hide the stars, soft grey-violet overcast
	if (cloud > 0.001) {
		float puff = 0.5 + 0.25 * sin(d.x * 7.0 + d.z * 5.0 + pekaboo_night_time * 0.05) + 0.25 * sin(d.z * 11.0 - d.x * 4.0);
		col = mix(col, mix(vec3(0.07, 0.065, 0.1), vec3(0.15, 0.14, 0.2), puff) * (0.6 + 0.4 * up), cloud * 0.88);
	}
	COLOR = col;
	}
}
