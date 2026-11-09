class_name GridaniaBuilder
## Gridania as one continuous city. A forested rock ridge divides New Gridania (south: the
## Aetheryte Plaza, the Carline Canopy and the Roost, the Knot, the Adders' Nest, the Archers'
## Guild, Acorn Orchard, the river and Apkallu Falls, the Blue Badger Gate) from Old Gridania
## (north: Stillglade Fane, the Lancers', Leatherworkers' and Botanists' guilds, Mih Khetto's
## Amphitheatre, the Lotus Stand and the gate to the North Shroud). Three timber-framed,
## lantern-lit tunnels run straight through the ridge, so both halves share one zone.

const WALL := 92.0
const RIDGE_N := -32.0      # north face of the ridge
const RIDGE_S := -16.0      # south face
const RIDGE_H := 13.0
const TUNNELS := [-56.0, 0.0, 56.0]
const TUNNEL_W := 6.5
const TUNNEL_H := 5.2
const RIVER_Z := 46.0
const RIVER_HALF := 6.0
const POND := Vector2(28, -72)
const POND_R := 10.0
const PLAZA := Vector3(0, 0, 8)
const OLD_PLAZA := Vector3(0, 0, -52)

## Where each district begins, for the area title shown when you walk between them.
const DISTRICTS := [["Old Gridania", -24.0], ["New Gridania", 999.0]]


