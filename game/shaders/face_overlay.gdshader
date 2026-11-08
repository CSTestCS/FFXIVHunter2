shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// Drawn as a second pass over the face skin. Lip colour, face paint, tattoos and facial features
// are painted procedurally in the standard VRoid face UV layout (front projection: eyes near
// v = 0.54, nose tip v = 0.64, mouth v = 0.755), so no extra textures are needed.
uniform vec4 lip_color : source_color = vec4(0.72, 0.42, 0.42, 1.0);
uniform float lip_amount = 0.55;
uniform int paint = 0;
uniform vec4 paint_color : source_color = vec4(0.6, 0.1, 0.1, 1.0);
uniform int tattoo = 0;
uniform vec4 tattoo_color : source_color = vec4(0.15, 0.2, 0.35, 1.0);
uniform int feature = 0;
uniform vec4 feature_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float line(vec2 p, vec2 a, vec2 b, float w) {
	return 1.0 - smoothstep(w * 0.6, w, seg(p, a, b));
}

float dot_at(vec2 p, vec2 c, float r) {
	return 1.0 - smoothstep(r * 0.7, r, length(p - c));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// q: mirrored coordinates (x = distance from the face centre line, y = down the face).
float paint_mask(vec2 q) {
	if (paint == 1) {   // Cheek Stripes
		return max(line(q, vec2(0.30, 0.615), vec2(0.20, 0.64), 0.009), line(q, vec2(0.30, 0.65), vec2(0.20, 0.675), 0.009));
	} else if (paint == 2) {   // Eye Mask
		float band = (1.0 - smoothstep(0.045, 0.06, abs(q.y - 0.535 + q.x * 0.08))) * (1.0 - smoothstep(0.30, 0.33, q.x));
		return band;
	} else if (paint == 3) {   // Tear Lines
		return max(line(q, vec2(0.15, 0.585), vec2(0.165, 0.71), 0.006), line(q, vec2(0.19, 0.585), vec2(0.205, 0.66), 0.005));
	} else if (paint == 4) {   // Forehead Mark
		vec2 d = abs(q - vec2(0.0, 0.36)) / vec2(0.03, 0.055);
		return max(1.0 - smoothstep(0.85, 1.0, d.x + d.y), dot_at(q, vec2(0.0, 0.445), 0.008));
	} else if (paint == 5) {   // War Paint
		return max(line(q, vec2(0.05, 0.605), vec2(0.31, 0.565), 0.017), line(q, vec2(0.0, 0.8), vec2(0.0, 0.9), 0.012));
	}
	return 0.0;
}

float tattoo_mask(vec2 q) {
	if (tattoo == 1) {   // Temple Lines
		return max(line(q, vec2(0.27, 0.47), vec2(0.34, 0.40), 0.005), line(q, vec2(0.29, 0.51), vec2(0.37, 0.45), 0.005));
	} else if (tattoo == 2) {   // Eye Rings
		return 1.0 - smoothstep(0.003, 0.006, abs(length((q - vec2(0.16, 0.54)) * vec2(1.0, 1.5)) - 0.085));
	} else if (tattoo == 3) {   // Chin Lines
		return max(line(q, vec2(0.0, 0.79), vec2(0.0, 0.87), 0.005), line(q, vec2(0.03, 0.79), vec2(0.035, 0.85), 0.004));
	} else if (tattoo == 4) {   // Temple Swirl
		vec2 d = q - vec2(0.31, 0.44);
		float r = length(d);
		float a = atan(d.y, d.x);
		float s = abs(fract((r * 130.0 - a / 6.2832) ) - 0.5);
		return (1.0 - smoothstep(0.12, 0.2, s)) * (1.0 - smoothstep(0.035, 0.045, r));
	} else if (tattoo == 5) {   // Cheek Dots
		float m = 0.0;
		for (int i = 0; i < 3; i++) m = max(m, dot_at(q, vec2(0.12 + float(i) * 0.04, 0.625 + float(i) * 0.006), 0.008));
		return m;
	}
	return 0.0;
}

void fragment() {
	vec2 uv = UV;
	vec2 q = vec2(abs(uv.x - 0.5), uv.y);
	vec3 col = vec3(0.0);
	float a = 0.0;
	// Lips: a soft ellipse along the mouth line.
	vec2 ld = (uv - vec2(0.5, 0.757)) / vec2(0.062, 0.016);
	float lip = (1.0 - smoothstep(0.55, 1.0, length(ld))) * lip_amount;
	col = lip_color.rgb; a = lip;
	float t = tattoo_mask(q) * 0.85;
	col = mix(col, tattoo_color.rgb, t); a = max(a, t);
	float p = paint_mask(q) * 0.9;
	col = mix(col, paint_color.rgb, p); a = max(a, p);
	float f = 0.0;
	vec3 fc = feature_color.rgb;
	if (feature == 1) {   // Freckles
		vec2 cell = floor(uv / 0.013);
		vec2 c = (cell + 0.25 + 0.5 * vec2(hash(cell), hash(cell + 7.0))) * 0.013;
		float region = 1.0 - smoothstep(0.6, 1.0, length((uv - vec2(0.5, 0.625)) / vec2(0.21, 0.055)));
		f = step(0.55, hash(cell + 3.1)) * dot_at(uv, c, 0.0032) * region * 0.6;
		fc = vec3(0.42, 0.26, 0.18);
	} else if (feature == 2) {   // Beauty Mark
		f = dot_at(uv, vec2(0.585, 0.715), 0.0045) * 0.9;
		fc = vec3(0.2, 0.12, 0.1);
	} else if (feature == 3) {   // Scar
		f = line(uv, vec2(0.28, 0.45), vec2(0.37, 0.67), 0.0045) * 0.6;
		fc = vec3(0.86, 0.62, 0.6);
	} else if (feature == 4) {   // Scales
		vec2 cell = floor(q / vec2(0.016, 0.012));
		vec2 local = fract(q / vec2(0.016, 0.012)) - 0.5;
		float region = 1.0 - smoothstep(0.035, 0.07, length((q - vec2(0.30, 0.56)) * vec2(1.0, 0.8)));
		f = (1.0 - smoothstep(0.32, 0.45, length(local * vec2(1.0, 1.3)))) * region * step(0.25, hash(cell));
	} else if (feature == 5) {   // Whisker Marks
		for (int i = 0; i < 3; i++) f = max(f, line(q, vec2(0.12, 0.655 + float(i) * 0.018), vec2(0.25, 0.64 + float(i) * 0.03), 0.0035));
		f *= 0.75;
		fc = fc * 0.6;
	}
	col = mix(col, fc, f); a = max(a, f);
	if (a < 0.01) discard;
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = 0.6;
}
