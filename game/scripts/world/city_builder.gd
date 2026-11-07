class_name CityBuilder
## Lays out the four starting cities from architectural kits. Each city keeps its identity
## (Limsa's white stone over the sea, Gridania's timber and waterways beneath giant trees,
## Ul'dah's sandstone domes and walls, Ishgard's snow-dusted gothic spires) while sharing a
## readable layout: aetheryte plaza, adventurers' guild, kitchen, smithy, market, job trainer.

const STYLES := {
	"limsa": {"biome": "coast", "ground": "#d8d2c2", "wall": "#ece6d8", "trim": "#2f6f8a", "roof": "#3a7c94", "wood": "#7a5a3a", "wall_h": 4.0, "ground_y": 2.0},
	"gridania": {"biome": "forest", "ground": "#5a4a34", "wall": "#8a6a46", "trim": "#4a6a2c", "roof": "#5a4a2a", "wood": "#5a3e26", "wall_h": 3.0, "ground_y": 0.0},
	"uldah": {"biome": "desert", "ground": "#c8a878", "wall": "#d8bc88", "trim": "#a8343a", "roof": "#c8a060", "wood": "#7a5030", "wall_h": 12.0, "ground_y": 0.0},
	"ishgard": {"biome": "snow", "ground": "#9a9ca2", "wall": "#8a8c94", "trim": "#2a3a5a", "roof": "#3a3e4a", "wood": "#4a3a2a", "wall_h": 9.0, "ground_y": 0.0},
}
const WALL := 92.0
## Familiar city landmarks used for the service buildings.
const NAMES := {
	"limsa": {"inn": "The Bismarck", "smith": "Blacksmiths' Guild", "market": "Hawkers' Alley", "trainer": "Marauders' Guild"},
	"gridania": {"inn": "The Roost", "smith": "Carpenters' Guild", "market": "Leatherworkers' Guild", "trainer": "Lancers' Guild"},
	"uldah": {"inn": "The Hourglass", "smith": "Goldsmiths' Guild", "market": "Sapphire Avenue Exchange", "trainer": "Gladiators' Guild"},
	"ishgard": {"inn": "Cloud Nine", "smith": "Skysteel Manufactory", "market": "The Jeweled Crozier", "trainer": "Fortemps Manor"},
}


