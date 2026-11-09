class_name GridaniaBuilder
## Gridania, the forest city of the Black Shroud, as one continuous place. A wooded ridge divides
## New Gridania (the lower, southern half: the Aetheryte Plaza, the Carline Canopy and the Roost,
## the Knot, the Adders' Nest, the Archers' Guild, Acorn Orchard, Apkallu Falls and the Blue
## Badger Gate) from Old Gridania (the higher, northern half: the Lotus Stand over its pool,
## Stillglade Fane on its island, the Lancers', Leatherworkers' and Botanists' guilds, Mih Khetto's
## Amphitheatre and the White Wolf Gate). Three stone-vaulted tunnels run through the ridge.
## Landmark names and their district placement follow the lore; the layout itself is this game's.

const N := 209                 # 1.25 m terrain grid over the 260 m city square
const OLD_Y := 4.0
const NEW_Y := 0.0
const RIDGE_HW := 15.0
const TUNNELS := [-64.0, 2.0, 60.0]
const TW := 3.6                # tunnel half-width
const ARCH_H := 3.0            # springing height of the vault
const PLAZA := Vector3(0, 0, 44)
const PLAZA_R := 20.0
const OLD_SQ := Vector3(-6, 0, -50)
const LOTUS := Vector3(36, 0, -74)
const LOTUS_R := 16.0
const FANE := Vector3(-30, 0, -96)
const FANE_R := 14.0
const AMPHI := Vector3(-80, 0, -82)
const WATER_NEW := -1.0
const WATER_OLD := 2.6

## District boundary for the area title (Old Gridania lies north of the ridge).
const DISTRICTS := [["Old Gridania", -9.0], ["New Gridania", 999.0]]

static var _noise: FastNoiseLite
static var _streams: Array = []
static var _road := PackedFloat32Array()   # distance beyond a street's edge, per terrain cell
static var _wet := PackedFloat32Array()    # distance beyond the water's edge, per terrain cell


static func ridge_z(x: float) -> float:
	return -9.0 + 4.0 * sin(x * 0.035) + 2.0 * sin(x * 0.09 + 1.0)


static func _streams_def() -> Array:
	return [
		# Apkallu: from the falls on the western cliffs, across New Gridania, out under the east wall.
		{"level": WATER_NEW, "pts": [Vector2(-116, 63), Vector2(-104, 64), Vector2(-90, 70), Vector2(-70, 78), Vector2(-50, 84), Vector2(-30, 82),
			Vector2(-10, 87), Vector2(10, 94), Vector2(32, 98), Vector2(54, 93), Vector2(76, 87), Vector2(98, 90), Vector2(132, 93)],
			"w": [8.0, 13.0, 8.0, 8.5, 11.0, 8.5, 8.0, 8.0, 8.5, 8.0, 8.0, 8.0, 8.0]},
		# The spring that feeds the Lotus Stand's pool, falling from the northern heights.
		{"level": WATER_OLD, "pts": [Vector2(72, -116), Vector2(68, -104), Vector2(58, -94), Vector2(48, -84)], "w": [6.0, 4.5, 4.5, 5.0]},
		# The pool's outflow, east under the wall.
		{"level": WATER_OLD, "pts": [Vector2(50, -64), Vector2(70, -58), Vector2(90, -56), Vector2(110, -52), Vector2(132, -50)], "w": [5.0, 5.0, 5.0, 5.0, 5.0]},
		# A quiet channel from the pool to Stillglade Fane's pond.
		{"level": WATER_OLD, "pts": [Vector2(22, -80), Vector2(4, -86), Vector2(-14, -92)], "w": [4.0, 4.0, 4.0]},
	]


## Distance from p to a polyline, and the interpolated half-width there.
static func _poly(p: Vector2, pts: Array, w: Array) -> Vector2:
	var best := 1e9
	var bw := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			bw = lerpf(w[i], w[i + 1], t) * 0.5
	return Vector2(best, bw)


## Ground height before the tunnels are cut (also used to cap the tunnels seamlessly).
static func h_natural(x: float, z: float) -> float:
	var zr := ridge_z(x)
	var base := lerpf(OLD_Y, NEW_Y, smoothstep(zr - RIDGE_HW * 0.55, zr + RIDGE_HW * 0.55, z))
	var nz := _noise.get_noise_2d(x, z)
	var y := base + nz * 0.35
	# The ridge.
	var t := absf(z - zr) / RIDGE_HW
	var crest := 14.0 + 3.0 * sin(x * 0.07) + 2.0 * sin(x * 0.19) + nz * 2.0
	y = maxf(y, base + crest * (1.0 - smoothstep(0.15, 1.0, t)))
	# The forested heights around the city, with passes for the two gates.
	var q := Vector2(absf(x) - 106.0, absf(z) - 106.0)
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	var rim := smoothstep(-4.0, 16.0, d) * (18.0 + nz * 6.0)
	if z > 96.0: rim *= smoothstep(6.0, 10.0, absf(x))                       # Blue Badger Gate
	if x < -96.0: rim *= smoothstep(6.0, 10.0, absf(z + 56.0))               # White Wolf Gate
	y = maxf(y, base + rim)
	# The Aetheryte Plaza stands on a raised stone terrace.
	var pd := Vector2(x - PLAZA.x, z - PLAZA.z).length()
	if pd < PLAZA_R + 0.6: y = NEW_Y + 1.2
	# Mih Khetto's Amphitheatre: a sunken stage and tiers of seating rising to the west.
	var ad := Vector2(x - AMPHI.x, z - AMPHI.z)
	var ar := ad.length()
	if ar < 26.0:
		if ar < 8.0: y = OLD_Y - 0.6
		elif ad.x < 6.0 and ar < 22.0: y = OLD_Y - 0.4 + floorf((ar - 8.0) / 2.2) * 0.55
		elif ad.x < 6.0: y = lerpf(OLD_Y - 0.4 + 6.0 * 0.55, y, smoothstep(22.0, 26.0, ar))
	# Old Gridania's square is level.
	if Vector2(x - OLD_SQ.x, z - OLD_SQ.z).length() < 14.0: y = OLD_Y
	# Pools and streams.
	for pool in [[LOTUS, LOTUS_R], [FANE, FANE_R]]:
		var c: Vector3 = pool[0]
		var r: float = pool[1]
		var dd := Vector2(x - c.x, z - c.z).length()
		if dd < r + 3.0:
			y = minf(y, lerpf(WATER_OLD - 2.2, y, smoothstep(r - 3.0, r + 3.0, dd)))
	if Vector2(x - FANE.x, z - FANE.z).length() < 7.5: y = OLD_Y + 0.3     # the Fane's island
	for s in _streams:
		if not (s["box"] as Rect2).has_point(Vector2(x, z)): continue
		var pr := _poly(Vector2(x, z), s["pts"], s["w"])
		if pr.x < pr.y + 3.5:
			y = minf(y, lerpf(float(s["level"]) - 1.6, y, smoothstep(pr.y - 1.2, pr.y + 3.5, pr.x)))
	return y


static func tunnel_floor(tx: float, z: float) -> float:
	var zr := ridge_z(tx)
	return lerpf(OLD_Y, NEW_Y, clampf((z - (zr - RIDGE_HW - 2.0)) / ((RIDGE_HW + 2.0) * 2.0), 0.0, 1.0))


static func height(x: float, z: float) -> float:
	var y := h_natural(x, z)
	for tx in TUNNELS:
		var zr := ridge_z(tx)
		if absf(z - zr) < RIDGE_HW + 6.0 and absf(x - tx) < TW + 1.9:
			y = minf(y, tunnel_floor(tx, z))
	return y