static func build(zone_id: String) -> Dictionary:
	var zd: Dictionary = Data.zones[zone_id]
	var st: Dictionary = CityBuilder.STYLES["gridania"]
	var b: Dictionary = ZoneBuilder.BIOMES[st["biome"]].duplicate()
	var n := ZoneBuilder.N
	var size := ZoneData.SIZE
	var half := size * 0.5
	var sp := size / (n - 1)
	# ---- ground: flat city floor, the river channel, the Lotus Stand pond, hills beyond the walls
	var h := PackedFloat32Array(); h.resize(n * n)
	for iz in n:
		for ix in n:
			var x := -half + ix * sp
			var z := -half + iz * sp
			var y := 0.0
			var rz := absf(z - RIVER_Z)
			if rz < RIVER_HALF + 1.0: y = lerpf(-3.2, 0.0, smoothstep(RIVER_HALF - 2.0, RIVER_HALF + 1.0, rz))
			var pd := Vector2(x, z).distance_to(POND)
			if pd < POND_R + 1.5: y = minf(y, lerpf(-2.6, 0.0, smoothstep(POND_R - 3.0, POND_R + 1.5, pd)))
			if maxf(absf(x), absf(z)) > WALL + 4.0: y = 10.0
			h[iz * n + ix] = y
	var root := Node3D.new(); root.name = "City"
	var exits := [
		{"to": "central_shroud", "dir": "S", "pos": Vector3(0, 0, WALL - 1.0), "gate": "Blue Badger Gate"},
		{"to": "north_shroud", "dir": "W", "pos": Vector3(-WALL + 1.0, 0, -62), "gate": "White Wolf Gate"},
	]
	var info := {"root": root, "heights": h, "n": n, "size": size, "exits": exits, "landmarks": [], "aetheryte": PLAZA,
		"waters": [], "npcs": [], "biome": b, "spawns": [], "nodes": [], "camp": PLAZA + Vector3(0, 0, 20), "interact": [], "city": true,
		"districts": DISTRICTS}
	# ---- cobbled paths
	var paths := [
		[PLAZA, Vector3(0, 0, RIDGE_S)], [PLAZA, Vector3(-56, 0, RIDGE_S)], [PLAZA, Vector3(56, 0, RIDGE_S)],
		[PLAZA, Vector3(0, 0, WALL)], [PLAZA, Vector3(-28, 0, 8)], [PLAZA, Vector3(28, 0, 4)], [PLAZA, Vector3(26, 0, 24)],
		[Vector3(-28, 0, 8), Vector3(-30, 0, 28)], [Vector3(0, 0, 30), Vector3(50, 0, 34)], [Vector3(50, 0, 34), Vector3(54, 0, 62)],
		[Vector3(0, 0, 30), Vector3(-50, 0, 34)], [Vector3(-50, 0, 34), Vector3(-58, 0, 62)],
		[Vector3(0, 0, RIDGE_N), OLD_PLAZA], [Vector3(-56, 0, RIDGE_N), Vector3(-40, 0, -48)], [Vector3(56, 0, RIDGE_N), Vector3(40, 0, -46)],
		[OLD_PLAZA, Vector3(-40, 0, -48)], [OLD_PLAZA, Vector3(40, 0, -46)], [OLD_PLAZA, Vector3(0, 0, -66)],
		[Vector3(-40, 0, -48), Vector3(-WALL, 0, -62)], [Vector3(-40, 0, -48), Vector3(-52, 0, -74)],
		[Vector3(40, 0, -46), Vector3(58, 0, -62)], [Vector3(40, 0, -46), Vector3(28, 0, -60)],
	]
	for tx in TUNNELS:
		paths.append([Vector3(tx, 0, RIDGE_S), Vector3(tx, 0, RIDGE_N)])
	var gb := Dictionary(b); gb["grass_a"] = "#2c4a1e"; gb["grass_b"] = "#456a26"; gb["dirt"] = "#6a5638"
	gb["shore_h"] = -1.4   # sandy banks only at the river and the pond
	var mask := PackedFloat32Array(); mask.resize(n * n)
	for iz in n:
		for ix in n:
			var p := Vector2(-half + ix * sp, -half + iz * sp)
			var road := 0.0
			if p.distance_to(Vector2(PLAZA.x, PLAZA.z)) < 17.0 or p.distance_to(Vector2(OLD_PLAZA.x, OLD_PLAZA.z)) < 12.0: road = 1.0
			for s in paths:
				var w := 4.0 if absf(s[0].x - s[1].x) < 0.1 and s[0].z <= RIDGE_S and s[1].z <= RIDGE_S else 3.2
				if ZoneBuilder._seg_dist(p, Vector2(s[0].x, s[0].z), Vector2(s[1].x, s[1].z)) < w: road = 1.0
			mask[iz * n + ix] = road
	ZoneBuilder._terrain_mesh(root, h, mask, gb)
	var bt := Batcher.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 2207
	var wood := Props.pbr(st["wood"], 0.85)
	var rock := Props.pbr("#6a6656", 0.95)
	var moss := Props.pbr("#3d5a2a", 0.95)
	var gold := Props.pbr("#d6a238", 0.55)
	var lamp := Props.glow("#ffd890", 2.5)
	var trees := []
	var boulders := []
	# ---- the dividing ridge and its three tunnels
	_ridge(root, bt, rng, rock, moss, wood, lamp, trees, boulders)
	# ---- New Gridania: the Aetheryte Plaza on a raised timber deck under golden canopies
	bt.cyl(PLAZA + Vector3(0, 0.25, 0), 15.0, 0.5, "deck", wood, true, -1.0, 24)
	bt.cyl(PLAZA + Vector3(0, 0.08, 0), 16.2, 0.16, "deck2", Props.pbr("#4a3420", 0.9), false, -1.0, 24)
	ZoneBuilder._aetheryte(root, bt, PLAZA + Vector3(0, 0.5, 0))
	for k in 6:
		var a := k * TAU / 6.0 + 0.5
		var p := PLAZA + Vector3(cos(a) * 13.5, 0, sin(a) * 13.5)
		_canopy(bt, p, a + PI * 0.5, gold, wood)
	info["aetheryte"] = PLAZA + Vector3(0, 0.5, 0)
	# Service buildings face the plaza (or their own square in Old Gridania).
	var services := [
		["guild", Vector3(-40, 0, 6), Vector3(24, 0, 18), PLAZA, zd["guild"], 1.35],
		["inn", Vector3(-40, 0, 30), Vector3(14, 0, 11), PLAZA, "The Roost", 1.0],
		["smith", Vector3(40, 0, 0), Vector3(16, 0, 14), PLAZA, "Carpenters' Guild (The Knot)", 1.1],
		["market", Vector3(46, 0, -48), Vector3(16, 0, 13), OLD_PLAZA, "Leatherworkers' Guild", 1.1],
		["trainer", Vector3(-46, 0, -50), Vector3(16, 0, 13), OLD_PLAZA, "Lancers' Guild", 1.1],
	]
	var doors := {}
	for s in services:
		var pos: Vector3 = s[1]; var sz: Vector3 = s[2]; var tgt: Vector3 = s[3]
		var face := _face(pos, tgt)
		CityBuilder._building(bt, root, pos, sz, "gridania", st, face, s[4], true, s[5])
		var front := (Vector3(tgt.x, 0, tgt.z) - pos).normalized()
		doors[s[0]] = pos + front * (sz.z * 0.5 + 1.4)
		_awning(bt, pos + front * (sz.z * 0.5), face, gold, wood)
		info["landmarks"].append({"name": s[4], "pos": doors[s[0]]})
	var gd: Vector3 = doors["guild"]
	var gface := _face(Vector3(-40, 0, 6), PLAZA) - PI
	var gside := Vector3(cos(gface), 0, -sin(gface))
	info["npcs"].append({"role": "guildmaster", "pos": gd, "face": gface, "cast": StoryData.GUILDS[zone_id]["gm"]})
	info["npcs"].append({"role": "leves", "pos": gd + gside * 6.0, "face": gface, "name": "Levemete"})
	info["npcs"].append({"role": "recruiter", "pos": gd - gside * 6.0, "face": gface, "name": "Party Recruiter"})
	for r in [["inn", "Cook"], ["smith", "Smith"], ["market", "Merchant"], ["trainer", "Job Trainer"]]:
		var d: Vector3 = doors[r[0]]
		var tgt: Vector3 = PLAZA if r[0] in ["inn", "smith"] else OLD_PLAZA
		info["npcs"].append({"role": r[0], "pos": d, "face": _face(d, tgt) - PI, "name": r[1]})
	# Landmarks without services.
	var others := [
		[Vector3(34, 0, 24), Vector3(14, 0, 12), PLAZA, "Adders' Nest", 1.2],
		[Vector3(60, 0, 74), Vector3(15, 0, 12), Vector3(54, 0, 60), "Archers' Guild (Quiver's Hold)", 1.0],
		[Vector3(66, 0, -64), Vector3(13, 0, 11), Vector3(40, 0, -46), "Botanists' Guild", 1.0],
	]
	for o in others:
		var face := _face(o[0], o[2])
		CityBuilder._building(bt, root, o[0], o[1], "gridania", st, face, o[3], true, o[4])
		_awning(bt, o[0] + (Vector3(o[2].x, 0, o[2].z) - o[0]).normalized() * (o[1].z * 0.5), face, gold, wood)
		info["landmarks"].append({"name": o[3], "pos": o[0]})
	# The river with three bridges, and Apkallu Falls spilling from the western cliffs.
	info["waters"].append({"kind": "river", "level": -0.6, "z": RIVER_Z, "half": RIVER_HALF})
	ZoneBuilder._water_plane(root, Vector3(0, -0.6, RIVER_Z), Vector2(size, RIVER_HALF * 2.0 + 2.0), b, false)
	for bx in [-50.0, 0.0, 50.0]:
		_bridge(bt, Vector3(bx, 0, RIVER_Z), wood)
	_waterfall(root, bt, Vector3(-WALL + 2.0, 0, RIVER_Z), rock, "Apkallu Falls")
	ZoneBuilder._sign(root, Vector3(-60, 4, 64), "Acorn Orchard", 22)
	for i in 10:
		trees.append(["broadleaf", Vector3(-70 + (i % 5) * 6.0 + rng.randf_range(-1, 1), 0, 58 + int(i / 5) * 9.0)])
	# ---- Old Gridania
	bt.cyl(OLD_PLAZA + Vector3(0, 0.1, 0), 11.0, 0.2, "pave", Props.pbr("#7a6a50", 0.8), false, -1.0, 24)
	bt.cyl(OLD_PLAZA + Vector3(0, 0.45, 0), 2.6, 0.9, "rock", rock, true, 2.8, 16)
	trees.append(["broadleaf", OLD_PLAZA + Vector3(0, 0.9, 0)])
	_fane(root, bt, Vector3(0, 0, -76), wood, gold, moss, trees)
	_amphitheatre(root, bt, Vector3(-60, 0, -76), wood)
	_lotus_stand(root, bt, rng, wood, b, info)
	# ---- cottages filling both districts, kept off paths, water and landmarks
	var keep_out := [Vector3(PLAZA.x, 0, PLAZA.z), OLD_PLAZA, Vector3(0, 0, -76), Vector3(-60, 0, -76), Vector3(POND.x, 0, POND.y)]
	for s in services: keep_out.append(s[1])
	for o in others: keep_out.append(o[0])
	var folk := [PLAZA + Vector3(18, 0, 10), PLAZA + Vector3(-6, 0, 22), Vector3(24, 0, 36), Vector3(-24, 0, 36), Vector3(10, 0, 70),
		Vector3(-58, 0, 56), Vector3(0, 0, -40), OLD_PLAZA + Vector3(8, 0, 6), OLD_PLAZA + Vector3(-9, 0, -4), Vector3(-30, 0, -64),
		Vector3(16, 0, -66), Vector3(50, 0, -76)]
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 600:
		tries += 1
		var p := Vector3(rng.randf_range(-WALL + 10, WALL - 10), 0, rng.randf_range(-WALL + 10, WALL - 10))
		if p.z > RIDGE_N - 9.0 and p.z < RIDGE_S + 9.0: continue
		if absf(p.z - RIVER_Z) < RIVER_HALF + 8.0: continue
		var bad := false
		for k in keep_out:
			if Vector2(p.x - k.x, p.z - k.z).length() < 19.0: bad = true
		for s in paths:
			if ZoneBuilder._seg_dist(Vector2(p.x, p.z), Vector2(s[0].x, s[0].z), Vector2(s[1].x, s[1].z)) < 9.0: bad = true
		for e in exits:
			if Vector2(p.x - e["pos"].x, p.z - e["pos"].z).length() < 18.0: bad = true
		for f in folk:
			if Vector2(p.x - f.x, p.z - f.z).length() < 10.0: bad = true
		if bad: continue
		keep_out.append(p)
		var sz := Vector3(rng.randf_range(8, 12), 0, rng.randf_range(7, 11))
		var tgt := PLAZA if p.z > 0 else OLD_PLAZA
		CityBuilder._building(bt, root, p, sz, "gridania", st, _face(p, tgt), "", false, rng.randf_range(0.85, 1.3))
		placed += 1
	# ---- people: side-quest givers, the story cast and townsfolk on both sides of the ridge
	var side_spots := [PLAZA + Vector3(12, 0.5, 6), PLAZA + Vector3(-12, 0.5, 6), PLAZA + Vector3(10, 0.5, -9), PLAZA + Vector3(-10, 0.5, -9)]
	var si := 0
	for q in StoryData.SIDE:
		if q["city"] == zone_id and si < side_spots.size():
			info["npcs"].append({"role": "side", "pos": side_spots[si], "face": _face(side_spots[si], PLAZA) - PI, "quest": q["id"], "name": q["giver"]})
			si += 1
	for sc in [["orrik", gd + Vector3(6, 0, 7)], ["ysolde", PLAZA + Vector3(14, 0, 14)], ["tatale", PLAZA + Vector3(-15, 0, -6)]]:
		info["npcs"].append({"role": "story", "pos": sc[1], "face": 0.0, "cast": sc[0]})
	for f in folk:
		info["npcs"].append({"role": "citizen", "pos": f, "face": rng.randf() * TAU})
	# ---- rocky outer walls with gate gaps, and the gates themselves
	for sd in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		for k in range(-9, 10):
			var along := Vector3(-sd.z, 0, sd.x) * (k * 10.0)
			var p: Vector3 = sd * WALL + along
			var gap := false
			for e in exits:
				if e["pos"].distance_to(Vector3(p.x, 0, p.z)) < 9.0: gap = true
			if gap: continue
			var hh := rng.randf_range(9.0, 13.0)
			bt.box(p + Vector3(0, hh * 0.5, 0), Vector3(10.4 if sd.x == 0 else 4.0, hh, 4.0 if sd.x == 0 else 10.4), "rock", rock)
			bt.box(p + Vector3(0, hh + 0.15, 0), Vector3(11.0 if sd.x == 0 else 4.6, 0.3, 4.6 if sd.x == 0 else 11.0), "moss", moss, false)
	for e in exits:
		ZoneBuilder._zone_gate(root, bt, e["pos"], e["dir"], Data.zones[e["to"]]["name"])
		ZoneBuilder._sign(root, e["pos"] + Vector3(0, 6.2, 0), e["gate"], 26)
	# ---- forest: giant trees around the edges, broadleaves and bushes in the districts, flowers
	for i in 22:
		var a := rng.randf() * TAU; var r := rng.randf_range(70, 88)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.z - RIVER_Z) < RIVER_HALF + 2.0: continue
		if p.z > RIDGE_N - 3.0 and p.z < RIDGE_S + 3.0: continue
		trees.append(["giant", p])
	var placed_t := 0
	while placed_t < 46:
		var p := Vector3(rng.randf_range(-WALL + 6, WALL - 6), 0, rng.randf_range(-WALL + 6, WALL - 6))
		placed_t += 1
		if p.z > RIDGE_N - 3.0 and p.z < RIDGE_S + 3.0: continue
		if absf(p.z - RIVER_Z) < RIVER_HALF + 1.5: continue
		if Vector2(p.x, p.z).distance_to(POND) < POND_R + 2.0: continue
		var bad := false
		for k in keep_out:
			if Vector2(p.x - k.x, p.z - k.z).length() < 11.0: bad = true
		for s in paths:
			if ZoneBuilder._seg_dist(Vector2(p.x, p.z), Vector2(s[0].x, s[0].z), Vector2(s[1].x, s[1].z)) < 4.5: bad = true
		if bad: continue
		trees.append(["broadleaf" if placed_t % 3 else "bush", p])
	var flowers := []
	for s in paths:
		var a3: Vector3 = s[0]; var b3: Vector3 = s[1]
		var steps := int(a3.distance_to(b3) / 7.0)
		var side := Vector3(-(b3 - a3).z, 0, (b3 - a3).x).normalized()
		for k in steps:
			var p := a3.lerp(b3, (k + 0.5) / maxf(1, steps)) + side * (4.6 if k % 2 == 0 else -4.6)
			if absf(p.z - RIVER_Z) < RIVER_HALF + 1.0 or (p.z > RIDGE_N - 1.0 and p.z < RIDGE_S + 1.0): continue
			if k % 2 == 0:
				bt.cyl(p + Vector3(0, 1.7, 0), 0.12, 3.4, "post", wood, false)
				bt.box(p + Vector3(0, 3.5, 0), Vector3(0.45, 0.55, 0.45), "lamp", lamp, false)
			else:
				flowers.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
	Props.scatter(root, "flower", flowers, 120.0, false, 80.0)
	var tl := {}
	for t in trees:
		if not tl.has(t[0]): tl[t[0]] = []
		tl[t[0]].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), t[1]))
		if t[0] != "bush" and t[1].y < 1.0:
			var cs := CylinderShape3D.new(); cs.radius = 1.4 if t[0] == "giant" else 0.35; cs.height = 6.0
			bt.collider(cs, Transform3D(Basis(), t[1] + Vector3(0, 3, 0)))
	for k in tl: Props.scatter(root, k, tl[k], 300.0, true, 80.0)
	Props.scatter(root, "boulder", boulders, 300.0, true, 80.0)
	bt.commit(root)
	ZoneBuilder._edge_walls(root)
	return info