static func build(zone_id: String) -> Dictionary:
	var zd: Dictionary = Data.zones[zone_id]
	var st: Dictionary = STYLES[zd["style"]]
	var b: Dictionary = ZoneBuilder.BIOMES[st["biome"]].duplicate()
	var n := ZoneBuilder.N
	var size := ZoneData.SIZE
	var half := size * 0.5
	var sp := size / (n - 1)
	var gy: float = st["ground_y"]
	var style: String = zd["style"]
	var h := PackedFloat32Array(); h.resize(n * n)
	for iz in n:
		for ix in n:
			var x := -half + ix * sp
			var z := -half + iz * sp
			var y := gy
			var edge := maxf(absf(x), absf(z))
			if style == "limsa":
				# Limsa stands on a stone shelf above the sea: open water to the south and west.
				if (z > WALL - 4.0 or x < -WALL + 4.0) and edge > WALL - 4.0: y = -8.0
				if edge > WALL + 6.0: y = -8.0 if (z > 0 or x < 0) else gy + 14.0
			elif style == "gridania":
				var rz := absf(z - 42.0)
				if rz < 7.0: y = lerpf(-3.2, gy, smoothstep(4.0, 7.0, rz))
				if edge > WALL + 4.0: y = gy + 10.0
			else:
				if edge > WALL + 4.0: y = gy + 16.0
			h[iz * n + ix] = y
	var root := Node3D.new(); root.name = "City"
	var exits := []
	for e in zd["exits"]:
		var p := ZoneBuilder.exit_pos(e["dir"], half - WALL + 3.0)
		p.y = gy
		exits.append({"to": e["to"], "dir": e["dir"], "pos": p})
	var info := {"root": root, "heights": h, "n": n, "size": size, "exits": exits, "landmarks": [], "aetheryte": Vector3(0, gy, 0),
		"waters": [], "npcs": [], "biome": b, "spawns": [], "nodes": [], "camp": Vector3(0, gy, 30), "interact": [], "city": true}
	var gb := Dictionary(b); gb["grass_a"] = st["ground"]; gb["grass_b"] = st["ground"]; gb["dirt"] = st["ground"]
	if style == "gridania": gb["grass_a"] = "#2c4a1e"; gb["grass_b"] = "#456a26"; gb["dirt"] = "#6a5638"
	if style == "ishgard": gb["grass_a"] = "#e6eaf0"; gb["grass_b"] = "#d8dee6"; gb["dirt"] = "#8a8c94"
	var mask := PackedFloat32Array(); mask.resize(n * n)
	for iz in n:
		for ix in n:
			var x := -half + ix * sp
			var z := -half + iz * sp
			var road := 0.0
			if Vector2(x, z).length() < 22.0: road = 1.0
			for e in exits:
				var ep: Vector3 = e["pos"]
				if ZoneBuilder._seg_dist(Vector2(x, z), Vector2.ZERO, Vector2(ep.x, ep.z)) < 5.5: road = 1.0
			mask[iz * n + ix] = road
	ZoneBuilder._terrain_mesh(root, h, mask, gb)
	var bt := Batcher.new()
	var wall_m := Props.pbr(st["wall"], 0.8)
	var trim_m := Props.pbr(st["trim"], 0.6)
	var roof_m := Props.pbr(st["roof"], 0.7)
	var wood_m := Props.pbr(st["wood"], 0.85)
	var ground_m := Props.pbr(st["ground"], 0.75)
	# plaza paving and aetheryte
	bt.cyl(Vector3(0, gy + 0.05, 0), 18.0, 0.1, "pave", Props.pbr(Color(st["ground"]).lightened(0.12).to_html(), 0.6), false, -1.0, 32)
	ZoneBuilder._aetheryte(root, bt, Vector3(0, gy, 0))
	# --- service buildings around the plaza
	var guild_name: String = zd["guild"]
	var nm: Dictionary = NAMES[zone_id]
	var services := [
		["guild", Vector3(0, gy, -34), Vector3(22, 0, 14), guild_name],
		["inn", Vector3(34, gy, -4), Vector3(14, 0, 16), nm["inn"]],
		["smith", Vector3(-34, gy, -4), Vector3(14, 0, 14), nm["smith"]],
		["market", Vector3(28, gy, 30), Vector3(14, 0, 12), nm["market"]],
		["trainer", Vector3(-28, gy, 30), Vector3(14, 0, 12), nm["trainer"]],
	]
	for s in services:
		var pos: Vector3 = s[1]
		var face := atan2(-pos.x, -pos.z) + PI
		_building(bt, root, pos, s[2], style, st, face, s[3], true)
	var guild_door := Vector3(0, gy, -25)
	info["npcs"].append({"role": "guildmaster", "pos": guild_door + Vector3(0, 0, 1.5), "face": 0.0, "cast": StoryData.GUILDS[zone_id]["gm"]})
	info["npcs"].append({"role": "leves", "pos": guild_door + Vector3(6, 0, 1.5), "face": 0.0, "name": "Levemete"})
	info["npcs"].append({"role": "recruiter", "pos": guild_door + Vector3(-6, 0, 1.5), "face": 0.0, "name": "Party Recruiter"})
	info["npcs"].append({"role": "inn", "pos": Vector3(25.5, gy, -4), "face": -PI * 0.5, "name": "Cook"})
	info["npcs"].append({"role": "smith", "pos": Vector3(-25.5, gy, -4), "face": PI * 0.5, "name": "Smith"})
	info["npcs"].append({"role": "market", "pos": Vector3(22, gy, 24), "face": -PI * 0.75, "name": "Merchant"})
	info["npcs"].append({"role": "trainer", "pos": Vector3(-22, gy, 24), "face": PI * 0.75, "name": "Job Trainer"})
	var side_spots := [Vector3(12, gy, 14), Vector3(-12, gy, 14), Vector3(16, gy, -16), Vector3(-16, gy, -16)]
	var si := 0
	for q in StoryData.SIDE:
		if q["city"] == zone_id and si < side_spots.size():
			info["npcs"].append({"role": "side", "pos": side_spots[si], "face": atan2(side_spots[si].x, side_spots[si].z), "quest": q["id"], "name": q["giver"]})
			si += 1
	if zd.has("ferry"):
		info["npcs"].append({"role": "ferry", "pos": Vector3(-WALL + 8, gy, 50), "face": PI * 0.5, "name": "Ferry Skipper"})
		bt.box(Vector3(-WALL - 4, gy - 0.4, 50), Vector3(16, 0.8, 5), "wood", wood_m)
		ZoneBuilder._sign(root, Vector3(-WALL + 6, gy + 3.5, 50), zd["ferry"]["name"], 22)
	for i in 8:
		var a := i * TAU / 8.0 + 0.3
		info["npcs"].append({"role": "citizen", "pos": Vector3(cos(a) * 26.0, gy, sin(a) * 26.0 + 6.0), "face": -a})
	# --- filler buildings along the streets
	var rng := RandomNumberGenerator.new(); rng.seed = hash(zone_id)
	for i in 34:
		var a := rng.randf() * TAU
		var r := rng.randf_range(48.0, WALL - 12.0)
		var p := Vector3(cos(a) * r, gy, sin(a) * r)
		var blocked := false
		for e in exits:
			var ep: Vector3 = e["pos"]
			if ZoneBuilder._seg_dist(Vector2(p.x, p.z), Vector2.ZERO, Vector2(ep.x, ep.z)) < 13.0: blocked = true
		if style == "gridania" and absf(p.z - 42.0) < 12.0: blocked = true
		if blocked: continue
		var sz := Vector3(rng.randf_range(8, 14), 0, rng.randf_range(8, 13))
		_building(bt, root, p, sz, style, st, atan2(-p.x, -p.z) + PI, "", false, rng.randf_range(0.8, 1.6))
	# --- perimeter walls with gate gaps
	for side in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		if style == "limsa" and (side.z > 0 or side.x < 0):
			# sea side: low parapet with gaps so you can dive in
			for k in range(-9, 10):
				if k % 3 == 0: continue
				var along := Vector3(-side.z, 0, side.x) * (k * 10.0)
				bt.box(side * WALL + along + Vector3(0, gy + 0.6, 0), Vector3(8.0 if side.x == 0 else 1.0, 1.2, 1.0 if side.x == 0 else 8.0), "wall", wall_m)
			continue
		for k in range(-9, 10):
			var along := Vector3(-side.z, 0, side.x) * (k * 10.0)
			var p = side * WALL + along
			var gap := false
			for e in exits:
				if e["pos"].distance_to(Vector3(p.x, e["pos"].y, p.z)) < 9.0: gap = true
			if gap: continue
			var wh: float = st["wall_h"] + 3.0
			bt.box(p + Vector3(0, gy + wh * 0.5, 0), Vector3(10.2 if side.x == 0 else 2.0, wh, 2.0 if side.x == 0 else 10.2), "wall", wall_m)
			if k % 3 == 0: bt.box(p + Vector3(0, gy + wh + 1.0, 0), Vector3(3, 2, 3), "trim", trim_m)
	for e in exits:
		ZoneBuilder._zone_gate(root, bt, e["pos"], e["dir"], Data.zones[e["to"]]["name"])
	# --- style set-pieces
	var trees := []
	var dec := []
	match style:
		"limsa":
			bt.cyl(Vector3(-70, gy + 14, -70), 4.0, 28.0, "wall", wall_m, true, 3.2, 16)
			bt.cyl(Vector3(-70, gy + 29.5, -70), 4.6, 3.0, "trim", trim_m, false, 3.8, 16)
			var beacon := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 2.0; bs.height = 4.0; beacon.mesh = bs
			beacon.material_override = Props.glow("#ffe8a0", 4.0); beacon.position = Vector3(-70, gy + 32, -70); root.add_child(beacon)
			ZoneBuilder._sign(root, Vector3(-70, gy + 36, -70), "The Lominsan Lighthouse", 28)
			for k in 6: bt.box(Vector3(-20 + k * 8, gy + 3.5, 60), Vector3(0.8, 7.0, 0.8), "trim", trim_m)
			bt.box(Vector3(0, gy + 7.2, 60), Vector3(48, 0.6, 6), "trim", trim_m)
			ZoneBuilder._sign(root, Vector3(0, gy + 9, 60), "Bulwark Hall Arches", 22)
			info["waters"].append({"kind": "sea", "level": 0.0, "dir": Vector2(-0.7, 0.7), "from": -999.0})
			ZoneBuilder._water_plane(root, Vector3(0, 0, 0), Vector2(size * 3, size * 3), b, true)
			for i in 26:
				var a := rng.randf() * TAU; var r := rng.randf_range(40, 85)
				trees.append(["palm", Vector3(cos(a) * r, gy, sin(a) * r)])
			# stairs into the sea so swimmers can climb back up
			for k in 6:
				bt.box(Vector3(-30, gy - 1.0 - k * 0.9, WALL + 1.5 + k * 1.4), Vector3(8, 0.9, 1.4), "pave2", ground_m)
		"gridania":
			info["waters"].append({"kind": "river", "level": -0.6, "z": 42.0, "half": 6.5})
			ZoneBuilder._water_plane(root, Vector3(0, -0.6, 42), Vector2(size, 14), b, false)
			for bx in [-50.0, 0.0, 50.0]:
				bt.box(Vector3(bx, gy + 0.3, 42), Vector3(6, 0.4, 16), "wood", wood_m)
				bt.box(Vector3(bx + 2.8, gy + 1.0, 42), Vector3(0.2, 1.2, 16), "wood", wood_m, false)
				bt.box(Vector3(bx - 2.8, gy + 1.0, 42), Vector3(0.2, 1.2, 16), "wood", wood_m, false)
			for i in 14:
				var a := rng.randf() * TAU; var r := rng.randf_range(55, 88)
				trees.append(["giant", Vector3(cos(a) * r, gy, sin(a) * r)])
			for i in 30:
				var a := rng.randf() * TAU; var r := rng.randf_range(24, 88)
				trees.append(["broadleaf" if i % 3 else "bush", Vector3(cos(a) * r, gy, sin(a) * r)])
			ZoneBuilder._sign(root, Vector3(-40, gy + 6, -60), "Stillglade Fane", 24)
			bt.box(Vector3(-40, gy + 2.5, -64), Vector3(16, 5, 10), "wood", wood_m)
		"uldah":
			bt.cyl(Vector3(-50, gy + 6, -55), 18.0, 12.0, "wall", wall_m, true, 18.0, 28)
			bt.cyl(Vector3(-50, gy + 12.5, -55), 18.6, 1.0, "trim", trim_m, false, 18.6, 28)
			ZoneBuilder._sign(root, Vector3(-50, gy + 16, -55), "The Coliseum", 28)
			for i in 20:
				var a := rng.randf() * TAU; var r := rng.randf_range(30, 85)
				trees.append(["palm", Vector3(cos(a) * r, gy, sin(a) * r)])
			for k in 8:
				var a := k * TAU / 8.0
				bt.box(Vector3(cos(a) * 20, gy + 3.5, sin(a) * 20), Vector3(1.2, 7, 1.2), "trim2", Props.pbr("#e8d0a0", 0.5))
		"ishgard":
			bt.box(Vector3(0, gy + 10, -70), Vector3(26, 20, 18), "wall", wall_m)
			var spire := PrismMesh.new(); spire.size = Vector3(10, 26, 10)
			bt.add(spire, Transform3D(Basis(), Vector3(0, gy + 33, -70)), "roof", roof_m)
			ZoneBuilder._sign(root, Vector3(0, gy + 48, -70), "The Vault", 30)
			for i in 26:
				var a := rng.randf() * TAU; var r := rng.randf_range(30, 85)
				dec.append(Vector3(cos(a) * r, gy, sin(a) * r))
			for p in dec:
				bt.cyl(p + Vector3(0, 0.8, 0), 0.25, 1.6, "trim", trim_m, false)
				bt.cyl(p + Vector3(0, 1.75, 0), 0.4, 0.3, "fire", Props.glow("#ffa040", 3.0), false)
	var tl := {}
	for t in trees:
		if not tl.has(t[0]): tl[t[0]] = []
		tl[t[0]].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)), t[1]))
		if t[0] != "bush":
			var cs := CylinderShape3D.new(); cs.radius = 1.4 if t[0] == "giant" else 0.35; cs.height = 6.0
			bt.collider(cs, Transform3D(Basis(), t[1] + Vector3(0, 3, 0)))
	for k in tl: Props.scatter(root, k, tl[k], 300.0, true, 80.0)
	# lanterns along the main avenues
	for e in exits:
		var ep: Vector3 = e["pos"]
		for k in range(1, 5):
			var p := ep * (k / 5.0)
			var side := Vector3(-ep.z, 0, ep.x).normalized() * 5.5
			for s in [1.0, -1.0]:
				var lp = p + side * s
				bt.cyl(Vector3(lp.x, gy + 1.6, lp.z), 0.12, 3.2, "post", wood_m, false)
				bt.box(Vector3(lp.x, gy + 3.35, lp.z), Vector3(0.45, 0.5, 0.45), "lamp", Props.glow("#ffd890", 2.5), false)
	bt.commit(root)
	ZoneBuilder._edge_walls(root)
	return info


