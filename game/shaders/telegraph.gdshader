shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Ground attack marker draped over the terrain. The fill grows from the origin as the attack
// winds up. Vertices are nudged toward the camera so the marker never sinks into the ground.
uniform sampler2D shape_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform float progress = 0.0;
uniform bool linear_fill = false;

void vertex() {
	vec3 vv = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vv -= normalize(vv) * 0.12;
	POSITION = PROJECTION_MATRIX * vec4(vv, 1.0);
}

void fragment() {
	float shape = texture(shape_tex, UV).a;
	float d = linear_fill ? (1.0 - UV.y) : length(UV - 0.5) * 2.0;
	float filled = step(d, progress);
	vec3 col = mix(tint.rgb, mix(tint.rgb, vec3(1.0), 0.3), filled);
	ALBEDO = col;
	ALPHA = shape * mix(0.42, 0.72, filled) * tint.a;
}
