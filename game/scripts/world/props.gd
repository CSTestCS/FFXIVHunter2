class_name Props
## Shared prop meshes and materials (trees, rocks, crystals, grass). Built once and cached;
## placed with MultiMesh so thousands of instances cost a few draw calls.

static var _cache := {}
static var noise_tex: NoiseTexture2D


static func noise() -> NoiseTexture2D:
	if noise_tex == null:
		noise_tex = NoiseTexture2D.new()
		noise_tex.width = 256; noise_tex.height = 256
		noise_tex.seamless = true
		noise_tex.generate_mipmaps = true
		var n := FastNoiseLite.new(); n.frequency = 0.03; n.fractal_octaves = 4
		noise_tex.noise = n
	return noise_tex


static func pbr(hex: String, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "m|%s|%s|%s" % [hex, rough, metal]
	if _cache.has(key): return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex); m.roughness = rough; m.metallic = metal
	_cache[key] = m
	return m


static func glow(hex: String, energy := 2.0) -> StandardMaterial3D:
	var key := "g|%s|%s" % [hex, energy]
	if _cache.has(key): return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex); m.emission_enabled = true; m.emission = Color(hex); m.emission_energy_multiplier = energy
	m.roughness = 0.15; m.metallic_specular = 0.9
	_cache[key] = m
	return m


static func leaves(a: String, b: String, cards := false, sway := 0.06) -> ShaderMaterial:
	var key := "l|%s|%s|%s|%s" % [a, b, cards, sway]
	if _cache.has(key): return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("tint", Color(a)); m.set_shader_parameter("tint2", Color(b))
	m.set_shader_parameter("cards", cards); m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("noise_tex", noise())
	_cache[key] = m
	return m


## Combines primitives into one mesh with up to two materials (wood/bark + leaves/other).
static func _compose(parts: Array) -> ArrayMesh:
	var groups := {}
	for p in parts:
		var mat: Material = p[2]
		var k := mat.get_instance_id()
		if not groups.has(k):
			var s := SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); groups[k] = [s, mat]
		groups[k][0].append_from(p[0], 0, p[1])
	var am: ArrayMesh = null
	for k in groups:
		groups[k][0].set_material(groups[k][1])
		am = groups[k][0].commit(am)
	return am


static func _x(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot * (PI / 180.0)).scaled(scl), pos)


