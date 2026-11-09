shader_type spatial;
render_mode cull_disabled;
// Leaf cards for the forest kit. Each card holds a small spray of leaves (mode 0) or a fern frond
// (mode 1), cut procedurally from UV, so no textures ship. Alpha-scissored to avoid sorting.
// Vertex colour R weights wind sway (tips move, the base stays put).
uniform int mode = 0;
uniform vec3 tint : source_color = vec3(0.22, 0.36, 0.12);
uniform vec3 tint2 : source_color = vec3(0.38, 0.5, 0.16);
uniform vec3 tint3 : source_color = vec3(0.55, 0.52, 0.18);
uniform float sway = 0.15;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
varying float vsway;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vsway = COLOR.r;
	float t = TIME;
	float s = sin(t * 1.3 + wp.x * 0.13 + wp.z * 0.11) * 0.6 + sin(t * 2.7 + wp.y * 0.4 + wp.x * 0.3) * 0.4;
	VERTEX += vec3(s, s * 0.25, s * 0.6) * sway * COLOR.r;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 c;
	float shade = 1.0;
	if (mode == 0) {
		// A spray of overlapping pointed-oval leaves on a 3x3 jittered grid.
		vec2 g = UV * 3.0;
		vec2 cell = floor(g);
		float best = 9.0;
		float pick = 0.0;
		float vein = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cc = cell + vec2(float(i), float(j));
				float h = hash12(cc);
				vec2 ctr = cc + 0.5 + (vec2(hash12(cc + 3.7), hash12(cc + 9.1)) - 0.5) * 0.6;
				float a = h * 6.2832;
				vec2 d = g - ctr;
				vec2 l = vec2(cos(a) * d.x + sin(a) * d.y, -sin(a) * d.x + cos(a) * d.y);
				// Pointed oval: narrower toward the tip.
				float wdt = 0.27 * (1.0 - smoothstep(-0.2, 0.75, l.x) * 0.6);
				float e = length(vec2(l.x / 0.72, l.y / max(wdt, 0.05)));
				if (e < best) { best = e; pick = h; vein = abs(l.y) / max(wdt, 0.05); }
			}
		}
		float edge = length(UV - 0.5) * 2.0;
		if (best > 1.0 || edge > 1.05) discard;
		c = mix(tint, tint2, pick);
		c = mix(c, tint3, smoothstep(0.82, 1.0, pick) * 0.6);
		shade = mix(0.75, 1.05, 1.0 - best) * mix(0.85, 1.0, smoothstep(0.0, 0.15, vein));
	} else if (mode == 2) {
		// Blossoms: five-petalled flowers on a jittered grid, with pale centres.
		vec2 g = UV * 2.5;
		vec2 cell = floor(g);
		vec2 f = fract(g) - 0.5 - (vec2(hash12(cell), hash12(cell + 4.3)) - 0.5) * 0.3;
		float r = length(f);
		float a = atan(f.y, f.x) + hash12(cell + 1.9) * 6.2832;
		float petal = 0.32 + 0.12 * cos(a * 5.0);
		if (r > petal || length(UV - 0.5) > 0.55) discard;
		c = mix(tint, tint2, smoothstep(0.0, petal, r) * hash12(cell + 7.7));
		c = mix(tint3, c, smoothstep(0.05, 0.11, r));
		shade = mix(1.05, 0.8, r / petal);
	} else {
		// Fern frond: a central stem with tapering leaflets along UV.y.
		float y = UV.y;
		float x = abs(UV.x - 0.5) * 2.0;
		float taper = (1.0 - y) * 0.9 + 0.1;
		float seg = fract(y * 14.0);
		float leaflet = smoothstep(0.0, 0.5, seg) * smoothstep(1.0, 0.55, seg);
		float reach = taper * mix(0.35, 1.0, leaflet);
		if (x > reach && x > 0.05) discard;
		c = mix(tint, tint2, y + hash12(floor(vec2(y * 14.0, UV.x * 2.0))) * 0.3);
		shade = mix(0.7, 1.0, 1.0 - x);
	}
	float n = texture(noise_tex, wp.xz * 0.03).r;
	ALBEDO = c * shade * (0.85 + n * 0.3);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	BACKLIGHT = ALBEDO * 0.55;
}
