shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft shafts of sunlight falling through gaps in the canopy, fading at the ends, at the edges and
// near the camera, with a slow shimmer.
uniform vec3 color : source_color = vec3(1.0, 0.94, 0.75);
uniform float strength = 0.16;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float shimmer = texture(noise_tex, vec2(UV.x * 0.6 + TIME * 0.01, UV.y * 0.15 - TIME * 0.02) + wp.xz * 0.01).r;
	float near = smoothstep(2.0, 10.0, length(VERTEX));
	ALBEDO = color;
	ALPHA = clamp(pow(across, 2.0) * along * (0.5 + shimmer * 0.8) * near * strength, 0.0, 1.0);
}