static func _sph(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = maxi(4, seg / 2); return s


static func _cyl(r: float, h: float, r2 := -1.0, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new(); c.bottom_radius = r; c.top_radius = r if r2 < 0 else r2; c.height = h; c.radial_segments = seg; c.rings = 1; return c


static func mesh(kind: String) -> Mesh:
	if _cache.has(kind): return _cache[kind]
	var bark := pbr("#4a3626", 0.9)
	var m: Mesh
	match kind:
		"broadleaf":
			var lv := leaves("#2f4f1c", "#5a7a2a")
			m = _compose([[_cyl(0.28, 5.0, 0.18), _x(Vector3(0, 2.5, 0)), bark],
				[_sph(2.4), _x(Vector3(0, 5.6, 0), Vector3.ZERO, Vector3(1, 0.8, 1)), lv],
				[_sph(1.8), _x(Vector3(1.3, 4.8, 0.4)), lv], [_sph(1.7), _x(Vector3(-1.1, 5.0, -0.6)), lv]])
		"giant":
			var lv := leaves("#2a4818", "#4c6c22")
			m = _compose([[_cyl(1.6, 22.0, 0.9, 12), _x(Vector3(0, 11.0, 0)), bark],
				[_cyl(0.5, 7.0, 0.2), _x(Vector3(3, 15, 0), Vector3(0, 0, -50)), bark],
				[_sph(7.0, 12), _x(Vector3(0, 23, 0), Vector3.ZERO, Vector3(1, 0.6, 1)), lv],
				[_sph(5.0, 12), _x(Vector3(5, 18, 2)), lv], [_sph(5.0, 12), _x(Vector3(-4, 19, -3)), lv]])
		"conifer", "conifer_snow":
			var lv := leaves("#1f3a24", "#2e4c2c") if kind == "conifer" else leaves("#dfe8ee", "#a9bfc0", false, 0.02)
			m = _compose([[_cyl(0.22, 3.0, 0.15), _x(Vector3(0, 1.5, 0)), bark],
				[_cyl(2.0, 3.0, 0.2), _x(Vector3(0, 3.2, 0)), lv], [_cyl(1.6, 2.6, 0.1), _x(Vector3(0, 5.0, 0)), lv],
				[_cyl(1.1, 2.2, 0.02), _x(Vector3(0, 6.6, 0)), lv]])
		"palm":
			var lv := leaves("#3a6a24", "#6a9a34", false, 0.1)
			var parts := []
			for i in 5:
				parts.append([_cyl(0.18 - i * 0.015, 1.4), _x(Vector3(i * i * 0.05, 0.7 + i * 1.35, 0), Vector3(0, 0, -i * 4.0)), bark])
			for k in 7:
				parts.append([BoxMesh.new(), _x(Vector3(1.6, 0, 0).rotated(Vector3.UP, k * TAU / 7.0) + Vector3(1.2, 7.0, 0), Vector3(0, k * 360.0 / 7.0, -25), Vector3(3.2, 0.05, 0.7)), lv])
			m = _compose(parts)
		"dead":
			m = _compose([[_cyl(0.22, 4.0, 0.08), _x(Vector3(0, 2.0, 0)), pbr("#5a4a3c", 0.95)],
				[_cyl(0.08, 2.0, 0.02), _x(Vector3(0.6, 3.0, 0), Vector3(0, 0, -45)), pbr("#5a4a3c", 0.95)],
				[_cyl(0.07, 1.6, 0.02), _x(Vector3(-0.5, 2.5, 0.2), Vector3(20, 0, 50)), pbr("#5a4a3c", 0.95)]])
		"cactus":
			var g := pbr("#4f7a34", 0.7)
			m = _compose([[_cyl(0.32, 3.4, 0.28), _x(Vector3(0, 1.7, 0)), g], [_sph(0.3), _x(Vector3(0, 3.4, 0)), g],
				[_cyl(0.18, 1.2), _x(Vector3(0.55, 1.8, 0), Vector3(0, 0, 0)), g], [_cyl(0.15, 0.5), _x(Vector3(0.35, 1.3, 0), Vector3(0, 0, 90)), g]])
		"rock", "rock_snow", "rock_sand", "rock_dark":
			var col = {"rock": "#6e6a64", "rock_snow": "#8a8e94", "rock_sand": "#b08a5e", "rock_dark": "#4a4650"}[kind]
			m = _rock(pbr(col, 0.9), 1)
		"boulder":
			m = _rock(pbr("#77736c", 0.9), 2)
		"crystal":
			var c := glow("#9a7cff", 2.2)
			var parts := []
			for i in 4:
				var pm := PrismMesh.new(); pm.size = Vector3(0.8, 4.0 + i, 0.8)
				parts.append([pm, _x(Vector3(sin(i * 2.0) * 0.8, 2.0 + i * 0.5, cos(i * 2.0) * 0.8), Vector3(sin(i) * 15, i * 40, cos(i) * 15)), c])
			m = _compose(parts)
		"bush":
			var lv := leaves("#2c4a1e", "#4e6e28")
			m = _compose([[_sph(0.8, 8), _x(Vector3(0, 0.5, 0)), lv], [_sph(0.6, 8), _x(Vector3(0.6, 0.4, 0.2)), lv], [_sph(0.55, 8), _x(Vector3(-0.5, 0.35, -0.3)), lv]])
		"grass", "grass_dry", "grass_snow":
			var cols = {"grass": ["#3a5a1c", "#6a8a30"], "grass_dry": ["#8a7a4a", "#b8a060"], "grass_snow": ["#9aa89a", "#c8d0c8"]}[kind]
			var lv := leaves(cols[0], cols[1], true, 0.15)
			var parts := []
			for i in 3:
				var q := QuadMesh.new(); q.size = Vector2(1.1, 0.7); q.center_offset = Vector3(0, 0.35, 0)
				parts.append([q, _x(Vector3.ZERO, Vector3(0, i * 60.0, 0)), lv])
			m = _compose(parts)
		"flower":
			var lv := leaves("#c8506a", "#f0d070", false, 0.1)
			m = _compose([[_sph(0.12, 6), _x(Vector3(0, 0.4, 0)), lv], [_sph(0.1, 6), _x(Vector3(0.25, 0.35, 0.1)), lv], [_sph(0.11, 6), _x(Vector3(-0.2, 0.3, -0.15)), lv]])
	_cache[kind] = m
	return m


## Low-poly rock: a sphere with its vertices displaced by noise (computed once).
static func _rock(mat: Material, seed_v: int) -> ArrayMesh:
	var s := _sph(1.0, 9)
	var arr := s.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new(); n.seed = seed_v; n.frequency = 1.3
	for i in verts.size():
		var v := verts[i]
		var k := 1.0 + n.get_noise_3dv(v) * 0.35
		verts[i] = Vector3(v.x * k * 1.2, maxf(v.y * k * 0.75, -0.3), v.z * k)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(am, 0)
	st.generate_normals()
	st.set_material(mat)
	return st.commit()


## Places instances in spatial chunks so whole far chunks are culled at once.
static func scatter(parent: Node3D, kind: String, xforms: Array, vis_end: float, shadows := true, chunk := 64.0) -> void:
	var buckets := {}
	for xf in xforms:
		var key := Vector2i(floori(xf.origin.x / chunk), floori(xf.origin.z / chunk))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(xf)
	var m := mesh(kind)
	for key in buckets:
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = list.size()
		for i in list.size(): mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if vis_end < 120.0 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if not shadows: mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