static func build(zone_id: String) -> Dictionary:
	var zd: Dictionary = Data.zones[zone_id]
	_noise = FastNoiseLite.new(); _noise.seed = 1717; _noise.frequency = 0.03
	_streams = _streams_def()
	for s in _streams:
		var r := Rect2(s["pts"][0], Vector2.ZERO)
		for q in s["pts"]: r = r.expand(q)
		s["box"] = r.grow(12.0)
	var size := ZoneData.SIZE
	var half := size * 0.5
	var sp := size / (N - 1)
	var b: Dictionary = ZoneBuilder.BIOMES["forest"].duplicate()
	b["fog_density"] = 0.007
	b["fog"] = "#a8bc98"
	var h := PackedFloat32Array(); h.resize(N * N)
	for iz in N:
		for ix in N:
			h[iz * N + ix] = height(-half + ix * sp, -half + iz * sp)
	var root := Node3D.new(); root.name = "City"
	var exits := [
		{"to": "central_shroud", "dir": "S", "pos": Vector3(0, 0, 126), "gate": "Blue Badger Gate"},
		{"to": "north_shroud", "dir": "W", "pos": Vector3(-126, 0, -56), "gate": "White Wolf Gate"},
	]
	var info := {"root": root, "heights": h, "n": N, "size": size, "exits": exits, "landmarks": [], "aetheryte": PLAZA,
		"waters": [], "npcs": [], "biome": b, "spawns": [], "nodes": [], "camp": PLAZA + Vector3(0, 0, 26), "interact": [], "city": true,
		"districts": DISTRICTS}
	var g := func(x: float, z: float) -> float: return ZoneBuilder.sample(h, x, z, N, size)
	# ---------------------------------------------------------------- streets
	var paths := _paths()
	_road = _raster([], paths)
	_wet = _raster(_streams, [])
	for pool in [[LOTUS, LOTUS_R], [FANE, FANE_R]]:
		_raster_disc(_wet, Vector2(pool[0].x, pool[0].z), float(pool[1]))
	var mask := PackedFloat32Array(); mask.resize(N * N)
	for iz in N:
		for ix in N:
			var i := iz * N + ix
			var p := Vector2(-half + ix * sp, -half + iz * sp)
			var road := 1.0 - smoothstep(-1.0, 0.0, _road[i])
			if p.distance_to(Vector2(PLAZA.x, PLAZA.z)) < PLAZA_R - 0.5 or p.distance_to(Vector2(OLD_SQ.x, OLD_SQ.z)) < 13.0: road = 1.0
			mask[i] = road
	var tb := Dictionary(b); tb["grass_a"] = "#2a4419"; tb["grass_b"] = "#46642a"; tb["dirt"] = "#5a4630"; tb["rock"] = "#3e4a2a"
	tb["shore_h"] = -99.0
	ZoneBuilder._terrain_mesh(root, h, mask, tb, N, size)
	var tmat: ShaderMaterial = (root.get_node("Terrain") as MeshInstance3D).mesh.surface_get_material(0)
	tmat.set_shader_parameter("cobble", true)
	var bt := Batcher.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 2207
	var trees := {"elder": [], "oak": [], "slim": [], "bush": [], "fern": [], "great": []}
	var occupied := []   # [Vector2 centre, radius] kept clear of filler houses and trees
	# ---------------------------------------------------------------- water
	for s in _streams:
		_stream_mesh(root, s, b)
		var hw := []
		for w in s["w"]: hw.append(float(w) * 0.5)
		info["waters"].append({"kind": "stream", "level": s["level"], "pts": s["pts"], "half": hw})
	for pool in [[LOTUS, LOTUS_R], [FANE, FANE_R]]:
		var c: Vector3 = pool[0]
		info["waters"].append({"kind": "lake", "level": WATER_OLD, "center": Vector2(c.x, c.z), "radius": float(pool[1]) - 0.5})
		ZoneBuilder._water_plane(root, Vector3(c.x, WATER_OLD, c.z), Vector2(float(pool[1]) * 2.3, float(pool[1]) * 2.3), b, false)
	_waterfall(root, bt, Vector3(-127, 17, 63), Vector3(-114, WATER_NEW, 63), 9.0)
	_waterfall(root, bt, Vector3(74, OLD_Y + 12.0, -126), Vector3(72, WATER_OLD, -116), 5.0)
	ZoneBuilder._sign(root, Vector3(-112, 6, 63), "Apkallu Falls", 24)
	info["landmarks"].append({"name": "Apkallu Falls", "pos": Vector3(-104, 0, 70)})
	# ---------------------------------------------------------------- the ridge and its tunnels
	for tx in TUNNELS:
		_tunnel(root, bt, tx)
	# ---------------------------------------------------------------- New Gridania
	_plaza(root, bt, info, g)
	occupied.append([Vector2(PLAZA.x, PLAZA.z), PLAZA_R + 3.0])
	var services := {}
	# The Carline Canopy: the Adventurers' Guild, a long hall with a tower, facing the plaza.
	services["guild"] = _hall(bt, root, Vector3(-46, 0, 40), PLAZA, 20.0, 13.0, 2, g, occupied, {"tower": true, "roof": "roof_g"}, zd["guild"], info)
	services["inn"] = _hall(bt, root, Vector3(-48, 0, 64), Vector3(-20, 0, 60), 13.0, 10.0, 2, g, occupied, {"roof": "roof_b"}, "The Roost", info)
	services["smith"] = _hall(bt, root, Vector3(46, 0, 38), PLAZA, 16.0, 12.0, 2, g, occupied, {"roof": "roof_b", "chimney": true}, "Carpenters' Guild (The Knot)", info)
	_hall(bt, root, Vector3(42, 0, 64), Vector3(14, 0, 52), 14.0, 11.0, 2, g, occupied, {"tower": true}, "The Adders' Nest", info)
	_hall(bt, root, Vector3(80, 0, 64), Vector3(56, 0, 66), 14.0, 11.0, 1, g, occupied, {}, "Archers' Guild", info)
	for k in 4:
		_target(bt, Vector3(100, g.call(100, 56.0 + k * 6.0), 56.0 + k * 6.0))
	for c in [Vector3(-8, 0, 74), Vector3(8, 0, 74), Vector3(-20, 0, 72), Vector3(20, 0, 72)]:
		GKit.stall(bt, Vector3(c.x, g.call(c.x, c.z), c.z), atan2(-c.x, -(c.z - 60.0)) if false else PI, "cloth_g" if c.x < 0 else "cloth_y")
		occupied.append([Vector2(c.x, c.z), 3.0])
	# Acorn Orchard, across the stream to the south-west.
	ZoneBuilder._sign(root, Vector3(-64, g.call(-64, 106) + 5.0, 106), "Acorn Orchard", 22)
	info["landmarks"].append({"name": "Acorn Orchard", "pos": Vector3(-64, 0, 104)})
	for i in 4:
		for j in 3:
			var p := Vector3(-82 + i * 9.0, 0, 98 + j * 9.0)
			trees["oak"].append(Vector3(p.x, g.call(p.x, p.z), p.z))
	for c in [Vector3(-46, 0, 104), Vector3(-40, 0, 112)]:
		GKit.stall(bt, Vector3(c.x, g.call(c.x, c.z), c.z), -PI * 0.5, "cloth_y")
	occupied.append([Vector2(-64, 106), 18.0])
	# The Blue Badger Gate.
	_gatehouse(root, bt, Vector3(0, g.call(0, 112), 112), 0.0, "Blue Badger Gate", g)
	occupied.append([Vector2(0, 114), 10.0])
	# ---------------------------------------------------------------- Old Gridania
	_old_square(root, bt, trees, g)
	occupied.append([Vector2(OLD_SQ.x, OLD_SQ.z), 15.0])
	services["trainer"] = _hall(bt, root, Vector3(-64, 0, -48), OLD_SQ, 16.0, 12.0, 2, g, occupied, {"tower": true, "roof": "roof_t"}, "Lancers' Guild", info)
	for k in 3:
		_dummy(bt, Vector3(-52 + k * 4.0, g.call(-52 + k * 4.0, -66), -66))
	occupied.append([Vector2(-48, -66), 7.0])
	services["market"] = _hall(bt, root, Vector3(52, 0, -42), OLD_SQ, 14.0, 11.0, 2, g, occupied, {"roof": "roof_b"}, "Leatherworkers' Guild", info)
	for k in 3:
		_rack(bt, Vector3(62 + k * 3.0, g.call(62 + k * 3.0, -30), -30))
	_hall(bt, root, Vector3(90, 0, -88), Vector3(70, 0, -70), 14.0, 11.0, 1, g, occupied, {"roof": "roof_g"}, "Botanists' Guild", info)
	_gardens(bt, Vector3(78, 0, -74), g)
	occupied.append([Vector2(78, -74), 8.0])
	_lotus_stand(root, bt, trees, info, g)
	occupied.append([Vector2(LOTUS.x, LOTUS.z), LOTUS_R + 4.0])
	occupied.append([Vector2(34, -104), 12.0])
	_fane(root, bt, trees, info, g)
	occupied.append([Vector2(FANE.x, FANE.z), FANE_R + 4.0])
	_amphitheatre(root, bt, info, g)
	occupied.append([Vector2(AMPHI.x, AMPHI.z), 26.0])
	_gatehouse(root, bt, Vector3(-112, g.call(-112, -56), -56), PI * 0.5, "White Wolf Gate", g)
	occupied.append([Vector2(-114, -56), 10.0])
	# ---------------------------------------------------------------- service NPCs
	var gd: Vector3 = services["guild"]
	var gface := atan2(PLAZA.x - gd.x, PLAZA.z - gd.z) + PI
	var gside := Vector3(cos(gface), 0, -sin(gface))
	info["npcs"].append({"role": "guildmaster", "pos": gd, "face": gface, "cast": StoryData.GUILDS[zone_id]["gm"]})
	info["npcs"].append({"role": "leves", "pos": gd + gside * 6.0, "face": gface, "name": "Levemete"})
	info["npcs"].append({"role": "recruiter", "pos": gd - gside * 6.0, "face": gface, "name": "Party Recruiter"})
	for r in [["inn", "Cook"], ["smith", "Smith"], ["market", "Merchant"], ["trainer", "Job Trainer"]]:
		info["npcs"].append({"role": r[0], "pos": services[r[0]], "face": 0.0, "name": r[1]})
	# ---------------------------------------------------------------- homes
	var homes := [
		# New Gridania
		[Vector3(-26, 0, 20), Vector3(-8, 0, 30)], [Vector3(24, 0, 20), Vector3(8, 0, 30)], [Vector3(-74, 0, 30), Vector3(-50, 0, 30)],
		[Vector3(-80, 0, 50), Vector3(-60, 0, 50)], [Vector3(70, 0, 26), Vector3(50, 0, 30)], [Vector3(84, 0, 42), Vector3(60, 0, 44)],
		[Vector3(-24, 0, 100), Vector3(-10, 0, 90)], [Vector3(24, 0, 112), Vector3(10, 0, 104)], [Vector3(-26, 0, 64), Vector3(-10, 0, 56)],
		[Vector3(66, 0, 110), Vector3(48, 0, 100)], [Vector3(88, 0, 108), Vector3(70, 0, 100)], [Vector3(-92, 0, 90), Vector3(-80, 0, 80)],
		[Vector3(-100, 0, 36), Vector3(-80, 0, 40)], [Vector3(96, 0, 22), Vector3(80, 0, 30)],
		# Old Gridania
		[Vector3(-30, 0, -40), Vector3(-10, 0, -48)], [Vector3(16, 0, -38), Vector3(0, 0, -48)], [Vector3(-38, 0, -64), Vector3(-14, 0, -58)],
		[Vector3(22, 0, -54), Vector3(4, 0, -52)], [Vector3(-90, 0, -42), Vector3(-70, 0, -40)], [Vector3(-96, 0, -110), Vector3(-80, 0, -100)],
		[Vector3(-54, 0, -112), Vector3(-44, 0, -96)], [Vector3(78, 0, -38), Vector3(60, 0, -44)], [Vector3(96, 0, -26), Vector3(76, 0, -30)],
		[Vector3(100, 0, -110), Vector3(86, 0, -96)], [Vector3(10, 0, -112), Vector3(10, 0, -96)], [Vector3(-8, 0, -76), Vector3(-6, 0, -60)],
	]
	for hm in homes:
		var p: Vector3 = hm[0]
		var clear := true
		for o in occupied:
			if Vector2(p.x, p.z).distance_to(o[0]) < float(o[1]) + 5.0: clear = false
		if not clear: continue
		var w := rng.randf_range(8.0, 11.0); var d := rng.randf_range(7.0, 9.5)
		var gy := _footing(g, p, maxf(w, d))
		var yaw := atan2(hm[1].x - p.x, hm[1].z - p.z)
		GKit.house(bt, root, Vector3(p.x, gy, p.z), yaw, w, d, 2 if rng.randf() < 0.55 else 1,
			{"roof": ["roof_g", "roof_b", "roof_t"][rng.randi() % 3], "plaster": "plaster" if rng.randf() < 0.7 else "plaster_g", "chimney": rng.randf() < 0.4})
		occupied.append([Vector2(p.x, p.z), maxf(w, d) * 0.6 + 2.0])
	# ---------------------------------------------------------------- lanterns along the streets
	var lit := 0
	for s in paths:
		var pts: Array = s[0]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]; var c: Vector2 = pts[i + 1]
			var n := int(a.distance_to(c) / 16.0)
			for k in n:
				var t := (k + 0.5) / maxf(1, n)
				var q := a.lerp(c, t)
				var side := (c - a).orthogonal().normalized() * (float(s[1]) + 0.9) * (1.0 if k % 2 == 0 else -1.0)
				var lp := q + side
				if _in_water(lp, 1.0) or _blocked(lp, occupied, 0.0): continue
				GKit.lamp_post(bt, root, Vector3(lp.x, g.call(lp.x, lp.y), lp.y), atan2(-side.y, side.x), lit % 4 == 0 and lit < 48)
				lit += 1
	# ---------------------------------------------------------------- people
	var side_spots := [PLAZA + Vector3(12, 0, 8), PLAZA + Vector3(-12, 0, 8), PLAZA + Vector3(10, 0, -10), PLAZA + Vector3(-10, 0, -10)]
	var si := 0
	for q in StoryData.SIDE:
		if q["city"] == zone_id and si < side_spots.size():
			info["npcs"].append({"role": "side", "pos": side_spots[si], "face": 0.0, "quest": q["id"], "name": q["giver"]})
			si += 1
	for sc in [["orrik", gd + Vector3(6, 0, 7)], ["ysolde", PLAZA + Vector3(14, 0, 14)], ["tatale", OLD_SQ + Vector3(8, 0, 6)]]:
		info["npcs"].append({"role": "story", "pos": sc[1], "face": 0.0, "cast": sc[0]})
	for f in [PLAZA + Vector3(16, 0, 10), PLAZA + Vector3(-5, 0, 16), Vector3(4, 0, 78), Vector3(-14, 0, 80), Vector3(-60, 0, 100),
			Vector3(60, 0, 70), OLD_SQ + Vector3(9, 0, 7), OLD_SQ + Vector3(-9, 0, -5), Vector3(22, 0, -50), Vector3(-24, 0, -70),
			Vector3(-74, 0, -84), Vector3(84, 0, -80), Vector3(-56, 0, -60)]:
		info["npcs"].append({"role": "citizen", "pos": f, "face": rng.randf() * TAU})
	# ---------------------------------------------------------------- exits
	for e in exits:
		ZoneBuilder._zone_gate(root, bt, Vector3(e["pos"].x, g.call(e["pos"].x, e["pos"].z), e["pos"].z), e["dir"], Data.zones[e["to"]]["name"])
	# ---------------------------------------------------------------- the forest
	_forest(root, bt, rng, trees, occupied, paths, g)
	bt.commit(root)
	ZoneBuilder._edge_walls(root)
	return info


