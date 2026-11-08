shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;
// The glowing platform the character stands on in the aetherial sea: rippling caustics that fade
// toward a dark rim, with two faint rings. Colours are authored as display (sRGB) values.
uniform bool linear_out = true;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = TIME * 0.22;
	vec2 q = p * 6.5;
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		q += vec2(sin(q.y * 1.3 + t * 1.7 + float(i)), cos(q.x * 1.1 - t * 1.3 + float(i) * 2.0));
		c += 1.0 / (1.0 + 5.0 * abs(sin(q.x) * sin(q.y)));
	}
	c /= 3.0;
	vec3 base = mix(vec3(0.12, 0.4, 0.8), vec3(0.01, 0.05, 0.16), smoothstep(0.0, 0.95, r));
	vec3 col = base + vec3(0.45, 0.82, 1.0) * pow(c, 3.0) * (1.0 - r) * 1.3;
	col += vec3(0.5, 0.85, 1.0) * (smoothstep(0.018, 0.0, abs(r - 0.5)) * 0.35 + smoothstep(0.012, 0.0, abs(r - 0.93)) * 0.25);
	ALBEDO = linear_out ? pow(col, vec3(2.2)) : col;
	ALPHA = smoothstep(0.98, 0.6, r);
}
