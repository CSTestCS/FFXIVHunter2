shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Water: depth-based colour and opacity, fresnel, two scrolling normal layers, shoreline foam.
uniform vec3 shallow : source_color = vec3(0.18, 0.55, 0.6);
uniform vec3 deep : source_color = vec3(0.04, 0.2, 0.3);
uniform float clarity = 6.0;
uniform float wave_speed = 0.04;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.35 + TIME * 1.1) * 0.06 + cos(w.z * 0.27 + TIME * 0.8) * 0.06;
}

void fragment() {
	vec3 wv = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = wv.xz;
	float a = texture(noise_tex, uv * 0.06 + vec2(TIME * wave_speed, TIME * wave_speed * 0.6)).r;
	float b = texture(noise_tex, uv * 0.11 - vec2(TIME * wave_speed * 0.8, TIME * wave_speed * 1.1)).r;
	float ax = texture(noise_tex, uv * 0.06 + vec2(TIME * wave_speed + 0.01, TIME * wave_speed * 0.6)).r - a;
	float az = texture(noise_tex, uv * 0.11 - vec2(TIME * wave_speed * 0.8, TIME * wave_speed * 1.1 - 0.01)).r - b;
	NORMAL_MAP = normalize(vec3(ax * 10.0, az * 10.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 vp = INV_PROJECTION_MATRIX * ndc;
	vp.xyz /= vp.w;
	float thickness = clamp(VERTEX.z - vp.z, 0.0, 100.0);
	float t = 1.0 - exp(-thickness / clarity);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float foam = (1.0 - smoothstep(0.0, 0.6, thickness)) * smoothstep(0.35, 0.7, a + b * 0.5);
	ALBEDO = mix(shallow, deep, t) + vec3(foam * 0.8);
	ALPHA = clamp(mix(0.3, 0.88, t) + fres * 0.25 + foam, 0.0, 1.0);
	ROUGHNESS = 0.04 + foam * 0.6;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
