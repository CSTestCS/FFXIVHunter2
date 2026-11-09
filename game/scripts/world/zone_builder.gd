class_name ZoneBuilder
## Generates a zone from its data: heightmap terrain with painted roads, edges that rise into
## cliffs (except at zone lines and the sea), water, biome vegetation, camps, the aetheryte,
## landmark signposts and spawn points. Cities are laid out from style kits.
## Everything is deterministic per zone id, so a zone always looks the same.

const N := 105
const BIOMES := {
	"forest": {"amp": 9.0, "freq": 0.012, "grass_a": "#22381a", "grass_b": "#3c5620", "dirt": "#4a3a28", "rock": "#5a5a52", "top": "#3c5a24", "top_h": 999.0,
		"trees": [["broadleaf", 0.55], ["conifer", 0.25], ["giant", 0.04], ["bush", 0.3]], "tree_density": 700, "grass": "grass", "grass_density": 3200, "rocks": "rock",
		"sky_top": "#3a6ea8", "sky_horizon": "#a8c4c8", "fog": "#9bb89a", "fog_density": 0.006, "sun": "#fff0d8", "sun_e": 1.5, "music": "forest"},
	"coast": {"amp": 12.0, "freq": 0.01, "grass_a": "#3a5a22", "grass_b": "#5a7a30", "dirt": "#7a6448", "rock": "#7a746a", "top": "#5a7a30", "top_h": 999.0,
		"trees": [["broadleaf", 0.35], ["palm", 0.35], ["bush", 0.3]], "tree_density": 260, "grass": "grass", "grass_density": 2600, "rocks": "rock",
		"sky_top": "#2a6ac8", "sky_horizon": "#b8d8e8", "fog": "#b8d0dc", "fog_density": 0.003, "sun": "#fff6e6", "sun_e": 1.7, "music": "sea"},
	"desert": {"amp": 7.0, "freq": 0.008, "grass_a": "#b8925e", "grass_b": "#cfa76e", "dirt": "#9a7448", "rock": "#9a6e4a", "top": "#cfa76e", "top_h": 999.0,
		"trees": [["cactus", 0.5], ["dead", 0.3], ["palm", 0.1]], "tree_density": 140, "grass": "grass_dry", "grass_density": 900, "rocks": "rock_sand",
		"sky_top": "#3a78c8", "sky_horizon": "#e8d8b8", "fog": "#e0caa0", "fog_density": 0.004, "sun": "#fff0d0", "sun_e": 2.0, "music": "desert", "mesas": true},
	"snow": {"amp": 14.0, "freq": 0.011, "grass_a": "#d8e0e8", "grass_b": "#eef2f6", "dirt": "#8a8a90", "rock": "#6a6c74", "top": "#ffffff", "top_h": 4.0,
		"trees": [["conifer_snow", 0.8], ["dead", 0.2]], "tree_density": 320, "grass": "grass_snow", "grass_density": 600, "rocks": "rock_snow",
		"sky_top": "#5a7894", "sky_horizon": "#c8d4dc", "fog": "#c8d2dc", "fog_density": 0.012, "sun": "#e8f0ff", "sun_e": 1.1, "music": "snow", "snowfall": true},
	"highland": {"amp": 15.0, "freq": 0.012, "grass_a": "#3a5222", "grass_b": "#56682e", "dirt": "#5a4a36", "rock": "#6a665e", "top": "#56682e", "top_h": 999.0,
		"trees": [["conifer", 0.6], ["broadleaf", 0.2], ["bush", 0.2]], "tree_density": 300, "grass": "grass", "grass_density": 2200, "rocks": "boulder",
		"sky_top": "#3a6aa8", "sky_horizon": "#b0c8d0", "fog": "#a8b8bc", "fog_density": 0.005, "sun": "#fff2dc", "sun_e": 1.6, "music": "forest"},
	"crystal": {"amp": 10.0, "freq": 0.012, "grass_a": "#4a4a5e", "grass_b": "#5e5a72", "dirt": "#3e3a48", "rock": "#4a4650", "top": "#5e5a72", "top_h": 999.0,
		"trees": [["dead", 0.6], ["crystal", 0.4]], "tree_density": 170, "grass": "grass_dry", "grass_density": 700, "rocks": "rock_dark",
		"sky_top": "#3a3a6a", "sky_horizon": "#8a84a8", "fog": "#7a7498", "fog_density": 0.01, "sun": "#e0d8ff", "sun_e": 1.2, "music": "crystal"},
}