## Yaw that turns a building at `p` so its front (door side) faces `target`.
static func _face(p: Vector3, target: Vector3) -> float:
	var d := target - p
	return atan2(d.x, d.z) + PI


## The ridge: solid rock with moss on top, boulders along both faces, trees on the crest, and three
## tunnels framed in timber and lit by lanterns.
static func _ridge(root: Node3D, bt: Batcher, rng: RandomNumberGenerator, rock: Material, moss: Material, wood: Material,
		lamp: Material, trees: Array, boulders: Array) -> void:
	var zc := (RIDGE_N + RIDGE_S) * 0.5
	var depth := RIDGE_S - RIDGE_N
	var edges := [-WALL - 2.0]
	for tx in TUNNELS:
		edges.append(tx - TUNNEL_W * 0.5); edges.append(tx + TUNNEL_W * 0.5)
	edges.append(WALL + 2.0)
	for i in range(0, edges.size(), 2):
		var x0: float = edges[i]; var x1: float = edges[i + 1]
		var hh := RIDGE_H + rng.randf_range(-1.0, 1.5)
		bt.box(Vector3((x0 + x1) * 0.5, hh * 0.5, zc), Vector3(x1 - x0, hh, depth), "rock", rock)
		bt.box(Vector3((x0 + x1) * 0.5, hh + 0.2, zc), Vector3(x1 - x0 + 0.8, 0.4, depth + 0.8), "moss", moss, false)
		# Crest trees and face boulders.
		var x := x0 + 4.0
		while x < x1 - 4.0:
			trees.append(["broadleaf" if rng.randf() < 0.6 else "giant", Vector3(x + rng.randf_range(-2, 2), hh + 0.3, zc + rng.randf_range(-5, 5))])
			for fz in [RIDGE_N - 0.5, RIDGE_S + 0.5]:
				var s := rng.randf_range(1.6, 3.2)
				boulders.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.2), s)),
					Vector3(x + rng.randf_range(-3, 3), rng.randf_range(0.0, 4.0), fz)))
			x += rng.randf_range(7.0, 11.0)
	# Buttresses of rock jutting from both faces break up the long wall, clear of the tunnel mouths.
	var bx := -WALL + 2.0
	while bx < WALL - 2.0:
		var clear := true
		for tx in TUNNELS:
			if absf(bx - tx) < TUNNEL_W * 0.5 + 3.0: clear = false
		if clear:
			for face_z in [RIDGE_N, RIDGE_S]:
				var out := -1.0 if face_z == RIDGE_N else 1.0
				var hh := RIDGE_H * rng.randf_range(0.45, 1.05)
				var d := rng.randf_range(1.2, 3.0)
				var w := rng.randf_range(3.0, 6.0)
				var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.25, 0.25)), Vector3(bx, hh * 0.5, face_z + out * d * 0.5))
				var bm := BoxMesh.new(); bm.size = Vector3(w, hh, d + 1.0)
				bt.add(bm, xf, "rock", rock)
				var sh := BoxShape3D.new(); sh.size = bm.size
				bt.collider(sh, xf)
				var mm := BoxMesh.new(); mm.size = Vector3(w + 0.3, 0.3, d + 1.3)
				bt.add(mm, Transform3D(xf.basis, xf.origin + Vector3(0, hh * 0.5 + 0.1, 0)), "moss", moss, false)
		bx += rng.randf_range(4.5, 7.5)
	for tx in TUNNELS:
		# Rock over the passage, a plank ceiling, timber frames and lanterns.
		bt.box(Vector3(tx, (TUNNEL_H + RIDGE_H) * 0.5, zc), Vector3(TUNNEL_W + 0.2, RIDGE_H - TUNNEL_H, depth), "rock", rock)
		bt.box(Vector3(tx, RIDGE_H + 0.2, zc), Vector3(TUNNEL_W + 1.0, 0.4, depth + 0.8), "moss", moss, false)
		bt.box(Vector3(tx, TUNNEL_H - 0.15, zc), Vector3(TUNNEL_W, 0.3, depth), "plank", wood, false)
		var z := RIDGE_N
		while z <= RIDGE_S + 0.01:
			for sx in [-1.0, 1.0]:
				bt.box(Vector3(tx + sx * (TUNNEL_W * 0.5 - 0.3), TUNNEL_H * 0.5, z), Vector3(0.45, TUNNEL_H, 0.45), "beam", wood, false)
			bt.box(Vector3(tx, TUNNEL_H - 0.45, z), Vector3(TUNNEL_W, 0.5, 0.5), "beam", wood, false)
			if absf(z - zc) < 4.5:
				for sx in [-1.0, 1.0]:
					bt.box(Vector3(tx + sx * (TUNNEL_W * 0.5 - 0.6), 3.0, z + 0.4), Vector3(0.35, 0.45, 0.35), "lamp", lamp, false)
			z += 4.0
		# Larger arched frames at each mouth.
		for mz in [RIDGE_N - 0.4, RIDGE_S + 0.4]:
			for sx in [-1.0, 1.0]:
				bt.box(Vector3(tx + sx * (TUNNEL_W * 0.5 + 0.2), (TUNNEL_H + 0.8) * 0.5, mz), Vector3(0.7, TUNNEL_H + 0.8, 0.7), "beam", wood, false)
			bt.box(Vector3(tx, TUNNEL_H + 0.6, mz), Vector3(TUNNEL_W + 1.8, 0.7, 0.8), "beam", wood, false)
		ZoneBuilder._sign(root, Vector3(tx, TUNNEL_H + 2.0, RIDGE_S + 1.0), "To Old Gridania", 22)
		ZoneBuilder._sign(root, Vector3(tx, TUNNEL_H + 2.0, RIDGE_N - 1.0), "To New Gridania", 22)
		var light := OmniLight3D.new()
		light.light_color = Color("#ffc878"); light.light_energy = 1.5; light.omni_range = 11.0
		light.position = Vector3(tx, 3.4, zc); light.shadow_enabled = false
		light.distance_fade_enabled = true; light.distance_fade_begin = 60.0; light.distance_fade_length = 20.0
		root.add_child(light)


