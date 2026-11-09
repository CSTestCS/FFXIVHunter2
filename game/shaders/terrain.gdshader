shader_type spatial;
// Terrain: blends ground layers by slope, height and a painted road mask (vertex colour R).
// Detail comes from one tiny tiling noise texture sampled at two scales (no texture files).
uniform vec3 grass_a : source_color = vec3(0.24, 0.36, 0.12);
uniform vec3 grass_b : source_color = vec3(0.34, 0.42, 0.16);
uniform vec3 dirt : source_color = vec3(0.38, 0.30, 0.2);
uniform vec3 rock : source_color = vec3(0.42, 0.40, 0.38);
uniform vec3 top : source_color = vec3(0.92, 0.94, 0.98);
uniform vec3 shore : source_color = vec3(0.76, 0.69, 0.5);
uniform float top_height = 999.0;
uniform float shore_height = -999.0;
uniform bool cobble = false;   // city streets: laid stones instead of packed dirt
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.05).r;
	float n2 = texture(noise_tex, wpos.xz * 0.37).r;
	float n3 = texture(noise_tex, wpos.xz * 1.9).r;
	float slope = 1.0 - wnrm.y;
	vec3 g = mix(grass_a, grass_b, smoothstep(0.3, 0.7, n1));
	g *= 0.85 + n3 * 0.3;
	vec3 col = g;
	col = mix(col, dirt * (0.85 + n2 * 0.3), smoothstep(0.45, 0.6, n2 * 0.6 + slope * 1.3));
	col = mix(col, rock * (0.8 + n3 * 0.4), smoothstep(0.22, 0.38, slope + (n2 - 0.5) * 0.15));
	col = mix(col, shore * (0.9 + n3 * 0.2), smoothstep(shore_height + 1.2, shore_height, wpos.y));
	col = mix(col, top * (0.94 + n3 * 0.08), smoothstep(top_height - 3.0, top_height + 3.0, wpos.y + n1 * 6.0) * (1.0 - smoothstep(0.35, 0.55, slope)));
	float road = smoothstep(0.25, 0.75, COLOR.r + (n2 - 0.5) * 0.3);
	float stones = 1.0;
	if (cobble) {
		// Rounded setts on a jittered grid; mortar between them, worn edges toward the verges.
		vec2 g = wpos.xz * 2.2;
		vec2 cell = floor(g);
		float best = 9.0; float second = 9.0; float id = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cc = cell + vec2(float(i), float(j));
				vec2 jit = vec2(texture(noise_tex, cc * 0.137).r, texture(noise_tex, cc * 0.137 + 0.5).r);
				float d = length(g - cc - 0.2 - jit * 0.6);
				if (d < best) { second = best; best = d; id = jit.x; }
				else if (d < second) { second = d; }
			}
		}
		stones = smoothstep(0.02, 0.16, second - best);
		vec3 sett = mix(vec3(0.46, 0.43, 0.38), vec3(0.58, 0.54, 0.46), id) * (0.85 + n3 * 0.25);
		vec3 paved = mix(dirt * 0.7, sett, stones);
		col = mix(col, paved, road);
	} else {
		col = mix(col, dirt * 1.08 * (0.9 + n3 * 0.2), road);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.92, cobble ? mix(0.95, 0.7, stones) : 0.75, road) - smoothstep(top_height - 3.0, top_height, wpos.y) * 0.25;
	// Cheap micro-normal from the detail noise.
	float dx = texture(noise_tex, wpos.xz * 1.9 + vec2(0.01, 0.0)).r - n3;
	float dz = texture(noise_tex, wpos.xz * 1.9 + vec2(0.0, 0.01)).r - n3;
	NORMAL_MAP = normalize(vec3(-dx * 6.0, -dz * 6.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
}
