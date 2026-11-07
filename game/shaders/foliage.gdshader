shader_type spatial;
render_mode cull_disabled;
// Foliage cards & leaves: alpha-scissor (no sorting cost) with vertex wind sway weighted by height.
uniform vec3 tint : source_color = vec3(0.3, 0.45, 0.15);
uniform vec3 tint2 : source_color = vec3(0.45, 0.55, 0.2);
uniform float sway = 0.12;
uniform float cutoff = 0.5;
uniform bool cards = false;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
varying float h;
varying vec3 wp;

void vertex() {
	h = clamp(VERTEX.y, 0.0, 4.0);
	wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = sin(TIME * 1.7 + wp.x * 0.3 + wp.z * 0.2) * sway * h;
	VERTEX.x += w;
	VERTEX.z += w * 0.6;
}

void fragment() {
	float n = texture(noise_tex, wp.xz * 0.02 + UV * 0.5).r;
	vec3 c = mix(tint, tint2, n);
	if (cards) {
		// Procedural blade shape from UV so grass needs no texture.
		float blade = abs(fract(UV.x * 3.0) - 0.5) * 2.0;
		if (blade > (1.0 - UV.y) * 0.9 + 0.05) discard;
		c *= mix(0.55, 1.1, 1.0 - UV.y);
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.35;
}
