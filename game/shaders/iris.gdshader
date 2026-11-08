shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
// VRoid iris: each eye samples its own half of the iris texture, so the two halves can take
// different colours (heterochromia), and the iris can be shrunk around its centre (iris size).
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 col_a : source_color = vec4(1.0);
uniform vec4 col_b : source_color = vec4(1.0);
uniform float iris_scale = 1.0;

void fragment() {
	bool a = UV.x < 0.5;
	vec2 c = a ? vec2(0.2515, 0.508) : vec2(0.7476, 0.508);
	vec4 t = texture(tex, (UV - c) / iris_scale + c);
	ALBEDO = t.rgb * (a ? col_a.rgb : col_b.rgb);
	ALPHA = t.a;
	ROUGHNESS = 0.1;
	SPECULAR = 0.6;
}