static func build(zone_id: String) -> Dictionary:
	var zd: Dictionary = Data.zones[zone_id]
	if zd["type"] == "city": return CityBuilder.build(zone_id)
	return _field(zone_id, zd)


static func spacing() -> float:
	return ZoneData.SIZE / (N - 1)


## Bilinear lookup into a heights array covering [-SIZE/2, SIZE/2].
static func sample(h: PackedFloat32Array, x: float, z: float, n := N, size := ZoneData.SIZE) -> float:
	var sp := size / (n - 1)
	var fx := clampf((x + size * 0.5) / sp, 0.0, n - 1.001)
	var fz := clampf((z + size * 0.5) / sp, 0.0, n - 1.001)
	var ix := int(fx); var iz := int(fz)
	var tx := fx - ix; var tz := fz - iz
	var a := h[iz * n + ix]; var b := h[iz * n + ix + 1]
	var c := h[(iz + 1) * n + ix]; var d := h[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func exit_pos(dir: String, inset := 6.0) -> Vector3:
	var v: Vector2 = ZoneData.DIRS[dir]
	var half := ZoneData.SIZE * 0.5 - inset
	var p := v
	if absf(v.x) > 0.1 and absf(v.y) > 0.1: p = v / maxf(absf(v.x), absf(v.y))
	return Vector3(p.x * half, 0, p.y * half)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _field(zone_id: String, zd: Dictionary) -> Dictionary:
	var b: Dictionary = BIOMES[zd["biome"]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone_id)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = b["freq"]
	noise.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = rng.randi(); ridge.frequency = 0.03; ridge.noise_type = FastNoiseLite.TYPE_CELLULAR
	var half := ZoneData.SIZE * 0.5
	var sp := spacing()
	# --- layout: exits, hub, landmarks, roads
	var exits := []
	for e in zd["exits"]:
		exits.append({"to": e["to"], "dir": e["dir"], "pos": exit_pos(e["dir"])})
	var hub := Vector2.ZERO
	var lms := []
	for l in zd.get("landmarks", []):
		lms.append({"name": l[0], "pos": Vector3(l[1], 0, l[2])})
	var aeth: Vector3 = lms[0]["pos"] if not lms.is_empty() else Vector3.ZERO
	hub = Vector2(aeth.x, aeth.z)
	var roads := []
	for e in exits: roads.append([Vector2(e["pos"].x, e["pos"].z), hub])
	for i in range(1, lms.size()): roads.append([hub, Vector2(lms[i]["pos"].x, lms[i]["pos"].z)])
	if zd.has("ferry"):
		roads.append([hub, Vector2(-half + 20, 0)])
	# sea side: an edge with no zone line
	var sea_dir := ""
	if zd.get("water", "") == "sea":
		for cand in ["W", "S", "N", "E"]:
			var used := false
			for e in exits:
				if cand in e["dir"]: used = true
			if not used: sea_dir = cand; break
		if sea_dir == "": sea_dir = "W"
	var lake := {}
	if zd.get("water", "") == "lake":
		var lp: Vector3 = lms[1]["pos"] if lms.size() > 1 else Vector3(50, 0, -40)
		lake = {"center": Vector2(lp.x, lp.z) + Vector2(18, 14), "radius": 26.0}
	# --- heights
	var h := PackedFloat32Array()
	h.resize(N * N)
	var roadmask := PackedFloat32Array()
	roadmask.resize(N * N)
	for iz in N:
		for ix in N:
			var x := -half + ix * sp
			var z := -half + iz * sp
			var p := Vector2(x, z)
			var y := noise.get_noise_2d(x, z) * float(b["amp"]) + 6.0
			if b.get("mesas", false):
				var r := ridge.get_noise_2d(x, z)
				if r > 0.55: y += (r - 0.55) * 60.0
			# edges climb into cliffs except near zone lines and the sea
			var edge := maxf(absf(x), absf(z))
			var rise := smoothstep(half - 34.0, half - 4.0, edge) * 26.0
			for e in exits:
				var ep: Vector3 = e["pos"]
				var dd := p.distance_to(Vector2(ep.x, ep.z))
				rise *= smoothstep(10.0, 26.0, dd)
			var sea_k := 0.0
			if sea_dir != "":
				var sv: Vector2 = ZoneData.DIRS[sea_dir]
				var along := p.dot(sv)
				sea_k = smoothstep(half - 80.0, half - 35.0, along)
				rise *= 1.0 - sea_k
				y = lerpf(y, -7.0, sea_k)
			y += rise
			# roads
			var rd := 999.0
			for r in roads: rd = minf(rd, _seg_dist(p, r[0], r[1]))
			var rk := 1.0 - smoothstep(2.5, 6.0, rd)
			roadmask[iz * N + ix] = rk
			if rk > 0.0 and sea_k < 0.5: y = lerpf(y, noise.get_noise_2d(x * 0.3, z * 0.3) * float(b["amp"]) * 0.4 + 6.0, rk * 0.7)
			# flatten around the hub/landmarks for camps
			for l in lms:
				var ld := p.distance_to(Vector2(l["pos"].x, l["pos"].z))
				var fk := 1.0 - smoothstep(9.0, 16.0, ld)
				if fk > 0.0: y = lerpf(y, 6.0, fk)
			if not lake.is_empty():
				var ld2 := p.distance_to(lake["center"])
				var lk := 1.0 - smoothstep(lake["radius"] * 0.55, lake["radius"] + 6.0, ld2)
				y = lerpf(y, -2.5, lk)
			h[iz * N + ix] = y
	# --- result skeleton
	var root := Node3D.new()
	root.name = "Zone"
	var info := {"root": root, "heights": h, "n": N, "size": ZoneData.SIZE, "exits": exits, "landmarks": lms, "aetheryte": aeth,
		"waters": [], "npcs": [], "biome": b, "spawns": [], "nodes": [], "camp": Vector3.ZERO, "interact": []}
	for l in lms: l["pos"].y = sample(h, l["pos"].x, l["pos"].z)
	info["aetheryte"] = lms[0]["pos"] if not lms.is_empty() else Vector3(0, sample(h, 0, 0), 0)
	for e in exits: e["pos"].y = sample(h, e["pos"].x, e["pos"].z)
	_terrain_mesh(root, h, roadmask, b)
	# --- water
	if sea_dir != "":
		info["waters"].append({"kind": "sea", "level": 0.0, "dir": ZoneData.DIRS[sea_dir], "from": half - 95.0})
		_water_plane(root, Vector3(0, 0, 0), Vector2(ZoneData.SIZE * 3.0, ZoneData.SIZE * 3.0), b, true)
	if not lake.is_empty():
		var lc: Vector2 = lake["center"]
		info["waters"].append({"kind": "lake", "level": 0.5, "center": lc, "radius": lake["radius"] + 4.0})
		_water_plane(root, Vector3(lc.x, 0.5, lc.y), Vector2(lake["radius"] * 2.6, lake["radius"] * 2.6), b, false)
	# --- vegetation
	var gfx: Dictionary = Settings.gfx
	var tree_lists := {}
	var colliders := Batcher.new()
	var count := int(float(b["tree_density"]) * float(gfx["draw"]))
	for i in count:
		var x := rng.randf_range(-half + 8, half - 8)
		var z := rng.randf_range(-half + 8, half - 8)
		var y := sample(h, x, z)
		if y < 1.0 or _road_at(roadmask, x, z) > 0.2 or _near_lm(lms, x, z, 14.0) or _near_exit(exits, x, z, 14.0): continue
		var slope := absf(sample(h, x + 1, z) - y) + absf(sample(h, x, z + 1) - y)
		if slope > 1.4: continue
		var kind := _pick(b["trees"], rng)
		var s := rng.randf_range(0.8, 1.35)
		if not tree_lists.has(kind): tree_lists[kind] = []
		tree_lists[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y - 0.1, z)))
		if kind != "bush":
			var cs := CylinderShape3D.new(); cs.radius = (1.4 if kind == "giant" else 0.35) * s; cs.height = 6.0
			colliders.collider(cs, Transform3D(Basis(), Vector3(x, y + 3.0, z)))
	for kind in tree_lists:
		Props.scatter(root, kind, tree_lists[kind], 260.0 if kind != "bush" else 110.0, kind != "bush", 64.0)
	# rocks
	var rocks := []
	for i in int(90 * float(gfx["draw"])):
		var x := rng.randf_range(-half + 6, half - 6)
		var z := rng.randf_range(-half + 6, half - 6)
		var y := sample(h, x, z)
		if _road_at(roadmask, x, z) > 0.3 or _near_lm(lms, x, z, 10.0): continue
		var s := rng.randf_range(0.6, 2.6)
		rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)).scaled(Vector3.ONE * s), Vector3(x, y - 0.2 * s, z)))
		if s > 1.2:
			var ss := SphereShape3D.new(); ss.radius = s * 0.9
			colliders.collider(ss, Transform3D(Basis(), Vector3(x, y, z)))
	Props.scatter(root, b["rocks"], rocks, 220.0, true, 64.0)
	# grass (short range, no shadows)
	var grass := []
	var flowers := []
	for i in int(float(b["grass_density"]) * float(gfx["grass"])):
		var x := rng.randf_range(-half + 4, half - 4)
		var z := rng.randf_range(-half + 4, half - 4)
		var y := sample(h, x, z)
		if y < 0.6 or _road_at(roadmask, x, z) > 0.35: continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(x, y - 0.05, z))
		if zd["biome"] in ["forest", "coast", "highland"] and rng.randf() < 0.06: flowers.append(t)
		else: grass.append(t)
	Props.scatter(root, b["grass"], grass, 55.0, false, 32.0)
	if not flowers.is_empty(): Props.scatter(root, "flower", flowers, 45.0, false, 32.0)
	# --- landmarks: camps, aetheryte, signposts
	var bt := Batcher.new()
	for i in lms.size():
		var l: Dictionary = lms[i]
		_camp(bt, l["pos"], rng, b, i == 0)
		_sign(root, l["pos"] + Vector3(0, 4.2, 0), l["name"], 26)
	if not lms.is_empty():
		_aetheryte(root, bt, info["aetheryte"] + Vector3(4, 0, 4))
		info["aetheryte"] = info["aetheryte"] + Vector3(4, 0, 4)
	for e in exits:
		_zone_gate(root, bt, e["pos"], e["dir"], Data.zones[e["to"]]["name"])
	if zd.has("ferry"):
		var fp := Vector3(-half + 22, 0, 0)
		fp.y = maxf(sample(h, fp.x, fp.z), 0.5)
		bt.box(fp + Vector3(-6, -0.3, 0), Vector3(14, 0.6, 4), "dock", Props.pbr("#6a5038", 0.85))
		info["npcs"].append({"role": "ferry", "pos": fp + Vector3(1, 0, 2), "name": "Ferry Skipper", "face": PI * 0.5})
		_sign(root, fp + Vector3(0, 3.5, 0), zd["ferry"]["name"], 22)
	bt.commit(root)
	colliders.commit(root)
	_edge_walls(root)
	# --- spawn points for monsters / nodes
	for i in 80:
		var x := rng.randf_range(-half + 25, half - 25)
		var z := rng.randf_range(-half + 25, half - 25)
		var y := sample(h, x, z)
		if y < 1.0 or _near_lm(lms, x, z, 26.0) or _near_exit(exits, x, z, 24.0): continue
		info["spawns"].append(Vector3(x, y, z))
	for i in 40:
		var x := rng.randf_range(-half + 20, half - 20)
		var z := rng.randf_range(-half + 20, half - 20)
		var y := sample(h, x, z)
		if y < 0.6 or _near_exit(exits, x, z, 15.0): continue
		info["nodes"].append(Vector3(x, y, z))
	if not lake.is_empty():
		for i in 6:
			var a := i * TAU / 6.0
			var lc: Vector2 = lake["center"]
			var p = lc + Vector2(cos(a), sin(a)) * lake["radius"] * 0.35
			info["nodes"].append(Vector3(p.x, sample(h, p.x, p.y), p.y))
	info["camp"] = exits[0]["pos"] + (Vector3(0, 0, 0) - exits[0]["pos"]).normalized() * 18.0
	info["camp"].y = sample(h, info["camp"].x, info["camp"].z)
	return info


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for e in list: total += float(e[1])
	var r := rng.randf() * total
	for e in list:
		r -= float(e[1])
		if r <= 0.0: return e[0]
	return list[0][0]


