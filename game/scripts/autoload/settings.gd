extends Node
## Player options. Graphics presets favour stable frame rate; expensive effects are opt-in.

signal changed

const PATH := "user://settings.cfg"
const PRESETS := {
	"Low": {"shadows": 0, "ssao": false, "ssil": false, "ssr": false, "glow": false, "fog": false, "scale": 0.75, "aa": 1, "draw": 0.6, "grass": 0.3, "sss": false},
	"Medium": {"shadows": 1, "ssao": false, "ssil": false, "ssr": false, "glow": true, "fog": false, "scale": 1.0, "aa": 1, "draw": 0.8, "grass": 0.6, "sss": false},
	"High": {"shadows": 2, "ssao": true, "ssil": false, "ssr": false, "glow": true, "fog": true, "scale": 1.0, "aa": 2, "draw": 1.0, "grass": 1.0, "sss": true},
	"Ultra": {"shadows": 3, "ssao": true, "ssil": true, "ssr": true, "glow": true, "fog": true, "scale": 1.0, "aa": 2, "draw": 1.3, "grass": 1.3, "sss": true},
}

var v := {
	"preset": "High", "fullscreen": true, "vsync": true, "fps_cap": 0,
	"master": 0.8, "sfx": 0.9, "music": 0.6,
	"fov": 70.0, "sens": 1.0, "invert_y": false, "aoe_markers": true, "text_speed": 1.0, "cam_shake": 1.0,
}
var gfx: Dictionary = PRESETS["High"].duplicate()


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in v: v[k] = cf.get_value("opt", k, v[k])
	apply()


func save() -> void:
	var cf := ConfigFile.new()
	for k in v: cf.set_value("opt", k, v[k])
	cf.save(PATH)


func set_opt(k: String, val) -> void:
	v[k] = val
	apply()
	save()


func apply() -> void:
	gfx = PRESETS.get(v["preset"], PRESETS["High"]).duplicate()
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v["fps_cap"])
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if gfx["scale"] < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = gfx["scale"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if gfx["aa"] >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = gfx["aa"] >= 2
	vp.mesh_lod_threshold = 1.0 if gfx["draw"] >= 1.0 else 2.5
	var sh: int = [1024, 2048, 4096, 4096][gfx["shadows"]]
	RenderingServer.directional_shadow_atlas_set_size(sh, true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][gfx["shadows"]])
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(0.0001, v["master"])))
	changed.emit()


## Called by the world to configure its environment for the current preset.
func apply_env(env: Environment, sun: DirectionalLight3D) -> void:
	env.ssao_enabled = gfx["ssao"]
	env.ssil_enabled = gfx["ssil"]
	env.ssr_enabled = gfx["ssr"]
	env.glow_enabled = gfx["glow"]
	env.volumetric_fog_enabled = gfx["fog"]
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = [50.0, 80.0, 120.0, 180.0][gfx["shadows"]]
		sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][gfx["shadows"]]