static func _fill(n: int, v: float) -> Array:
	var a := []
	for i in n: a.append(v)
	return a


## Street network: [points, half-width].
static func _paths() -> Array:
	var ps := []
	var P := Vector2(PLAZA.x, PLAZA.z)
	for tx in TUNNELS:
		var zr := ridge_z(tx)
		ps.append([[Vector2(tx, zr - RIDGE_HW - 6.0), Vector2(tx, zr + RIDGE_HW + 6.0)], 3.2])
	ps.append([[P + Vector2(0, PLAZA_R), Vector2(0, 86), Vector2(0, 126)], 3.4])                      # to the Blue Badger Gate
	ps.append([[P - Vector2(0, PLAZA_R), Vector2(2, ridge_z(2) + RIDGE_HW + 6.0)], 3.0])
	ps.append([[P + Vector2(-PLAZA_R, -6), Vector2(-40, 26), Vector2(-64, ridge_z(-64) + RIDGE_HW + 6.0)], 2.8])
	ps.append([[P + Vector2(PLAZA_R, -6), Vector2(40, 22), Vector2(60, ridge_z(60) + RIDGE_HW + 6.0)], 2.8])
	ps.append([[P + Vector2(-PLAZA_R, 4), Vector2(-34, 48)], 3.0])                                    # Carline Canopy
	ps.append([[P + Vector2(PLAZA_R, 2), Vector2(36, 42)], 3.0])                                      # the Knot
	ps.append([[P + Vector2(-12, 16), Vector2(-36, 66)], 2.6])                                        # the Roost
	ps.append([[P + Vector2(12, 16), Vector2(32, 62), Vector2(68, 66)], 2.6])                         # Adders' Nest, Archers' Guild
	ps.append([[Vector2(-36, 66), Vector2(-58, 74), Vector2(-60, 92), Vector2(-62, 112)], 2.6])     # bridge to Acorn Orchard
	ps.append([[Vector2(32, 62), Vector2(46, 80), Vector2(50, 106)], 2.6])
	ps.append([[Vector2(0, 104), Vector2(-46, 106)], 2.4])
	var O := Vector2(OLD_SQ.x, OLD_SQ.z)
	ps.append([[Vector2(-64, ridge_z(-64) - RIDGE_HW - 6.0), Vector2(-40, -40), O + Vector2(-13, 2)], 2.8])
	ps.append([[Vector2(60, ridge_z(60) - RIDGE_HW - 6.0), Vector2(40, -40), O + Vector2(13, 2)], 2.8])
	ps.append([[Vector2(2, ridge_z(2) - RIDGE_HW - 6.0), O + Vector2(0, 13)], 3.0])
	ps.append([[O + Vector2(-12, -2), Vector2(-54, -48)], 2.8])                                       # Lancers' Guild
	ps.append([[O + Vector2(12, 0), Vector2(44, -44)], 2.8])                                          # Leatherworkers' Guild
	ps.append([[O + Vector2(4, -12), Vector2(20, -60), Vector2(30, -56)], 2.6])                       # to the Lotus Stand boardwalk
	ps.append([[O + Vector2(-6, -12), Vector2(-24, -72), Vector2(-28, -78)], 2.6])                    # to Stillglade Fane
	ps.append([[Vector2(-54, -48), Vector2(-70, -64), Vector2(-74, -70)], 2.6])                       # to the amphitheatre
	ps.append([[Vector2(-54, -48), Vector2(-90, -54), Vector2(-126, -56)], 3.0])                      # White Wolf Gate
	ps.append([[Vector2(44, -44), Vector2(66, -60), Vector2(82, -80)], 2.6])                          # Botanists' Guild
	return ps


