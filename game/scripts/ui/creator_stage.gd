class_name CreatorStage
extends Node3D
## The 3D side of character creation: the preview character, five viewing environments
## (the aetherial sea, a La Noscean coast, the Black Shroud, the Thanalan desert and an inn room),
## a time-of-day toggle, the orbit camera, and small head portraits for option grids.

const ENVS := ["Aetherial Sea", "La Noscea", "The Black Shroud", "Thanalan", "Inn Room"]
const ENV_COLORS := [["#0a2a6a", "#5ab0ff"], ["#3a7ad8", "#3f7a3a"], ["#2a4a2a", "#7aa04a"], ["#e0a060", "#b08048"], ["#3a2418", "#d8a060"]]
const TIMES := ["Day", "Dusk", "Night"]

var env_index := 0
var time_index := 0
var bg_rot := 0.0
var yaw := 0.0
var pitch := 6.0
var zoom := 0.0
var face_focus := false
var unique_pose := false
var preview: CharModel
var height_m := 1.6

var _we: WorldEnvironment
var _env: Environment
var _sky_mat: ShaderMaterial
var _scenery: Node3D
var _lights: Node3D
var _sun: DirectionalLight3D
var cam: Camera3D
var _target := Vector3(0, 0.9, 0)
var _dist := 3.5

# Portrait renderer
var _vp: SubViewport
var _vp_cam: Camera3D
var _vp_model: CharModel
var _thumbs: Array = []        # queue of {"ap": Dictionary, "cb": Callable}
var _thumb_job := {}
var _thumb_wait := 0
var _thumb_cache := {}


func _ready() -> void:
	_we = WorldEnvironment.new()
	_env = Environment.new()
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = 0.92
	_env.glow_enabled = true; _env.glow_intensity = 0.25; _env.glow_bloom = 0.0; _env.glow_hdr_threshold = 1.2
	_env.ssao_enabled = Settings.gfx.get("ssao", false); _env.ssao_intensity = 1.2; _env.ssao_radius = 0.5
	_env.adjustment_enabled = true; _env.adjustment_contrast = 1.05; _env.adjustment_saturation = 1.06
	_we.environment = _env
	add_child(_we)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://shaders/aether_sky.gdshader")
	_sky_mat.set_shader_parameter("linear_out", not Settings.is_compat())
	_scenery = Node3D.new(); add_child(_scenery)
	_lights = Node3D.new(); add_child(_lights)
	cam = Camera3D.new(); cam.fov = 32.0; cam.near = 0.05; cam.current = true
	add_child(cam)
	# Soft light from the viewer keeps faces readable in every environment.
	var fill := DirectionalLight3D.new(); fill.light_energy = 0.22; fill.light_color = Color("#dfe8ff")
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	cam.add_child(fill)
	_setup_portraits()
	set_environment(0)


# ----------------------------------------------------------------------------- environments
func set_environment(i: int) -> void:
	env_index = posmod(i, ENVS.size())
	for c in _scenery.get_children(): c.queue_free()
	for c in _lights.get_children(): c.queue_free()
	_sun = null
	_env.fog_enabled = false
	match env_index:
		0: _aether_sea()
		1: _outdoor("#6f8a3a", ["palm", "palm", "rock", "bush"], 9.0, 20.0, 14, true)
		2: _outdoor("#3a5528", ["broadleaf", "giant", "broadleaf", "bush", "bush"], 6.5, 24.0, 34, false)
		3: _outdoor("#c8a06a", ["cactus", "rock_sand", "rock_sand", "dead"], 8.0, 26.0, 16, false)
		4: _inn_room()
	_apply_time()


func cycle_time() -> void:
	time_index = (time_index + 1) % TIMES.size()
	_apply_time()