static func _road_at(mask: PackedFloat32Array, x: float, z: float) -> float:
	return sample(mask, x, z)


static func _near_lm(lms: Array, x: float, z: float, r: float) -> bool:
	for l in lms:
		if Vector2(l["pos"].x, l["pos"].z).distance_to(Vector2(x, z)) < r: return true
	return false


static func _near_exit(exits: Array, x: float, z: float, r: float) -> bool:
	for e in exits:
		if Vector2(e["pos"].x, e["pos"].z).distance_to(Vector2(x, z)) < r: return true
	return false


static func terrain_material(b: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	for k in ["grass_a", "grass_b", "dirt", "rock", "top"]:
		m.set_shader_parameter(k, Color(b[k]))
	m.set_shader_parameter("top_height", b["top_h"])
	m.set_shader_parameter("shore_height", b.get("shore_h", 1.2))
	m.set_shader_parameter("noise_tex", Props.noise())
	return m


static func _terrain_mesh(root: Node3D, h: PackedFloat32Array, mask: PackedFloat32Array, b: Dictionary, n := N, size := ZoneData.SIZE) -> void:
	var sp := size / (n - 1)
	var half := size * 0.5
	var verts := PackedVector3Array(); verts.resize(n * n)
	var norms := PackedVector3Array(); norms.resize(n * n)
	var cols := PackedColorArray(); cols.resize(n * n)
	var uvs := PackedVector2Array(); uvs.resize(n * n)
	for iz in n:
		for ix in n:
			var i := iz * n + ix
			verts[i] = Vector3(-half + ix * sp, h[i], -half + iz * sp)
			var hl := h[iz * n + maxi(ix - 1, 0)]; var hr := h[iz * n + mini(ix + 1, n - 1)]
			var hd := h[maxi(iz - 1, 0) * n + ix]; var hu := h[mini(iz + 1, n - 1) * n + ix]
			norms[i] = Vector3(hl - hr, 2.0 * sp, hd - hu).normalized()
			cols[i] = Color(mask[i] if mask.size() > 0 else 0.0, 0, 0)
			uvs[i] = Vector2(ix, iz) / (n - 1)
	var idx := PackedInt32Array()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, terrain_material(b))
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.name = "Terrain"
	root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = n; hs.map_depth = n; hs.map_data = h
	cs.shape = hs
	cs.scale = Vector3(sp, 1.0, sp)
	body.add_child(cs)
	root.add_child(body)


