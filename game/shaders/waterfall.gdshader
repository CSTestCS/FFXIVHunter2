shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Falling water: streaks scroll down the sheet, thinning into spray at the edges and foaming white
// where it lands.
uniform vec3 color : source_color = vec3(0.78, 0.9, 0.95);
uniform float speed = 0.9;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

void fragment() {
	float s1 = texture(noise_tex, vec2(UV.x * 1.5, UV.y * 0.25 - TIME * speed * 0.35)).r;
	float s2 = texture(noise_tex, vec2(UV.x * 4.0 + 0.3, UV.y * 0.5 - TIME * speed * 0.6)).r;
	float streak = smoothstep(0.35, 0.75, s1 * 0.6 + s2 * 0.6);
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float foot = smoothstep(0.75, 1.0, UV.y);
	ALBEDO = mix(color * 0.85, vec3(1.0), streak * 0.5 + foot * 0.6);
	ALPHA = clamp((0.45 + streak * 0.5) * edge + foot * 0.35, 0.0, 0.95);
	ROUGHNESS = 0.15;
	EMISSION = vec3(0.08, 0.1, 0.11) * streak;
}