## A golden fabric canopy on a timber frame, as found around the plazas.
static func _canopy(bt: Batcher, p: Vector3, yaw: float, gold: Material, wood: Material) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		bt.add(_box(0.25, 4.2, 0.25), Transform3D(basis, p + basis * Vector3(sx * 2.4, 2.1, 0)), "beam", wood)
	var tilt := basis * Basis(Vector3.RIGHT, deg_to_rad(18))
	bt.add(_box(5.6, 0.08, 3.0), Transform3D(tilt, p + Vector3(0, 4.3, 0)), "gold", gold, false)


## A gold awning over a doorway.
static func _awning(bt: Batcher, front: Vector3, face: float, gold: Material, wood: Material) -> void:
	var basis := Basis(Vector3.UP, face)
	var out := basis * Vector3(0, 0, -1)
	var tilt := basis * Basis(Vector3.RIGHT, deg_to_rad(-20))
	bt.add(_box(5.0, 0.08, 2.4), Transform3D(tilt, front + out * 1.1 + Vector3(0, 3.9, 0)), "gold", gold, false)
	for sx in [-1.0, 1.0]:
		bt.add(_box(0.18, 3.8, 0.18), Transform3D(basis, front + out * 2.2 + basis * Vector3(sx * 2.3, 1.9, 0)), "beam", wood, false)


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new(); m.size = Vector3(x, y, z)
	return m