func _aether_sea() -> void:
	var sky := Sky.new(); sky.sky_material = _sky_mat; sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.background_mode = Environment.BG_SKY; _env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("#4a6aa0"); _env.ambient_light_energy = 0.35
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(9, 9)
	floor_mi.mesh = pm
	var fm := ShaderMaterial.new(); fm.shader = preload("res://shaders/aether_floor.gdshader")
	fm.set_shader_parameter("linear_out", not Settings.is_compat())
	floor_mi.material_override = fm
	floor_mi.position.y = 0.002
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scenery.add_child(floor_mi)
	# Drifting motes of aether.
	var p := CPUParticles3D.new()
	p.amount = 70; p.lifetime = 9.0; p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(7, 2.5, 3.5)
	p.position = Vector3(0, 2.0, -3.5)
	p.direction = Vector3.UP; p.spread = 30.0; p.initial_velocity_min = 0.05; p.initial_velocity_max = 0.2
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.4; p.scale_amount_max = 1.0
	var qm := QuadMesh.new(); qm.size = Vector2(0.035, 0.035)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.albedo_color = Color(0.5, 0.85, 1.0, 0.9)
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL; dot.fill_from = Vector2(0.5, 0.5); dot.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new(); dg.set_color(0, Color.WHITE); dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg; dot.width = 32; dot.height = 32
	mm.albedo_texture = dot
	qm.material = mm
	p.mesh = qm
	_scenery.add_child(p)
	_light(Color("#fff0e4"), 0.8, Vector3(-2.0, 3.0, 3.0), true)
	_light(Color("#5aa0ff"), 0.3, Vector3(3.0, 0.6, 1.8), false)
	_light(Color("#8ad8ff"), 0.9, Vector3(0.6, 2.2, -3.0), false)


func _outdoor(ground: String, kinds: Array, r_min: float, r_max: float, count: int, sea: bool) -> void:
	var sm := ProceduralSkyMaterial.new()
	var sky := Sky.new(); sky.sky_material = sm; sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.background_mode = Environment.BG_SKY; _env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; _env.ambient_light_energy = 0.7
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var g := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 34.0; cm.bottom_radius = 34.0; cm.height = 0.2; cm.radial_segments = 48
	g.mesh = cm; g.position.y = -0.1
	g.material_override = Props.pbr(ground, 0.95)
	_scenery.add_child(g)
	if sea:
		var w := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(600, 600)
		w.mesh = pm; w.position.y = -0.35
		var wm := Props.pbr("#2a6aa0", 0.08, 0.0); w.material_override = wm
		_scenery.add_child(w)
		g.scale = Vector3(0.62, 1, 0.62)
	var rng := RandomNumberGenerator.new(); rng.seed = 7 + env_index
	for i in count:
		var a := rng.randf() * TAU
		# Keep the space straight behind the camera's default view open.
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.5: a += 1.2
		var r := rng.randf_range(r_min, r_max)
		var mi := MeshInstance3D.new()
		mi.mesh = Props.mesh(kinds[i % kinds.size()])
		mi.position = Vector3(cos(a) * r, 0, sin(a) * r)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		_scenery.add_child(mi)
	_sun = _light(Color.WHITE, 1.2, Vector3(-3, 4, 2), true)
	_env.fog_enabled = true; _env.fog_density = 0.004
	_env.fog_light_color = Color("#9ab8d8") if env_index != 2 else Color("#7a9a6a")