static func water_material(b: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("noise_tex", Props.noise())
	if b.get("music", "") == "crystal":
		m.set_shader_parameter("shallow", Color("#4a5a9a")); m.set_shader_parameter("deep", Color("#14183a"))
	elif b.get("music", "") == "snow":
		m.set_shader_parameter("shallow", Color("#5a8a9a")); m.set_shader_parameter("deep", Color("#0c2232"))
	return m


static func _water_plane(root: Node3D, pos: Vector3, size: Vector2, b: Dictionary, big: bool) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 48 if big else 16
	pm.subdivide_depth = 48 if big else 16
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_material(b)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.name = "Water"
	root.add_child(mi)


static func _camp(bt: Batcher, p: Vector3, rng: RandomNumberGenerator, b: Dictionary, main: bool) -> void:
	var wood := Props.pbr("#6a4c30", 0.85)
	var canvas := Props.pbr("#d8ccb0" if b.get("music") != "snow" else "#8a3a30", 0.9)
	for i in (4 if main else 2):
		var a := rng.randf() * TAU
		var tp := p + Vector3(cos(a), 0, sin(a)) * rng.randf_range(6, 10)
		var tent := PrismMesh.new(); tent.size = Vector3(3.2, 2.4, 3.6)
		var xf := Transform3D(Basis(Vector3.UP, a), tp + Vector3(0, 1.2, 0))
		bt.add(tent, xf, "canvas", canvas)
		var sh := BoxShape3D.new(); sh.size = Vector3(3.0, 2.2, 3.4)
		bt.collider(sh, xf)
	for i in 10:
		var a := i * TAU / 10.0
		bt.box(p + Vector3(cos(a) * 12.0, 0.6, sin(a) * 12.0), Vector3(0.2, 1.2, 0.2), "wood", wood, false)
	bt.box(p + Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 1.4), "stone", Props.pbr("#5a5652", 0.9), false)
	var fire := CylinderMesh.new(); fire.bottom_radius = 0.4; fire.top_radius = 0.0; fire.height = 0.9; fire.radial_segments = 6; fire.rings = 1
	bt.add(fire, Transform3D(Basis(), p + Vector3(0, 0.75, 0)), "fire", Props.glow("#ff8a30", 4.0), false)
	var crate := Props.pbr("#8a6a40", 0.8)
	bt.box(p + Vector3(3, 0.45, -2), Vector3(0.9, 0.9, 0.9), "crate", crate)
	bt.box(p + Vector3(3.6, 0.35, -1), Vector3(0.7, 0.7, 0.7), "crate", crate)