static func _bridge(bt: Batcher, c: Vector3, wood: Material) -> void:
	var span := RIVER_HALF * 2.0 + 4.0
	bt.box(c + Vector3(0, 0.3, 0), Vector3(5.0, 0.4, span), "deck", wood)
	for sx in [-1.0, 1.0]:
		bt.box(c + Vector3(sx * 2.4, 1.05, 0), Vector3(0.15, 0.12, span), "beam", wood, false)
		var k := -span * 0.5
		while k <= span * 0.5:
			bt.box(c + Vector3(sx * 2.4, 0.7, k), Vector3(0.18, 0.8, 0.18), "beam", wood, false)
			k += 2.0
	# Arch ribs beneath the deck.
	for i in 7:
		var t := float(i) / 6.0
		var z := lerpf(-span * 0.45, span * 0.45, t)
		var y := -0.2 - sin(t * PI) * 1.4
		bt.box(c + Vector3(0, y, z), Vector3(4.6, 0.3, 1.6), "beam", wood, false)


static func _waterfall(root: Node3D, bt: Batcher, p: Vector3, rock: Material, name: String) -> void:
	bt.box(p + Vector3(-2.0, 6.0, 0), Vector3(6.0, 12.0, 18.0), "rock", rock)
	var q := QuadMesh.new(); q.size = Vector2(7.0, 10.5)
	var mi := MeshInstance3D.new(); mi.mesh = q
	mi.material_override = FX.mat(Color("#d8f2ff"), 1.2, 0.55)
	mi.position = p + Vector3(1.05, 4.6, 0)
	mi.rotation.y = PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var foam := CPUParticles3D.new()
	foam.amount = 40; foam.lifetime = 1.4
	foam.position = p + Vector3(2.0, -0.3, 0)
	foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; foam.emission_box_extents = Vector3(1.0, 0.2, 3.2)
	foam.direction = Vector3(1, 1, 0); foam.spread = 40.0; foam.initial_velocity_min = 0.8; foam.initial_velocity_max = 1.8
	foam.gravity = Vector3(0, -2.0, 0)
	var qm := QuadMesh.new(); qm.size = Vector2(0.5, 0.5)
	qm.material = FX.mat(Color("#ffffff"), 1.0, 0.5)
	foam.mesh = qm
	root.add_child(foam)
	ZoneBuilder._sign(root, p + Vector3(5, 7.0, 0), name, 24)