static func _cell(p: Vector2) -> int:
	var sp := ZoneData.SIZE / (N - 1)
	var ix := clampi(int(round((p.x + ZoneData.SIZE * 0.5) / sp)), 0, N - 1)
	var iz := clampi(int(round((p.y + ZoneData.SIZE * 0.5) / sp)), 0, N - 1)
	return iz * N + ix


static func _in_water(p: Vector2, margin: float) -> bool:
	return _wet[_cell(p)] < margin


static func _on_road(p: Vector2, margin: float) -> bool:
	return _road[_cell(p)] < margin


## Distance-beyond-edge grid for streams ({pts, w}) or paths ([pts, half-width]); each segment
## only touches the cells inside its own bounding box.
static func _raster(streams: Array, paths: Array) -> PackedFloat32Array:
	var grid := PackedFloat32Array(); grid.resize(N * N); grid.fill(99.0)
	var sp := ZoneData.SIZE / (N - 1)
	var half := ZoneData.SIZE * 0.5
	var lines := []
	for s in streams:
		for i in s["pts"].size() - 1: lines.append([s["pts"][i], s["pts"][i + 1], float(s["w"][i]) * 0.5, float(s["w"][i + 1]) * 0.5])
	for s in paths:
		for i in s[0].size() - 1: lines.append([s[0][i], s[0][i + 1], float(s[1]), float(s[1])])
	for l in lines:
		var a: Vector2 = l[0]; var b: Vector2 = l[1]
		var reach := maxf(l[2], l[3]) + 12.0
		var x0 := clampi(int((minf(a.x, b.x) - reach + half) / sp), 0, N - 1); var x1 := clampi(int((maxf(a.x, b.x) + reach + half) / sp) + 1, 0, N - 1)
		var z0 := clampi(int((minf(a.y, b.y) - reach + half) / sp), 0, N - 1); var z1 := clampi(int((maxf(a.y, b.y) + reach + half) / sp) + 1, 0, N - 1)
		var ab := b - a
		var ll := ab.length_squared()
		for iz in range(z0, z1 + 1):
			for ix in range(x0, x1 + 1):
				var p := Vector2(-half + ix * sp, -half + iz * sp)
				var t := clampf((p - a).dot(ab) / ll, 0.0, 1.0)
				var d := p.distance_to(a + ab * t) - lerpf(l[2], l[3], t)
				var k := iz * N + ix
				if d < grid[k]: grid[k] = d
	return grid


static func _raster_disc(grid: PackedFloat32Array, c: Vector2, r: float) -> void:
	var sp := ZoneData.SIZE / (N - 1)
	var half := ZoneData.SIZE * 0.5
	for iz in range(clampi(int((c.y - r - 12.0 + half) / sp), 0, N - 1), clampi(int((c.y + r + 12.0 + half) / sp), 0, N - 1)):
		for ix in range(clampi(int((c.x - r - 12.0 + half) / sp), 0, N - 1), clampi(int((c.x + r + 12.0 + half) / sp), 0, N - 1)):
			var d := Vector2(-half + ix * sp, -half + iz * sp).distance_to(c) - r
			var k := iz * N + ix
			if d < grid[k]: grid[k] = d


static func _blocked(p: Vector2, occupied: Array, margin: float) -> bool:
	for o in occupied:
		if p.distance_to(o[0]) < float(o[1]) + margin: return true
	return false


## Highest ground under a footprint, so buildings sit on their stone footing.
static func _footing(g: Callable, p: Vector3, r: float) -> float:
	var y := -999.0
	for dx in [-0.5, 0.0, 0.5]:
		for dz in [-0.5, 0.0, 0.5]:
			y = maxf(y, g.call(p.x + dx * r, p.z + dz * r))
	return y


## A named building that faces `target`; returns where its door NPC stands.
static func _hall(bt: Batcher, root: Node3D, p: Vector3, target: Vector3, w: float, d: float, floors: int, g: Callable, occupied: Array,
		o: Dictionary, label: String, info: Dictionary) -> Vector3:
	var gy := _footing(g, p, maxf(w, d))
	var yaw := atan2(target.x - p.x, target.z - p.z)
	var door := GKit.house(bt, root, Vector3(p.x, gy, p.z), yaw, w, d, floors, o)
	if o.get("tower", false):
		var tp := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy, p.z)) * Vector3(w * 0.5 - 0.5, 0, -d * 0.5 + 0.5)
		GKit.tower(bt, tp, 3.2, 3.1 * floors + 4.5, {"roof": o.get("roof", "roof_g")})
	occupied.append([Vector2(p.x, p.z), maxf(w, d) * 0.6 + 2.5])
	ZoneBuilder._sign(root, Vector3(door.x, gy + 3.1 * floors + 3.0, door.z), label, 26)
	info["landmarks"].append({"name": label, "pos": door})
	GKit.banner(bt, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy, p.z)) * Vector3(-w * 0.3, 0.7 + 3.0, d * 0.5 + 0.35), yaw, 2.4, "cloth_g")
	GKit.banner(bt, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy, p.z)) * Vector3(w * 0.3, 0.7 + 3.0, d * 0.5 + 0.35), yaw, 2.4, "cloth_g")
	return Vector3(door.x, 0, door.z)