func _inn_room() -> void:
	_env.background_mode = Environment.BG_COLOR; _env.background_color = Color("#1a120c")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("#6a4a32"); _env.ambient_light_energy = 0.45
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var bt := Batcher.new()
	var wood := Props.pbr("#5a3a24", 0.7)
	var wall := Props.pbr("#7a5a3e", 0.85)
	bt.box(Vector3(0, -0.05, 0), Vector3(12, 0.1, 12), "floor", wood, false)
	bt.box(Vector3(0, 2.5, -6), Vector3(12, 5, 0.3), "wall", wall, false)
	bt.box(Vector3(-6, 2.5, 0), Vector3(0.3, 5, 12), "wall", wall, false)
	bt.box(Vector3(6, 2.5, 0), Vector3(0.3, 5, 12), "wall", wall, false)
	bt.box(Vector3(0, 5.0, 0), Vector3(12, 0.2, 12), "wall", Props.pbr("#3a2618", 0.9), false)
	bt.box(Vector3(-4.2, 0.5, -4.6), Vector3(2.2, 1.0, 1.4), "bed", Props.pbr("#5a3a4a", 0.9), false)
	bt.box(Vector3(4.4, 0.45, -4.8), Vector3(1.2, 0.9, 0.8), "desk", Props.pbr("#4a2e1c", 0.6), false)
	bt.cyl(Vector3(0, 0.005, 0), 2.0, 0.01, "rug", Props.pbr("#4a2426", 0.95), false, 2.0, 32)
	bt.commit(_scenery)
	for p in [Vector3(-3, 3.2, -3), Vector3(3, 3.2, -3), Vector3(0, 3.4, 3)]:
		var o := OmniLight3D.new(); o.position = p; o.light_color = Color("#ffc890"); o.light_energy = 1.2; o.omni_range = 9.0
		o.shadow_enabled = p.z > 0
		_lights.add_child(o)
		var lamp := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.09; sp.height = 0.18
		lamp.mesh = sp; lamp.material_override = Props.glow("#ffc080", 4.0); lamp.position = p
		_scenery.add_child(lamp)


func _light(col: Color, energy: float, from: Vector3, shadow: bool) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = col; l.light_energy = energy; l.shadow_enabled = shadow
	l.directional_shadow_max_distance = 25.0
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_lights.add_child(l)
	l.look_at_from_position(from, Vector3(0, 1, 0), Vector3.UP)
	return l


func _apply_time() -> void:
	if _sun == null or not (_env.sky and _env.sky.sky_material is ProceduralSkyMaterial): return
	var sm: ProceduralSkyMaterial = _env.sky.sky_material
	var warm := env_index == 3
	match time_index:
		0:
			sm.sky_top_color = Color("#2f6ccc"); sm.sky_horizon_color = Color("#f0d8b0") if warm else Color("#a8c8e8")
			_sun.light_color = Color("#fff2dc"); _sun.light_energy = 1.0
			_sun.look_at_from_position(Vector3(-3, 4.5, 2.5), Vector3.ZERO, Vector3.UP)
			_env.ambient_light_energy = 0.45
		1:
			sm.sky_top_color = Color("#2a3a6a"); sm.sky_horizon_color = Color("#f0905a")
			_sun.light_color = Color("#ffa060"); _sun.light_energy = 0.9
			_sun.look_at_from_position(Vector3(-5, 1.0, 1.5), Vector3.ZERO, Vector3.UP)
			_env.ambient_light_energy = 0.35
		2:
			sm.sky_top_color = Color("#040812"); sm.sky_horizon_color = Color("#1a2440")
			_sun.light_color = Color("#8aa0ff"); _sun.light_energy = 0.4
			_sun.look_at_from_position(Vector3(2, 4, 3), Vector3.ZERO, Vector3.UP)
			_env.ambient_light_energy = 0.3
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = sm.sky_horizon_color.darkened(0.6)
	_env.fog_light_color = sm.sky_horizon_color.darkened(0.2)


# ----------------------------------------------------------------------------- character
func show_character(ap: Dictionary, gear: Dictionary) -> void:
	if preview: preview.queue_free()
	preview = CharModel.new()
	add_child(preview)
	preview.build(ap, gear)
	preview.set_drawn(false)
	preview.rotation.y = PI
	preview.play("idle_combat" if unique_pose else "idle", 0.0)
	height_m = maxf(0.4, preview.head_pos().y + 0.11 * preview.scale.y)


func set_pose(unique: bool) -> void:
	unique_pose = unique
	if preview: preview.play("idle_combat" if unique else "idle", 0.3)