## A building: walls with windows and a door, roof in the city's style, optional name sign.
static func _building(bt: Batcher, root: Node3D, pos: Vector3, size: Vector3, style: String, st: Dictionary, face: float, sign: String, big: bool, hmul := 1.0) -> void:
	var wh: float = (6.0 if big else 4.5) * hmul * (1.4 if style == "uldah" else 1.0)
	var basis := Basis(Vector3.UP, face)
	var wall_m := Props.pbr(st["wall"], 0.8)
	var trim_m := Props.pbr(st["trim"], 0.6)
	var roof_m := Props.pbr(st["roof"], 0.7)
	var dark := Props.pbr("#1a1612", 0.9)
	var bm := BoxMesh.new(); bm.size = Vector3(size.x, wh, size.z)
	var xf := Transform3D(basis, pos + Vector3(0, wh * 0.5, 0))
	bt.add(bm, xf, "wall", wall_m)
	var sh := BoxShape3D.new(); sh.size = Vector3(size.x, wh, size.z)
	bt.collider(sh, xf)
	# trim band, door and windows on the front (local -Z faces the plaza after rotation)
	var front := basis * Vector3(0, 0, -size.z * 0.5 - 0.06)
	var right := basis * Vector3(1, 0, 0)
	var tb := BoxMesh.new(); tb.size = Vector3(size.x + 0.3, 0.5, size.z + 0.3)
	bt.add(tb, Transform3D(basis, pos + Vector3(0, wh - 0.25, 0)), "trim", trim_m)
	var door := BoxMesh.new(); door.size = Vector3(2.4 if big else 1.6, 3.2 if big else 2.5, 0.1)
	bt.add(door, Transform3D(basis, pos + front + Vector3(0, (3.2 if big else 2.5) * 0.5, 0)), "dark", dark, false)
	var win := BoxMesh.new(); win.size = Vector3(1.1, 1.3, 0.1)
	var nwin := int(size.x / 3.5)
	for i in nwin:
		var off := (i - (nwin - 1) * 0.5) * 3.2
		if absf(off) < 2.0: continue
		bt.add(win, Transform3D(basis, pos + front + right * off + Vector3(0, wh * 0.6, 0)), "window", Props.glow("#ffd9a0", 0.6), false)
	match style:
		"limsa":
			var aw := BoxMesh.new(); aw.size = Vector3(size.x * 0.7, 0.12, 2.2)
			bt.add(aw, Transform3D(basis * Basis(Vector3.RIGHT, deg_to_rad(-15)), pos + front * 1.0 + basis * Vector3(0, 0, -1.0) + Vector3(0, 3.4, 0)), "trim", trim_m, false)
			var rf := BoxMesh.new(); rf.size = Vector3(size.x + 0.6, 0.4, size.z + 0.6)
			bt.add(rf, Transform3D(basis, pos + Vector3(0, wh + 0.2, 0)), "roof", roof_m)
		"gridania":
			var pr := PrismMesh.new(); pr.size = Vector3(size.x + 1.6, 3.4, size.z + 1.6)
			bt.add(pr, Transform3D(basis, pos + Vector3(0, wh + 1.7, 0)), "roof", roof_m)
			for c in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
				var bb := BoxMesh.new(); bb.size = Vector3(0.5, wh, 0.5)
				bt.add(bb, Transform3D(basis, pos + basis * (c * Vector3(size.x * 0.5, 0, size.z * 0.5)) + Vector3(0, wh * 0.5, 0)), "wood", Props.pbr(st["wood"], 0.85))
		"uldah":
			var dome := SphereMesh.new(); dome.radius = minf(size.x, size.z) * 0.42; dome.height = dome.radius; dome.is_hemisphere = true
			dome.radial_segments = 20; dome.rings = 8
			bt.add(dome, Transform3D(basis, pos + Vector3(0, wh, 0)), "roof", roof_m)
			var ban := BoxMesh.new(); ban.size = Vector3(1.4, 3.0, 0.06)
			bt.add(ban, Transform3D(basis, pos + front * 1.02 + right * (size.x * 0.32) + Vector3(0, wh * 0.62, 0)), "trim", trim_m, false)
			bt.add(ban, Transform3D(basis, pos + front * 1.02 - right * (size.x * 0.32) + Vector3(0, wh * 0.62, 0)), "trim", trim_m, false)
		"ishgard":
			var pr := PrismMesh.new(); pr.size = Vector3(size.x + 0.6, 6.0, size.z + 0.6)
			bt.add(pr, Transform3D(basis, pos + Vector3(0, wh + 3.0, 0)), "roof", roof_m)
			var sp := PrismMesh.new(); sp.size = Vector3(1.6, 5.0, 1.6)
			bt.add(sp, Transform3D(basis, pos + Vector3(size.x * 0.35, wh + 5.5, 0).rotated(Vector3.UP, face)), "roof", roof_m)
			var snow := BoxMesh.new(); snow.size = Vector3(size.x + 0.7, 0.15, size.z + 0.7)
			bt.add(snow, Transform3D(basis, pos + Vector3(0, wh + 0.05, 0)), "snow", Props.pbr("#f2f4f8", 0.6), false)
	if sign != "":
		ZoneBuilder._sign(root, pos + front * 1.05 + Vector3(0, wh + (4.0 if style in ["gridania", "ishgard"] else 1.6), 0), sign, 30)