# ----------------------------------------------------------------------------- water features
static func _stream_mesh(root: Node3D, s: Dictionary, b: Dictionary) -> void:
	var pts: Array = s["pts"]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lv: float = s["level"]
	var prev_l := Vector3.ZERO; var prev_r := Vector3.ZERO
	var dense := []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var c: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(c) / 3.0))
		for k in n:
			var t := float(k) / n
			dense.append([a.lerp(c, t), lerpf(s["w"][i], s["w"][i + 1], t) * 0.5 + 1.8])
	dense.append([pts[pts.size() - 1], float(s["w"][pts.size() - 1]) * 0.5 + 1.8])
	for i in dense.size():
		var p: Vector2 = dense[i][0]
		var dir: Vector2 = ((dense[mini(i + 1, dense.size() - 1)][0] - dense[maxi(i - 1, 0)][0]) as Vector2).normalized()
		var side := dir.orthogonal() * float(dense[i][1])
		var l := Vector3(p.x + side.x, lv, p.y + side.y); var r := Vector3(p.x - side.x, lv, p.y - side.y)
		if i > 0:
			GKit._quad(st, prev_l, prev_r, r, l, Vector3.UP)
		prev_l = l; prev_r = r
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ZoneBuilder.water_material(b)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _waterfall(root: Node3D, bt: Batcher, top: Vector3, foot: Vector3, width: float) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat := Vector3(foot.x - top.x, 0, foot.z - top.z)
	var side := Vector3(-flat.z, 0, flat.x).normalized() * width * 0.5
	var steps := 12
	for i in steps:
		var t0 := float(i) / steps; var t1 := float(i + 1) / steps
		var p0 := top + flat * (1.0 - pow(1.0 - t0, 2.0)) * 0.6 + Vector3(0, (foot.y - top.y) * t0 * t0, 0)
		var p1 := top + flat * (1.0 - pow(1.0 - t1, 2.0)) * 0.6 + Vector3(0, (foot.y - top.y) * t1 * t1, 0)
		var n := flat.normalized()
		st.set_normal(n); st.set_uv(Vector2(0, t0)); st.add_vertex(p0 - side)
		st.set_normal(n); st.set_uv(Vector2(1, t0)); st.add_vertex(p0 + side)
		st.set_normal(n); st.set_uv(Vector2(1, t1)); st.add_vertex(p1 + side)
		st.set_normal(n); st.set_uv(Vector2(0, t0)); st.add_vertex(p0 - side)
		st.set_normal(n); st.set_uv(Vector2(1, t1)); st.add_vertex(p1 + side)
		st.set_normal(n); st.set_uv(Vector2(0, t1)); st.add_vertex(p1 - side)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/waterfall.gdshader"); m.set_shader_parameter("noise_tex", Props.noise())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# Mossy rocks framing the fall, and spray at its foot.
	for s in [-1.0, 1.0]:
		var rp: Vector3 = top.lerp(foot, 0.5) + side * s * 1.25
		bt.add(_rock(2), Transform3D(Basis(Vector3.UP, s).scaled(Vector3(3.0, 6.0, 3.0)), rp), "rock", GKit.M("rock"))
	var spray := CPUParticles3D.new()
	spray.amount = 50; spray.lifetime = 1.6
	spray.position = foot + Vector3(0, 0.2, 0)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; spray.emission_box_extents = Vector3(width * 0.4, 0.2, width * 0.4)
	spray.direction = Vector3.UP; spray.spread = 60.0; spray.initial_velocity_min = 1.0; spray.initial_velocity_max = 2.4
	spray.gravity = Vector3(0, -2.5, 0)
	spray.scale_amount_min = 0.6; spray.scale_amount_max = 1.6
	var qm := QuadMesh.new(); qm.size = Vector2(0.9, 0.9)
	var sm2 := StandardMaterial3D.new()
	sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm2.albedo_color = Color(1, 1, 1, 0.45)
	var dot := GradientTexture2D.new(); dot.fill = GradientTexture2D.FILL_RADIAL; dot.fill_from = Vector2(0.5, 0.5); dot.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new(); dg.set_color(0, Color.WHITE); dg.set_color(1, Color(1, 1, 1, 0)); dot.gradient = dg
	sm2.albedo_texture = dot
	qm.material = sm2
	spray.mesh = qm
	root.add_child(spray)


static func _petal() -> Mesh:
	if GKit._c.has("petal"): return GKit._c["petal"]
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 10; sm.rings = 6
	GKit._c["petal"] = sm
	return sm


static func _rock(variant: int) -> ArrayMesh:
	var key := "rock|%d" % variant
	if GKit._c.has(key): return GKit._c[key]
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 12; sm.rings = 7
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var fn := FastNoiseLite.new(); fn.seed = variant * 31; fn.frequency = 1.6
	for i in v.size():
		var p := v[i]
		v[i] = p * (1.0 + fn.get_noise_3dv(p * 2.0) * 0.35)
		v[i].y = maxf(v[i].y, -0.35)
	arr[Mesh.ARRAY_VERTEX] = v
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new(); st.create_from(am, 0); st.generate_normals()
	var out := st.commit()
	GKit._c[key] = out
	return out


# ----------------------------------------------------------------------------- tunnels
## A tunnel through the ridge: a stone barrel vault with portals, wing walls, lanterns and a rock
## cap that continues the ridge surface over the cut, so the hillside is unbroken above it.
static func _tunnel(root: Node3D, bt: Batcher, tx: float) -> void:
	var zr := ridge_z(tx)
	var z0 := zr - RIDGE_HW - 6.0
	var z1 := zr + RIDGE_HW + 6.0
	# The vault covers the stretch where the ridge stands more than its own height above the floor.
	var va := z1; var vb := z0
	var z := z0
	while z <= z1:
		if h_natural(tx, z) - tunnel_floor(tx, z) > ARCH_H + TW + 1.4:
			va = minf(va, z); vb = maxf(vb, z)
		z += 0.5
	var lining := SurfaceTool.new(); lining.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SurfaceTool.new(); cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arch := []
	arch.append(Vector2(-TW, -0.3))
	arch.append(Vector2(-TW, ARCH_H))
	for k in range(1, 12):
		var a := PI - PI * k / 12.0
		arch.append(Vector2(cos(a) * TW, ARCH_H + sin(a) * TW))
	arch.append(Vector2(TW, ARCH_H))
	arch.append(Vector2(TW, -0.3))
	var step := 1.0
	var zz := va
	var capw := TW + 4.0
	while zz < vb - 0.01:
		var za := zz; var zb := minf(zz + step, vb)
		var fa := tunnel_floor(tx, za); var fb := tunnel_floor(tx, zb)
		for i in arch.size() - 1:
			var p: Vector2 = arch[i]; var q: Vector2 = arch[i + 1]
			var tg := (q - p).normalized()
			var n := Vector3(tg.y, -tg.x, 0)   # points into the tunnel
			if n.x * (p.x + q.x) > 0.0 or (absf(p.x + q.x) < 0.01 and n.y > 0): n = -n
			GKit._quad(lining, Vector3(tx + p.x, fa + p.y, za), Vector3(tx + q.x, fa + q.y, za), Vector3(tx + q.x, fb + q.y, zb), Vector3(tx + p.x, fb + p.y, zb), n)
		# Cap: follows the ridge surface across the cut.
		for k in 8:
			var xa := tx - capw + k * capw * 2.0 / 8.0
			var xb := xa + capw * 2.0 / 8.0
			var v0 := Vector3(xa, h_natural(xa, za), za); var v1 := Vector3(xb, h_natural(xb, za), za)
			var v2 := Vector3(xb, h_natural(xb, zb), zb); var v3 := Vector3(xa, h_natural(xa, zb), zb)
			var nn := (v1 - v0).cross(v3 - v0).normalized()
			if nn.y < 0: nn = -nn
			for v in [[v0, v1, v2], [v0, v2, v3]]:
				var order := [0, 1, 2]
				if (v[1] - v[0]).cross(v[2] - v[0]).dot(nn) > 0.0: order = [0, 2, 1]
				for o in order:
					cap.set_normal(nn); cap.set_color(Color(0, 0, 0)); cap.set_uv(Vector2.ZERO); cap.add_vertex(v[o])
		zz = zb
	var lm := lining.commit()
	var lmi := MeshInstance3D.new(); lmi.mesh = lm; lmi.material_override = GKit.M("stone")
	root.add_child(lmi)
	var body := StaticBody3D.new(); body.collision_layer = 1
	var cs := CollisionShape3D.new(); cs.shape = lm.create_trimesh_shape()
	body.add_child(cs); root.add_child(body)
	var cmi := MeshInstance3D.new(); cmi.mesh = cap.commit()
	var terrain := root.get_node_or_null("Terrain") as MeshInstance3D
	if terrain: cmi.material_override = terrain.mesh.surface_get_material(0)
	root.add_child(cmi)
	# Portals: a stone face around the arch, a ring of voussoirs, and wing walls along the cut.
	for end in [[va, -1.0], [vb, 1.0]]:
		var ze: float = end[0]
		var s: float = end[1]
		var fl := tunnel_floor(tx, ze)
		var top := h_natural(tx, ze)
		var face := SurfaceTool.new(); face.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outer := capw + 0.5
		for i in arch.size() - 1:
			var p: Vector2 = arch[i]; var q: Vector2 = arch[i + 1]
			var po := Vector2(signf(p.x) * outer if absf(p.x) > 0.01 else 0.0, maxf(p.y, 0.0))
			var qo := Vector2(signf(q.x) * outer if absf(q.x) > 0.01 else 0.0, maxf(q.y, 0.0))
			po.y = top - fl + 0.4 if p.y > ARCH_H - 0.01 else p.y
			qo.y = top - fl + 0.4 if q.y > ARCH_H - 0.01 else q.y
			GKit._quad(face, Vector3(tx + p.x, fl + p.y, ze), Vector3(tx + q.x, fl + q.y, ze), Vector3(tx + qo.x, fl + qo.y, ze), Vector3(tx + po.x, fl + po.y, ze), Vector3(0, 0, s))
		var fmi := MeshInstance3D.new(); fmi.mesh = face.commit(); fmi.material_override = GKit.M("stone")
		root.add_child(fmi)
		for k in 13:
			var a := PI - PI * k / 12.0
			var c := Vector3(tx + cos(a) * (TW + 0.35), fl + ARCH_H + sin(a) * (TW + 0.35), ze + s * 0.2)
			bt.add(GKit.boxm(Vector3(0.75, 0.55 if k != 6 else 0.8, 0.6)), Transform3D(Basis(Vector3(0, 0, 1), a - PI * 0.5), c), "stone_dark", GKit.M("stone_dark"))
		for sx in [-1.0, 1.0]:
			bt.add(GKit.boxm(Vector3(0.9, ARCH_H, 0.7)), Transform3D(Basis(), Vector3(tx + sx * (TW + 0.35), fl + ARCH_H * 0.5, ze + s * 0.2)), "stone_dark", GKit.M("stone_dark"))
			GKit.hang_lamp(bt, Transform3D(Basis(), Vector3(tx + sx * (TW + 1.3), fl + ARCH_H + 0.4, ze + s * 0.6)))
			# Wing walls hold back the hillside along the approach cut.
			var wz := ze
			var pts := []
			while absf(wz - ze) < RIDGE_HW and h_natural(tx + sx * (TW + 0.5), wz) - tunnel_floor(tx, wz) > 0.4:
				pts.append(Vector3(tx + sx * (TW + 0.5), tunnel_floor(tx, wz), wz))
				wz += s * 1.5
			for i in pts.size() - 1:
				var p0: Vector3 = pts[i]; var p1: Vector3 = pts[i + 1]
				var tp := h_natural(p0.x + sx * 0.6, (p0.z + p1.z) * 0.5) + 0.3
				var hh := tp - (p0.y - 1.0)
				bt.box(Vector3(p0.x + sx * 0.35, p0.y - 1.0 + hh * 0.5, (p0.z + p1.z) * 0.5), Vector3(0.9, hh, absf(p1.z - p0.z) + 0.05), "stone", GKit.M("stone"))
		ZoneBuilder._sign(root, Vector3(tx, fl + ARCH_H + TW + 1.2, ze + s * 1.0), "To New Gridania" if s < 0 else "To Old Gridania", 22)
	# Lanterns inside on alternate walls, and two soft lights.
	var lz := va + 3.0
	var k2 := 0
	while lz < vb - 2.0:
		var sx := -1.0 if k2 % 2 == 0 else 1.0
		var fl2 := tunnel_floor(tx, lz)
		GKit.hang_lamp(bt, Transform3D(Basis(), Vector3(tx + sx * (TW - 0.45), fl2 + ARCH_H + 0.2, lz)))
		bt.add(GKit.boxm(Vector3(0.5, 0.12, 0.12)), Transform3D(Basis(), Vector3(tx + sx * (TW - 0.2), fl2 + ARCH_H + 0.45, lz)), "iron", GKit.M("iron"))
		lz += 5.5
		k2 += 1
	for f in [0.3, 0.7]:
		var lz2 := lerpf(va, vb, f)
		var l := OmniLight3D.new(); l.light_color = Color("#ffc070"); l.light_energy = 1.6; l.omni_range = 12.0; l.shadow_enabled = false
		l.distance_fade_enabled = true; l.distance_fade_begin = 50.0; l.distance_fade_length = 15.0
		l.position = Vector3(tx, tunnel_floor(tx, lz2) + ARCH_H + 1.0, lz2)
		root.add_child(l)