static func _aetheryte(root: Node3D, bt: Batcher, p: Vector3) -> void:
	bt.cyl(p + Vector3(0, 0.25, 0), 2.2, 0.5, "plinth", Props.pbr("#8a8a90", 0.6, 0.2), true, 2.6, 16)
	var cr := PrismMesh.new(); cr.size = Vector3(1.0, 3.2, 1.0)
	var m := Props.glow("#6fd8ff", 3.0)
	var mi := MeshInstance3D.new(); mi.mesh = cr; mi.material_override = m; mi.position = p + Vector3(0, 3.6, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var mi2 := MeshInstance3D.new(); mi2.mesh = cr; mi2.material_override = m; mi2.position = p + Vector3(0, 1.6, 0); mi2.rotation_degrees.x = 180
	mi2.scale = Vector3(1, 0.4, 1); mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi2)
	var spin := mi.create_tween().set_loops()
	spin.tween_property(mi, "rotation:y", TAU, 6.0).from(0.0)
	var light := OmniLight3D.new(); light.light_color = Color("#8fe0ff"); light.omni_range = 9.0; light.light_energy = 1.4
	light.position = p + Vector3(0, 3.0, 0); light.shadow_enabled = false
	light.distance_fade_enabled = true; light.distance_fade_begin = 50.0; light.distance_fade_length = 20.0
	root.add_child(light)
	_sign(root, p + Vector3(0, 6.2, 0), "Aetheryte", 22)


