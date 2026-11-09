shader_type spatial;
// Procedural architectural surfaces, projected in world space (triplanar) so merged city meshes
// need no UVs or texture files. kind: 0 dressed stone, 1 timber, 2 plaster, 3 roof shingles,
// 4 bark, 5 rough rock, 6 planks (decks and walkways). Moss gathers on upward faces.
uniform int kind = 0;
uniform vec3 base : source_color = vec3(0.5);
uniform vec3 base2 : source_color = vec3(0.4);
uniform float scale = 1.0;
uniform float moss = 0.0;
uniform vec3 moss_color : source_color = vec3(0.24, 0.34, 0.12);
uniform float rough = 0.85;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float nz(vec2 p) {
	return texture(noise_tex, p).r;
}

// Height-like pattern value (0 = groove/mortar, 1 = face) and a tint for one projection plane.
// u runs along the surface horizontally, v vertically (v = world height on walls).
vec2 pattern(vec2 uv, bool wall) {
	float s = scale;
	if (kind == 0) {   // dressed stone courses
		vec2 p = uv * vec2(1.4, 2.6) * s;
		float row = floor(p.y);
		p.x += hash12(vec2(row, 3.1)) * 0.9 + mod(row, 2.0) * 0.5;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float jx = 0.06 + hash12(cell) * 0.04;
		float m = smoothstep(0.0, jx, f.x) * smoothstep(1.0, 1.0 - jx, f.x) * smoothstep(0.0, 0.1, f.y) * smoothstep(1.0, 0.9, f.y);
		return vec2(m, hash12(cell + 7.0));
	} else if (kind == 1) {   // timber grain along the length
		float g = nz(vec2(uv.x * 0.08, uv.y * 2.4) * s) * 0.7 + nz(vec2(uv.x * 0.3, uv.y * 9.0) * s) * 0.3;
		return vec2(0.75 + g * 0.25, g);
	} else if (kind == 2) {   // lime plaster
		float g = nz(uv * 0.35 * s) * 0.6 + nz(uv * 2.1 * s) * 0.4;
		return vec2(0.9 + g * 0.1, g);
	} else if (kind == 3) {   // overlapping shingles in courses
		vec2 p = uv * vec2(3.2, 4.2) * s;
		float row = floor(p.y);
		p.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float edge = smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x);
		float lap = smoothstep(0.0, 0.25, f.y);
		return vec2(edge * (0.55 + 0.45 * lap), hash12(cell));
	} else if (kind == 4) {   // bark: deep vertical furrows
		float f = nz(vec2(uv.x * 0.9, uv.y * 0.12) * s);
		float furrow = smoothstep(0.35, 0.65, abs(fract(uv.x * 2.2 * s + f * 1.6) - 0.5) * 2.0);
		return vec2(0.45 + furrow * 0.55, f);
	} else if (kind == 5) {   // rough rock
		float g = nz(uv * 0.07 * s) * 0.5 + nz(uv * 0.31 * s) * 0.3 + nz(uv * 1.3 * s) * 0.2;
		return vec2(0.6 + g * 0.4, g);
	}
	// planks: boards along u
	vec2 p = uv * vec2(0.35, 3.6) * s;
	float row = floor(p.y);
	float seam = smoothstep(0.0, 0.06, fract(p.y)) * smoothstep(1.0, 0.94, fract(p.y));
	float butt = smoothstep(0.0, 0.015, fract(p.x + hash12(vec2(row, 1.0))));
	float g = nz(vec2(uv.x * 0.1, uv.y * 3.0 + row * 1.7) * s);
	return vec2(seam * butt * (0.8 + g * 0.2), hash12(vec2(row, 5.0)) * 0.6 + g * 0.4);
}

void fragment() {
	vec3 an = abs(wn);
	vec3 w = pow(an, vec3(4.0));
	w /= (w.x + w.y + w.z);
	// Walls use (horizontal, height); floors/roofs use (x, z). Roofs use their slope direction.
	vec2 px = pattern(vec2(wp.z, wp.y), true);
	vec2 pz = pattern(vec2(wp.x, wp.y), true);
	vec2 py = pattern(kind == 3 ? vec2(wp.x + wp.z, wp.y * 1.6 + (wp.x - wp.z) * 0.0) : wp.xz, false);
	if (kind == 3) {
		// On sloped roofs, courses run horizontally: project on the dominant horizontal axis.
		vec2 a = pattern(vec2(wp.x, wp.y * 1.3), true);
		vec2 b = pattern(vec2(wp.z, wp.y * 1.3), true);
		py = an.x > an.z ? b : a;
	}
	vec2 p = px * w.x + py * w.y + pz * w.z;
	float n = nz(wp.xz * 0.05 + wp.y * 0.03);
	vec3 col = mix(base, base2, clamp(p.y * 0.8 + n * 0.4 - 0.2, 0.0, 1.0));
	col *= mix(0.42, 1.0, p.x);
	// Grime toward the ground and in crevices.
	col *= mix(0.78, 1.0, smoothstep(0.0, 1.6, wp.y - floor(wp.y / 400.0)) * 0.3 + 0.7);
	float up = clamp(wn.y, 0.0, 1.0);
	float mossy = moss * smoothstep(0.35, 0.85, up + (n - 0.5) * 0.7) * smoothstep(0.2, 0.8, 1.0 - p.x + n * 0.6);
	if (kind == 4 || kind == 5) mossy = max(mossy, moss * smoothstep(0.55, 0.75, n) * (1.0 - p.x) * 1.4);
	col = mix(col, moss_color * (0.8 + n * 0.4), clamp(mossy, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = clamp(rough + (1.0 - p.x) * 0.1, 0.0, 1.0);
	// Bump from the pattern: grooves read as recessed.
	float e = 0.02;
	vec2 pxx = pattern(vec2(wp.z + e, wp.y), true) * w.x + pattern(kind == 3 ? vec2(wp.x + e, wp.y * 1.3) : vec2(wp.x + e, wp.z), false) * w.y + pattern(vec2(wp.x + e, wp.y), true) * w.z;
	vec2 pyy = pattern(vec2(wp.z, wp.y + e), true) * w.x + pattern(kind == 3 ? vec2(wp.x, wp.y * 1.3 + e) : vec2(wp.x, wp.z + e), false) * w.y + pattern(vec2(wp.x, wp.y + e), true) * w.z;
	NORMAL_MAP = normalize(vec3((p.x - pxx.x) * 12.0, (p.x - pyy.x) * 12.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	AO = mix(0.7, 1.0, p.x);
	AO_LIGHT_AFFECT = 0.4;
}