# ----------------------------------------------------------------------------- districts and landmarks
## The Aetheryte Plaza: a raised stone terrace with steps on four sides, a ring of lanterns and
## gold canopies, and the aetheryte at its heart.
static func _plaza(root: Node3D, bt: Batcher, info: Dictionary, g: Callable) -> void:
	var c := PLAZA + Vector3(0, NEW_Y + 1.2, 0)
	bt.add(GKit._cyl(PLAZA_R + 0.4, 4.0, PLAZA_R + 0.6, 48), Transform3D(Basis(), c - Vector3(0, 2.05, 0)), "stone", GKit.M("stone"))
	bt.add(GKit._cyl(PLAZA_R + 0.7, 0.25, PLAZA_R + 0.7, 48), Transform3D(Basis(), c + Vector3(0, 0.0, 0)), "stone_dark", GKit.M("stone_dark"))
	bt.add(GKit._cyl(9.0, 0.12, 9.0, 32), Transform3D(Basis(), c + Vector3(0, 0.07, 0)), "plank", GKit.M("plank"))
	for k in 4:
		var d := Vector3(0, 0, 1).rotated(Vector3.UP, k * PI * 0.5 + (PI * 0.25 if k % 2 == 1 else 0.0) * 0.0)
		var top := c + d * (PLAZA_R + 0.2)
		var bottom := top + d * 4.0
		bottom.y = g.call(bottom.x, bottom.z)
		GKit.stairs(bt, bottom, top + Vector3(0, -0.02, 0), 6.0)
	ZoneBuilder._aetheryte(root, bt, c)
	info["aetheryte"] = c
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * (PLAZA_R - 1.6)
		GKit.lamp_post(bt, root, p, -a + PI, k % 2 == 0)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var p := c + Vector3(cos(a), 0, sin(a)) * 12.0
		var xf := Transform3D(Basis(Vector3.UP, -a), p)
		for s in [-1.0, 1.0]:
			GKit.beam(bt, xf, Vector3(s * 2.6, 0, -1.2), Vector3(s * 2.6, 4.2, -1.2), 0.24)
			GKit.beam(bt, xf, Vector3(s * 2.6, 0, 1.2), Vector3(s * 2.6, 3.6, 1.2), 0.24)
		bt.add(GKit.boxm(Vector3(6.0, 0.06, 3.0)), xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-11)), Vector3(0, 3.95, 0)), "cloth_y", GKit.M("cloth_y"), false)
		for s in [-1.0, 1.0]:
			GKit.bx(bt, xf, Vector3(0, 0.45, s * 1.0), Vector3(3.4, 0.12, 0.5), "plank")
			GKit.bx(bt, xf, Vector3(0, 0.22, s * 1.0), Vector3(3.2, 0.44, 0.3), "timber")
	info["landmarks"].append({"name": "Aetheryte Plaza", "pos": c})
	ZoneBuilder._sign(root, c + Vector3(0, 9.0, -PLAZA_R + 2.0), "Aetheryte Plaza", 28)


static func _old_square(root: Node3D, bt: Batcher, trees: Dictionary, g: Callable) -> void:
	var c := OLD_SQ + Vector3(0, OLD_Y, 0)
	bt.add(GKit._cyl(13.5, 0.14, 13.5, 40), Transform3D(Basis(), c + Vector3(0, 0.02, 0)), "stone_dark", GKit.M("stone_dark"))
	bt.add(GKit._cyl(4.2, 0.8, 4.4, 24), Transform3D(Basis(), c + Vector3(0, 0.4, 0)), "stone", GKit.M("stone"))
	trees["elder"].append(c + Vector3(0, 0.7, 0))
	for k in 6:
		var a := TAU * k / 6.0
		GKit.bx(bt, Transform3D(Basis(Vector3.UP, -a), c + Vector3(cos(a), 0, sin(a)) * 6.0), Vector3(0, 0.45, 0), Vector3(2.6, 0.12, 0.6), "plank")
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		GKit.lamp_post(bt, root, c + Vector3(cos(a), 0, sin(a)) * 12.0, -a + PI, k % 3 == 0)
	ZoneBuilder._sign(root, c + Vector3(0, 7.0, 10.0), "Old Gridania", 28)