## Stillglade Fane, the seat of the Conjurers' Guild: an open round pavilion before a giant tree.
static func _fane(root: Node3D, bt: Batcher, c: Vector3, wood: Material, gold: Material, moss: Material, trees: Array) -> void:
	bt.cyl(c + Vector3(0, 0.35, 0), 9.0, 0.7, "deck", wood, true, -1.0, 24)
	for k in 10:
		var a := k * TAU / 10.0
		bt.cyl(c + Vector3(cos(a) * 7.8, 3.6, sin(a) * 7.8), 0.3, 5.8, "beam", wood, false)
	var roof := CylinderMesh.new(); roof.top_radius = 0.6; roof.bottom_radius = 10.5; roof.height = 4.0; roof.radial_segments = 20
	bt.add(roof, Transform3D(Basis(), c + Vector3(0, 8.4, 0)), "roof", Props.pbr("#4a5a2a", 0.85), false)
	bt.cyl(c + Vector3(0, 6.6, 0), 10.6, 0.4, "gold", gold, false, -1.0, 20)
	trees.append(["giant", c + Vector3(0, 0, -16)])
	trees.append(["giant", c + Vector3(-12, 0, -12)])
	trees.append(["giant", c + Vector3(12, 0, -12)])
	ZoneBuilder._sign(root, c + Vector3(0, 12.0, 0), "Stillglade Fane (Conjurers' Guild)", 28)