static func _zone_gate(root: Node3D, bt: Batcher, p: Vector3, dir: String, to_name: String) -> void:
	var v: Vector2 = ZoneData.DIRS[dir]
	var side := Vector3(-v.y, 0, v.x).normalized()
	var stone := Props.pbr("#7a746a", 0.85)
	bt.box(p + side * 4.0 + Vector3(0, 2.0, 0), Vector3(0.8, 4.0, 0.8), "gate", stone)
	bt.box(p - side * 4.0 + Vector3(0, 2.0, 0), Vector3(0.8, 4.0, 0.8), "gate", stone)
	var shim := QuadMesh.new(); shim.size = Vector2(7.2, 3.6)
	var mi := MeshInstance3D.new(); mi.mesh = shim
	mi.material_override = FX.mat(Color("#9fd8ff"), 1.5, 0.18)
	mi.position = p + Vector3(0, 1.8, 0)
	mi.look_at_from_position(mi.position, mi.position + Vector3(v.x, 0, v.y), Vector3.UP)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_sign(root, p + Vector3(0, 4.6, 0), "To " + to_name, 24)


static func _sign(root: Node3D, p: Vector3, text: String, size := 24) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size * 2
	l.pixel_size = 0.01
	l.outline_size = 12
	l.modulate = Color("#f4ecd8")
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = p
	l.visibility_range_end = 60.0
	root.add_child(l)
	return l


static func _edge_walls(root: Node3D) -> void:
	var body := StaticBody3D.new(); body.collision_layer = 1
	var half := ZoneData.SIZE * 0.5
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2 if d.x != 0 else ZoneData.SIZE, 200, ZoneData.SIZE if d.x != 0 else 2)
		cs.shape = bs
		cs.position = d * (half + 1.0)
		body.add_child(cs)
	root.add_child(body)