## Displayed height in centimetres (Hyur Midlanders land around 160-175).
func height_cm() -> int:
	return int(round(height_m * 97.0))


func _process(delta: float) -> void:
	_env.sky_rotation = Vector3(0, bg_rot, 0)
	_scenery.rotation.y = bg_rot
	_lights.rotation.y = bg_rot
	if _sky_mat: _sky_mat.set_shader_parameter("rot", bg_rot)
	if preview:
		var body_t := Vector3(0, height_m * 0.52, 0)
		var face_t := preview.head_pos() - Vector3(0, 0.1 * preview.scale.y, 0)
		var want_t := face_t if face_focus else body_t
		var base := (0.62 * preview.scale.y + 0.25) if face_focus else (height_m * 0.62 + 0.25) / tan(deg_to_rad(16.0))
		if face_focus: base = maxf(0.75, 1.05 * minf(preview.scale.y, 1.25))
		var want_d := base * lerpf(1.0, 0.42, zoom)
		var k := clampf(delta * 6.0, 0.0, 1.0)
		_target = _target.lerp(want_t, k)
		_dist = lerpf(_dist, want_d, k)
	var dir := Vector3(sin(yaw) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)), cos(yaw) * cos(deg_to_rad(pitch)))
	cam.position = _target + dir * _dist
	cam.look_at(_target, Vector3.UP)
	_process_portraits()


# ----------------------------------------------------------------------------- portraits
func _setup_portraits() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(112, 112)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("#0b2346")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("#8aa8d8"); e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = e; _vp.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 1.2; key.light_color = Color("#fff4e8")
	_vp.add_child(key); key.look_at_from_position(Vector3(-1, 1.5, 2), Vector3.ZERO, Vector3.UP)
	var rim := DirectionalLight3D.new(); rim.light_energy = 0.8; rim.light_color = Color("#8ad0ff")
	_vp.add_child(rim); rim.look_at_from_position(Vector3(1, 1, -2), Vector3.ZERO, Vector3.UP)
	_vp_cam = Camera3D.new(); _vp_cam.fov = 24.0; _vp_cam.current = true
	_vp.add_child(_vp_cam)


## Renders a head-and-shoulders portrait of `ap` and calls cb(texture) when ready.
func portrait(ap: Dictionary, cb: Callable, wide := false) -> void:
	var key := str(ap.hash()) + ("w" if wide else "")
	if _thumb_cache.has(key):
		cb.call(_thumb_cache[key])
		return
	_thumbs.append({"ap": ap, "cb": cb, "key": key, "wide": wide})


func clear_portrait_queue() -> void:
	_thumbs.clear()


func _process_portraits() -> void:
	if not _thumb_job.is_empty():
		_thumb_wait -= 1
		if _thumb_wait == 1:
			var s := _vp_model.scale.y
			var d := (0.62 * s + 0.1) if _thumb_job["wide"] else (0.36 * s + 0.06)
			var t := _vp_model.head_pos() - Vector3(0, (0.04 if _thumb_job["wide"] else 0.035) * s, 0)
			_vp_cam.look_at_from_position(t + Vector3(0, 0.005, d), t)
		if _thumb_wait <= 0:
			var tex := ImageTexture.create_from_image(_vp.get_texture().get_image())
			_thumb_cache[_thumb_job["key"]] = tex
			if _thumb_cache.size() > 160: _thumb_cache.clear()
			_thumb_job["cb"].call(tex)
			_thumb_job = {}
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _thumbs.is_empty(): return
	_thumb_job = _thumbs.pop_front()
	if _vp_model: _vp_model.free()
	_vp_model = CharModel.new()
	_vp.add_child(_vp_model)
	_vp_model.build(_thumb_job["ap"], {})
	_vp_model.rotation.y = PI
	_vp_model.play("idle", 0.0)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_thumb_wait = 3