## The Lotus Stand: a round pavilion raised over the pool on a boardwalk, a carved lotus dais at
## its centre, and the colossal tree that shelters it.
static func _lotus_stand(root: Node3D, bt: Batcher, trees: Dictionary, info: Dictionary, g: Callable) -> void:
	var deck_y := WATER_OLD + 1.3
	var c := Vector3(LOTUS.x, deck_y, LOTUS.z - 6.0)
	# Piles and the round deck.
	for k in 12:
		var a := TAU * k / 12.0
		bt.add(GKit._cyl(0.3, 4.0, 0.3, 8), Transform3D(Basis(), c + Vector3(cos(a) * 8.5, -2.0, sin(a) * 8.5)), "timber", GKit.M("timber"))
	bt.add(GKit._cyl(9.2, 0.3, 9.2, 36), Transform3D(Basis(), c), "plank", GKit.M("plank"))
	var dk := CylinderShape3D.new(); dk.radius = 9.2; dk.height = 0.3
	bt.collider(dk, Transform3D(Basis(), c))
	GKit.pavilion(bt, c + Vector3(0, -0.25, 0), 7.0, 5.2, "roof_g", 10)
	# The lotus dais: tiers of upturned petals.
	for tier in 2:
		var r := 2.6 - tier * 1.0
		for k in 10:
			var a := TAU * k / 10.0 + tier * 0.3
			var xf := Transform3D(Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-40 - tier * 15)) * Basis.from_scale(Vector3(0.55, 0.1, 1.0)), c + Vector3(cos(a) * r, 0.5 + tier * 0.35, sin(a) * r))
			bt.add(_petal(), xf, "petal", Props.pbr("#f4d4e2", 0.55), false)
	bt.add(GKit._cyl(1.2, 0.5, 1.4, 16), Transform3D(Basis(), c + Vector3(0, 0.4, 0)), "brass", GKit.M("brass"))
	# Boardwalk from the south shore.
	var south := Vector3(LOTUS.x, 0, LOTUS.z + LOTUS_R + 3.0)
	south.y = g.call(south.x, south.z)
	var start := Vector3(c.x, deck_y, c.z + 9.0)
	var bw_len := south.z - start.z
	var n := int(bw_len / 2.0)
	for i in n:
		var z := start.z + (i + 0.5) * bw_len / n
		var y := lerpf(deck_y, maxf(south.y, deck_y), float(i) / n)
		bt.box(Vector3(c.x, y, z), Vector3(3.6, 0.24, bw_len / n + 0.05), "plank", GKit.M("plank"))
		for s in [-1.0, 1.0]:
			bt.add(GKit._cyl(0.18, 3.0, 0.18, 6), Transform3D(Basis(), Vector3(c.x + s * 1.7, y - 1.5, z)), "timber", GKit.M("timber"), true)
	GKit.railing(bt, [Vector3(c.x - 1.75, deck_y, start.z), Vector3(c.x - 1.75, south.y, south.z)], 1.0)
	GKit.railing(bt, [Vector3(c.x + 1.75, deck_y, start.z), Vector3(c.x + 1.75, south.y, south.z)], 1.0)
	# Lily pads and blooms.
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for i in 30:
		var a := rng.randf() * TAU; var r := rng.randf_range(3.0, LOTUS_R - 1.5)
		var p := Vector3(LOTUS.x + cos(a) * r, WATER_OLD + 0.03, LOTUS.z + sin(a) * r)
		if Vector2(p.x - c.x, p.z - c.z).length() < 10.5 or absf(p.x - c.x) < 3.0 and p.z > c.z: continue
		bt.add(GKit._cyl(rng.randf_range(0.4, 0.8), 0.03, -1.0 if false else rng.randf_range(0.4, 0.8), 10), Transform3D(Basis(), p), "pad", Props.pbr("#3e6e30", 0.5), false)
		if i % 3 == 0:
			bt.add(GKit._cyl(0.18, 0.22, 0.05, 8), Transform3D(Basis(), p + Vector3(0, 0.12, 0)), "bloom", Props.pbr("#f2b8d4", 0.5), false)
	# The great tree on the northern shore.
	trees["great"].append(Vector3(LOTUS.x - 4.0, g.call(LOTUS.x - 4.0, LOTUS.z - LOTUS_R - 14.0), LOTUS.z - LOTUS_R - 14.0))
	var light := OmniLight3D.new(); light.light_color = Color("#ffe0a0"); light.light_energy = 1.4; light.omni_range = 12.0
	light.position = c + Vector3(0, 4.0, 0); light.shadow_enabled = false
	root.add_child(light)
	ZoneBuilder._sign(root, c + Vector3(0, 9.5, 0), "The Lotus Stand", 28)
	info["landmarks"].append({"name": "The Lotus Stand", "pos": south})


## Stillglade Fane, home of the Conjurers' Guild: a pavilion on an island in a still pond, reached
## by footbridges and sheltered by elder trees.
static func _fane(root: Node3D, bt: Batcher, trees: Dictionary, info: Dictionary, g: Callable) -> void:
	var c := Vector3(FANE.x, OLD_Y + 0.3, FANE.z)
	GKit.pavilion(bt, c, 5.0, 4.4, "roof_t", 8)
	bt.add(GKit._cyl(1.0, 1.0, 0.8, 12), Transform3D(Basis(), c + Vector3(0, 0.9, 0)), "stone", GKit.M("stone"))
	var orb := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.45; sm.height = 0.9
	orb.mesh = sm; orb.material_override = Props.glow("#bff0c0", 2.0); orb.position = c + Vector3(0, 1.9, 0)
	root.add_child(orb)
	for d in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
		var a: Vector3 = c + d * 7.0; a.y = OLD_Y + 0.2
		var b: Vector3 = c + d * (FANE_R + 3.0); b.y = g.call(b.x, b.z)
		GKit.bridge(bt, b, a, 3.2, 1.0)
	trees["elder"].append(Vector3(FANE.x - 10.0, g.call(FANE.x - 10.0, FANE.z - FANE_R - 6.0), FANE.z - FANE_R - 6.0))
	trees["elder"].append(Vector3(FANE.x + 9.0, g.call(FANE.x + 9.0, FANE.z - FANE_R - 9.0), FANE.z - FANE_R - 9.0))
	ZoneBuilder._sign(root, c + Vector3(0, 8.5, 0), "Stillglade Fane (Conjurers' Guild)", 26)
	info["landmarks"].append({"name": "Stillglade Fane", "pos": c})


## Mih Khetto's Amphitheatre: a round stage with tiers of timber benches rising to the west.
static func _amphitheatre(root: Node3D, bt: Batcher, info: Dictionary, g: Callable) -> void:
	var c := AMPHI + Vector3(0, OLD_Y - 0.6, 0)
	bt.add(GKit._cyl(6.0, 0.9, 6.2, 32), Transform3D(Basis(), c + Vector3(0, 0.0, 0)), "plank", GKit.M("plank"))
	bt.add(GKit._cyl(6.3, 0.7, 6.5, 32), Transform3D(Basis(), c - Vector3(0, 0.3, 0)), "stone", GKit.M("stone"))
	var st := CylinderShape3D.new(); st.radius = 6.2; st.height = 0.9
	bt.collider(st, Transform3D(Basis(), c))
	for tier in 6:
		var r := 9.1 + tier * 2.2
		var y := OLD_Y - 0.4 + tier * 0.55
		var segs := 14
		for k in segs:
			var a := PI * 0.5 + PI * (float(k) + 0.5) / segs
			if cos(a) * r > 6.0: continue
			var p := AMPHI + Vector3(cos(a) * r, y + 0.3, sin(a) * r)
			bt.add(GKit.boxm(Vector3(r * PI / segs - 0.3, 0.12, 0.8)), Transform3D(Basis(Vector3.UP, -a - PI * 0.5), p + Vector3(0, 0.18, 0)), "plank", GKit.M("plank"))
			bt.add(GKit.boxm(Vector3(r * PI / segs - 0.3, 0.45, 0.6)), Transform3D(Basis(Vector3.UP, -a - PI * 0.5), p - Vector3(0, 0.1, 0)), "stone", GKit.M("stone"))
	# A backdrop arch behind the stage.
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(7.5, 0.4, 0))
	for s in [-1.0, 1.0]:
		GKit.bx(bt, xf, Vector3(s * 4.0, 3.0, 0), Vector3(0.5, 6.0, 0.5), "timber")
	GKit.bx(bt, xf, Vector3(0, 6.1, 0), Vector3(9.4, 0.6, 0.7), "timber")
	GKit.bx(bt, xf, Vector3(0, 3.5, 0.1), Vector3(7.6, 4.6, 0.06), "cloth_g", Basis(), false)
	ZoneBuilder._sign(root, c + Vector3(0, 8.0, 0), "Mih Khetto's Amphitheatre", 26)
	info["landmarks"].append({"name": "Mih Khetto's Amphitheatre", "pos": c})


static func _gatehouse(root: Node3D, bt: Batcher, p: Vector3, yaw: float, label: String, g: Callable) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	for s in [-1.0, 1.0]:
		GKit.tower(bt, xf * Vector3(s * 7.5, 0, 0), 2.8, 7.5, {"roof": "roof_g"})
	GKit.bx(bt, xf, Vector3(0, 6.6, 0), Vector3(12.0, 1.0, 2.2), "timber")
	GKit.bx(bt, xf, Vector3(0, 7.4, 0), Vector3(12.6, 0.6, 2.8), "stone_dark")
	for s in [-1.0, 1.0]:
		GKit.bx(bt, xf, Vector3(s * 4.6, 3.1, 0), Vector3(0.6, 6.2, 0.6), "timber")
		GKit.banner(bt, xf * Vector3(s * 3.0, 6.0, 1.2), yaw, 3.2, "cloth_g")
	bt.add(GKit.gable_roof(3.2, 12.0, 1.8, 0.6, 0.2, 0.3), xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 7.7, 0)), "roof_g", GKit.M("roof_g"))
	ZoneBuilder._sign(root, xf * Vector3(0, 10.5, 0), label, 28)


