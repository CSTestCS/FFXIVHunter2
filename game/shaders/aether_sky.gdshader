shader_type sky;
// The character creator's backdrop: a starry blue nebula with a bright aetherial band along the
// horizon. Procedural, so no textures ship. rot turns the backdrop ("Rotate Background").
uniform float rot = 0.0;
// Colours below are authored as display (sRGB) values; Forward+ expects linear ones.
uniform bool linear_out = true;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; }
	return s;
}

void sky() {
	vec3 d = EYEDIR;
	float c = cos(rot), s = sin(rot);
	d = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
	float n = fbm(d * 2.2 + vec3(0.0, 0.0, 1.3));
	float n2 = fbm(d * 4.5 + n * 1.6);
	float neb = smoothstep(0.32, 0.82, n2);
	vec3 col = mix(vec3(0.004, 0.012, 0.05), vec3(0.04, 0.2, 0.62), neb * 0.85);
	col += vec3(0.3, 0.72, 1.0) * pow(smoothstep(0.55, 0.95, n2), 3.0) * 0.9;
	// Faint violet and crimson clouds on one side, as in the aetherial sea.
	float warm = smoothstep(0.48, 0.76, fbm(d * 1.6 + vec3(4.0)));
	col = mix(col, mix(vec3(0.3, 0.08, 0.42), vec3(0.42, 0.07, 0.1), smoothstep(-0.6, 0.8, d.x)), warm * 0.4 * (0.3 + neb));
	// The bright band of aether along the horizon.
	col += vec3(0.2, 0.62, 1.0) * exp(-abs(d.y + 0.02) * 14.0) * 0.8;
	col += vec3(0.65, 0.92, 1.0) * exp(-abs(d.y + 0.01) * 70.0) * 0.5;
	// Stars, thicker where the nebula glows.
	vec3 sp = d * 240.0;
	vec3 cell = floor(sp);
	float h = hash(cell);
	float star = step(0.982 - neb * 0.02, h) * smoothstep(0.32, 0.0, length(fract(sp) - 0.5)) * (0.5 + hash(cell + 1.7));
	col += vec3(0.8, 0.9, 1.0) * star * (0.5 + neb);
	COLOR = linear_out ? pow(max(col, vec3(0.0)), vec3(2.2)) : col;
}