## Mih Khetto's Amphitheatre: tiers of timber seating around a round stage.
static func _amphitheatre(root: Node3D, bt: Batcher, c: Vector3, wood: Material) -> void:
	bt.cyl(c + Vector3(0, 0.3, 0), 5.0, 0.6, "deck", wood, true, -1.0, 20)
	for tier in 4:
		var r := 8.0 + tier * 1.8
		var hgt := 0.5 * (tier + 1)
		for k in 11:
			var a := PI * 0.5 + (float(k) / 10.0 - 0.5) * PI * 1.1 + PI
			var p := c + Vector3(cos(a) * r, hgt * 0.5, sin(a) * r)
			bt.add(_box(3.4, hgt, 1.8), Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p), "seat", wood)
	ZoneBuilder._sign(root, c + Vector3(0, 6.5, 0), "Mih Khetto's Amphitheatre", 26)


## The Lotus Stand: a quiet pond with lily pads and a timber viewing stand.
static func _lotus_stand(root: Node3D, bt: Batcher, rng: RandomNumberGenerator, wood: Material, b: Dictionary, info: Dictionary) -> void:
	info["waters"].append({"kind": "lake", "level": -0.5, "center": POND, "radius": POND_R})
	ZoneBuilder._water_plane(root, Vector3(POND.x, -0.5, POND.y), Vector2(POND_R * 2.2, POND_R * 2.2), b, false)
	var pad := Props.pbr("#4a7a3a", 0.6)
	var bloom := Props.pbr("#f0b8d0", 0.5)
	for i in 16:
		var a := rng.randf() * TAU; var r := rng.randf_range(1.5, POND_R - 2.0)
		var p := Vector3(POND.x + cos(a) * r, -0.46, POND.y + sin(a) * r)
		bt.cyl(p, rng.randf_range(0.5, 0.9), 0.04, "pad", pad, false, -1.0, 10)
		if i % 3 == 0: bt.cyl(p + Vector3(0, 0.12, 0), 0.18, 0.2, "bloom", bloom, false, 0.05, 8)
	var stand := Vector3(POND.x, 0, POND.y + POND_R + 1.0)
	bt.box(stand + Vector3(0, 0.3, -2.0), Vector3(5.0, 0.4, 6.0), "deck", wood)
	ZoneBuilder._sign(root, stand + Vector3(0, 4.0, 0), "The Lotus Stand", 24)
	info["landmarks"].append({"name": "The Lotus Stand", "pos": stand})