static func _target(bt: Batcher, p: Vector3) -> void:
	bt.add(GKit._cyl(0.8, 0.25, 0.8, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.0), p + Vector3(0, 1.4, 0)) * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO), "cloth_w", GKit.M("cloth_w"))
	bt.add(GKit._cyl(0.45, 0.27, 0.45, 16), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), p + Vector3(-0.02, 1.4, 0)), "cloth_y", GKit.M("cloth_y"))
	GKit.beam(bt, Transform3D(), p + Vector3(0.3, 0, 0.5), p + Vector3(0, 1.4, 0), 0.12)
	GKit.beam(bt, Transform3D(), p + Vector3(0.3, 0, -0.5), p + Vector3(0, 1.4, 0), 0.12)


static func _dummy(bt: Batcher, p: Vector3) -> void:
	GKit.beam(bt, Transform3D(), p - Vector3(0, 0.3, 0), p + Vector3(0, 2.0, 0), 0.2)
	GKit.beam(bt, Transform3D(), p + Vector3(-0.8, 1.6, 0), p + Vector3(0.8, 1.6, 0), 0.14)
	bt.add(GKit._cyl(0.35, 0.9, 0.3, 10), Transform3D(Basis(), p + Vector3(0, 1.3, 0)), "cloth_w", GKit.M("cloth_w"))
	bt.add(GKit._cyl(0.25, 0.4, 0.2, 10), Transform3D(Basis(), p + Vector3(0, 2.05, 0)), "cloth_w", GKit.M("cloth_w"))


static func _rack(bt: Batcher, p: Vector3) -> void:
	for s in [-1.0, 1.0]:
		GKit.beam(bt, Transform3D(), p + Vector3(s * 1.0, 0, 0), p + Vector3(s * 1.0, 2.2, 0), 0.12)
	GKit.beam(bt, Transform3D(), p + Vector3(-1.1, 2.1, 0), p + Vector3(1.1, 2.1, 0), 0.1)
	GKit.bx(bt, Transform3D(), p + Vector3(0, 1.3, 0), Vector3(1.6, 1.5, 0.04), "plank_dark", Basis(), false)


static func _gardens(bt: Batcher, c: Vector3, g: Callable) -> void:
	for i in 3:
		for j in 2:
			var p := c + Vector3(-5.0 + i * 5.0, 0, -2.5 + j * 5.0)
			p.y = g.call(p.x, p.z)
			GKit.bx(bt, Transform3D(), p + Vector3(0, 0.25, 0), Vector3(3.6, 0.5, 2.2), "plank_dark")
			GKit.bx(bt, Transform3D(), p + Vector3(0, 0.52, 0), Vector3(3.3, 0.06, 1.9), "dark")


# ----------------------------------------------------------------------------- the forest
static func _forest(root: Node3D, bt: Batcher, rng: RandomNumberGenerator, trees: Dictionary, occupied: Array, paths: Array, g: Callable) -> void:
	var clear := func(p: Vector2, margin: float) -> bool:
		if _in_water(p, 1.5) or _on_road(p, margin) or _blocked(p, occupied, margin): return false
		for tx in TUNNELS:
			if absf(p.x - tx) < TW + 4.0 and absf(p.y - ridge_z(tx)) < RIDGE_HW + 8.0: return false
		return true
	# Giant trees: a ring on the forested heights, along the ridge, and a few inside the districts.
	var tries := 0
	while trees["elder"].size() < 64 and tries < 3000:
		tries += 1
		var p := Vector2(rng.randf_range(-124, 124), rng.randf_range(-124, 124))
		var edge := maxf(absf(p.x), absf(p.y)) > 104.0
		var on_ridge := absf(p.y - ridge_z(p.x)) < RIDGE_HW * 0.6
		if not (edge or on_ridge or rng.randf() < 0.04): continue
		if not clear.call(p, 6.0): continue
		var bad := false
		for e in trees["elder"]:
			if Vector2(e.x, e.z).distance_to(p) < 15.0: bad = true
		if bad: continue
		trees["elder"].append(Vector3(p.x, g.call(p.x, p.y), p.y))
	for kind in [["oak", 110, 3.0], ["slim", 60, 2.5], ["bush", 420, 1.0], ["fern", 520, 0.5]]:
		var n := 0
		tries = 0
		while n < kind[1] and tries < kind[1] * 20:
			tries += 1
			var p := Vector2(rng.randf_range(-122, 122), rng.randf_range(-122, 122))
			if not clear.call(p, kind[2]): continue
			if kind[0] in ["oak", "slim"]:
				var bad := false
				for e in trees["elder"]:
					if Vector2(e.x, e.z).distance_to(p) < 6.0: bad = true
				if bad: continue
			trees[kind[0]].append(Vector3(p.x, g.call(p.x, p.y), p.y))
			n += 1
	# Ferns and bushes crowd the feet of the big trees.
	for e in trees["elder"]:
		for k in 6:
			var a := rng.randf() * TAU; var r := rng.randf_range(5.0, 9.0)
			var p := Vector2(e.x + cos(a) * r, e.z + sin(a) * r)
			if clear.call(p, 0.5): trees["fern"].append(Vector3(p.x, g.call(p.x, p.y), p.y))
	var vis := {"great": 500.0, "elder": 420.0, "oak": 200.0, "slim": 200.0, "bush": 80.0, "fern": 55.0}
	var variants := {"great": 1, "elder": 3, "oak": 3, "slim": 2, "bush": 2, "fern": 2}
	for kind in trees:
		var by_var := {}
		for p in trees[kind]:
			var v := rng.randi() % int(variants[kind])
			if not by_var.has(v): by_var[v] = []
			var s := rng.randf_range(0.85, 1.2) if kind != "great" else 1.0
			by_var[v].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
			if kind in ["elder", "great", "oak", "slim"]:
				var cs := CylinderShape3D.new()
				cs.radius = {"great": 4.0, "elder": 2.6, "oak": 0.6, "slim": 0.45}[kind] * s
				cs.height = 8.0
				bt.collider(cs, Transform3D(Basis(), p + Vector3(0, 3.5, 0)))
		for v in by_var:
			GKit.scatter(root, GKit.tree(kind, v), by_var[v], vis[kind], kind != "fern", 64.0)
	# Grass and flowers on open ground.
	var grass := []; var flowers := []
	tries = 0
	while grass.size() < 3500 and tries < 20000:
		tries += 1
		var p := Vector2(rng.randf_range(-118, 118), rng.randf_range(-118, 118))
		if not clear.call(p, 0.3): continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.6)), Vector3(p.x, g.call(p.x, p.y), p.y))
		if rng.randf() < 0.08: flowers.append(xf)
		else: grass.append(xf)
	Props.scatter(root, "grass", grass, 45.0, false, 32.0)
	Props.scatter(root, "flower", flowers, 60.0, false, 48.0)
	# Rocks on the ridge and the heights.
	var rocks := {}
	for i in 320:
		var p := Vector2(rng.randf_range(-124, 124), rng.randf_range(-124, 124))
		var on_ridge := absf(p.y - ridge_z(p.x)) < RIDGE_HW
		if not (on_ridge or maxf(absf(p.x), absf(p.y)) > 102.0): continue
		if not clear.call(p, 1.0): continue
		var v := i % 4
		if not rocks.has(v): rocks[v] = []
		var s := rng.randf_range(1.5, 4.5)
		rocks[v].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 0.9), s)), Vector3(p.x, g.call(p.x, p.y) - s * 0.15, p.y)))
	for v in rocks:
		var rm := _rock(v)
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rm.surface_get_arrays(0))
		am.surface_set_material(0, GKit.M("rock"))
		GKit.scatter(root, am, rocks[v], 300.0, true, 64.0)
	# Shafts of light in the clearings.
	var shafts := []
	for p in [Vector3(-20, 0, 30), Vector3(24, 0, 56), Vector3(-60, 0, 90), Vector3(60, 0, 100), Vector3(-30, 0, -40), Vector3(20, 0, -90),
			Vector3(-60, 0, -100), Vector3(80, 0, -60), Vector3(-90, 0, 20), Vector3(90, 0, 10)]:
		shafts.append(Vector3(p.x, g.call(p.x, p.z), p.z))
	GKit.light_shafts(root, shafts, Vector3(-0.35, -0.85, 0.4).normalized())
