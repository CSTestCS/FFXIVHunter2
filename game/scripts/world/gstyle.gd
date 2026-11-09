class_name GStyle
## The Gridanian building style: dark plank-walled lodges on stone plinths with raised front decks,
## arched double doors, tall arched windows, bell-curved roofs in terracotta, red or moss green,
## gold leaf-shaped awnings and flower barrels at the door; round cottages with domed roofs; and
## open interiors (counters, tables, shelves, rugs, a gallery and warm lamps) for guilds, the inn
## and shops. Built on GKit's mesh helpers and materials.

static var _c := {}


static func M(n: String) -> Material:
	match n:
		"roof_o": return GKit.surf(3, "#b0643a", "#8c4a2a", 1.0, 0.35, 0.8)
		"roof_r": return GKit.surf(3, "#8e3a2e", "#6e2a22", 1.0, 0.3, 0.8)
		"wall_d": return GKit.surf(6, "#4a3424", "#3a281c", 1.4, 0.05, 0.8)
		"glass": return Props.glow("#ffd99a", 0.9)
		"glass_g": return Props.glow("#7ad870", 1.1)
		"glass_y": return Props.glow("#f2d060", 1.1)
		"rug": return Props.pbr("#6a2e26", 0.95)
		"rug_r": return Props.pbr("#5a2a3a", 0.95)
		"awning":
			if not _c.has("mat_awning"):
				var m := StandardMaterial3D.new()
				m.albedo_color = Color("#d8b04a"); m.roughness = 0.8; m.cull_mode = BaseMaterial3D.CULL_DISABLED
				_c["mat_awning"] = m
			return _c["mat_awning"]
		"goods_a": return Props.pbr("#c8a050", 0.8)
		"goods_b": return Props.pbr("#8a3a3a", 0.8)
		"goods_c": return Props.pbr("#4a7a8a", 0.8)
		"goods_d": return Props.pbr("#7a9a3a", 0.8)
	return GKit.M(n)


static func add(bt: Batcher, mesh: Mesh, xf: Transform3D, key: String, shadow := true) -> void:
	bt.add(mesh, xf, key, M(key), shadow)


static func box(bt: Batcher, xf: Transform3D, c: Vector3, s: Vector3, key: String, collide := false, rot := Basis()) -> void:
	bt.add(GKit.boxm(s), xf * Transform3D(rot, c), key, M(key))
	if collide:
		var sh := BoxShape3D.new(); sh.size = s
		bt.collider(sh, xf * Transform3D(rot, c))


# ----------------------------------------------------------------------------- shapes
## Flat panel: a rectangle w x h topped with a half-disc (an arched opening), facing +Z.
static func arch_panel(w: float, h: float) -> ArrayMesh:
	var key := "ap|%.2f|%.2f" % [w, h]
	if _c.has(key): return _c[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := w * 0.5
	var hs := h - r
	GKit._quad(st, Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(r, hs, 0), Vector3(-r, hs, 0), Vector3(0, 0, 1))
	for k in 10:
		var a0 := PI * k / 10.0; var a1 := PI * (k + 1) / 10.0
		GKit._tri(st, Vector3(0, hs, 0), Vector3(cos(a0) * r, hs + sin(a0) * r, 0), Vector3(cos(a1) * r, hs + sin(a1) * r, 0), Vector3(0, 0, 1))
	var m := st.commit()
	_c[key] = m
	return m


## Beams tracing an arch outline (frame) in a local frame facing +Z.
static func arch_frame(bt: Batcher, xf: Transform3D, w: float, h: float, t := 0.16, key := "timber") -> void:
	var r := w * 0.5
	var hs := h - r
	GKit.beam(bt, xf, Vector3(-r, 0, 0), Vector3(-r, hs, 0), t, key)
	GKit.beam(bt, xf, Vector3(r, 0, 0), Vector3(r, hs, 0), t, key)
	var prev := Vector3(r, hs, 0)
	for k in range(1, 9):
		var a := PI * k / 8.0
		var q := Vector3(cos(a) * r, hs + sin(a) * r, 0)
		GKit.beam(bt, xf, prev, q, t, key)
		prev = q


## Gable roof with a bell curve: the slope swells, then sweeps up at the eaves.
static func bell_roof(w: float, d: float, rise: float, over := 1.0, flare := 0.7, bulge := 0.5) -> ArrayMesh:
	var key := "br|%.2f|%.2f|%.2f|%.2f|%.2f" % [w, d, rise, over, bulge]
	if _c.has(key): return _c[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	var steps := 10
	var thick := 0.26
	var z0 := -d * 0.5 - over; var z1 := d * 0.5 + over
	for s in [-1.0, 1.0]:
		var prof := []
		for i in steps + 1:
			var t := float(i) / steps
			var x := t * (hw + over)
			var u := x / hw
			prof.append(Vector2(x * s, rise * (1.0 - u) + bulge * sin(clampf(u, 0.0, 1.0) * PI) + flare * pow(t, 3.0)))
		for i in steps:
			var a: Vector2 = prof[i]; var b: Vector2 = prof[i + 1]
			var tg := (b - a).normalized()
			var n2 := Vector2(-tg.y, tg.x) if s > 0 else Vector2(tg.y, -tg.x)
			var n := Vector3(n2.x, n2.y, 0)
			var ao := Vector3(a.x, a.y, 0); var bo := Vector3(b.x, b.y, 0)
			var dn := -n * thick
			GKit._quad(st, ao + Vector3(0, 0, z0), bo + Vector3(0, 0, z0), bo + Vector3(0, 0, z1), ao + Vector3(0, 0, z1), n)
			GKit._quad(st, ao + dn + Vector3(0, 0, z0), bo + dn + Vector3(0, 0, z0), bo + dn + Vector3(0, 0, z1), ao + dn + Vector3(0, 0, z1), -n)
			GKit._quad(st, ao + Vector3(0, 0, z0), bo + Vector3(0, 0, z0), bo + dn + Vector3(0, 0, z0), ao + dn + Vector3(0, 0, z0), Vector3(0, 0, -1))
			GKit._quad(st, ao + Vector3(0, 0, z1), bo + Vector3(0, 0, z1), bo + dn + Vector3(0, 0, z1), ao + dn + Vector3(0, 0, z1), Vector3(0, 0, 1))
	var m := st.commit()
	_c[key] = m
	return m


## Domed cone for round cottages and towers (swelling profile, flared eaves).
static func dome_roof(r: float, rise: float, over := 0.9, bulge := 0.8, segs := 20) -> ArrayMesh:
	var key := "dr|%.2f|%.2f|%.2f|%d" % [r, rise, bulge, segs]
	if _c.has(key): return _c[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 9
	var prof := []
	for i in steps + 1:
		var t := float(i) / steps
		var x := t * (r + over)
		var u := x / r
		prof.append(Vector2(x, rise * (1.0 - u) + bulge * sin(clampf(u, 0.0, 1.0) * PI) + 0.5 * pow(t, 3.0)))
	for k in segs:
		var a0 := TAU * k / segs; var a1 := TAU * (k + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0)); var d1 := Vector3(cos(a1), 0, sin(a1))
		for i in steps:
			var p: Vector2 = prof[i]; var q: Vector2 = prof[i + 1]
			var tg := (q - p).normalized()
			var nn := Vector2(-tg.y, tg.x)
			var n := ((d0 + d1).normalized() * nn.x + Vector3(0, nn.y, 0)).normalized()
			var v := [d0 * p.x + Vector3(0, p.y, 0), d1 * p.x + Vector3(0, p.y, 0), d1 * q.x + Vector3(0, q.y, 0), d0 * q.x + Vector3(0, q.y, 0)]
			GKit._quad(st, v[0], v[1], v[2], v[3], n)
			GKit._quad(st, v[0] - n * 0.25, v[1] - n * 0.25, v[2] - n * 0.25, v[3] - n * 0.25, -n)
	var m := st.commit()
	_c[key] = m
	return m


## Gold fabric awning shaped like a broad leaf, curving down at the tip.
static func leaf_awning() -> ArrayMesh:
	if _c.has("leafaw"): return _c["leafaw"]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 8
	var pts := []
	for i in rows + 1:
		var t := float(i) / rows
		var half_w := sin(t * PI) * 2.4 + 0.15
		var y := -t * t * 1.2
		pts.append([Vector3(-half_w, y + sin(t * PI) * 0.25, t * 3.2), Vector3(0, y + 0.18, t * 3.2), Vector3(half_w, y + sin(t * PI) * 0.25, t * 3.2)])
	for i in rows:
		for j in 2:
			var a: Vector3 = pts[i][j]; var b: Vector3 = pts[i][j + 1]; var c: Vector3 = pts[i + 1][j + 1]; var d: Vector3 = pts[i + 1][j]
			var n := (b - a).cross(d - a).normalized()
			if n.y < 0: n = -n
			GKit._quad(st, a, b, c, d, n)
			GKit._quad(st, a - n * 0.03, b - n * 0.03, c - n * 0.03, d - n * 0.03, -n)
	var m := st.commit()
	_c["leafaw"] = m
	return m


# ----------------------------------------------------------------------------- buildings
## A Gridanian lodge. Front (door) faces local +Z. Options:
##  roof: roof_o / roof_r / roof_g; floors (1-2); deck (raised front deck with stairs, default on);
##  interior (walk-in hall with furniture; default off); turret; awning (gold leaf over the door);
##  kind ("guild", "inn", "shop", "hall") steers interior furnishing.
## Returns {"door": doorstep, "inside": a point inside, "counter": where staff stand, "floor": floor y}.
static func lodge(bt: Batcher, root: Node3D, p: Vector3, yaw: float, w: float, d: float, o := {}) -> Dictionary:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var floors: int = o.get("floors", 1)
	var ph: float = o.get("plinth", 1.0)
	var fh := 3.6
	var H := floors * fh
	var interior: bool = o.get("interior", false)
	var roofk: String = o.get("roof", "roof_o")
	var t := 0.32
	# Plinth (stone, sunk into the slope) and the floor.
	box(bt, xf, Vector3(0, (ph - 3.0) * 0.5, 0), Vector3(w + 0.6, ph + 3.0, d + 0.6), "stone", true)
	box(bt, xf, Vector3(0, ph + 0.05, 0), Vector3(w - 0.2, 0.1, d - 0.2), "plank")
	var door_w := 2.4
	var door_h := 3.3
	if interior:
		# Walls as separate panels, with an opening in the front wall.
		box(bt, xf, Vector3(0, ph + H * 0.5, -d * 0.5 + t * 0.5), Vector3(w, H, t), "wall_d", true)
		box(bt, xf, Vector3(-w * 0.5 + t * 0.5, ph + H * 0.5, 0), Vector3(t, H, d), "wall_d", true)
		box(bt, xf, Vector3(w * 0.5 - t * 0.5, ph + H * 0.5, 0), Vector3(t, H, d), "wall_d", true)
		var side := (w - door_w) * 0.5
		box(bt, xf, Vector3(-(door_w + side) * 0.5, ph + H * 0.5, d * 0.5 - t * 0.5), Vector3(side, H, t), "wall_d", true)
		box(bt, xf, Vector3((door_w + side) * 0.5, ph + H * 0.5, d * 0.5 - t * 0.5), Vector3(side, H, t), "wall_d", true)
		box(bt, xf, Vector3(0, ph + door_h + (H - door_h) * 0.5, d * 0.5 - t * 0.5), Vector3(door_w, H - door_h, t), "wall_d", true)
	else:
		box(bt, xf, Vector3(0, ph + H * 0.5, 0), Vector3(w, H, d), "wall_d", true)
	# Frame: corner posts, sill and eaves beams, and floor bands.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(bt, xf, Vector3(sx * (w * 0.5 + 0.05), ph + H * 0.5, sz * (d * 0.5 + 0.05)), Vector3(0.5, H, 0.5), "timber")
	for yy in range(floors + 1):
		var y := ph + yy * fh
		box(bt, xf, Vector3(0, y, d * 0.5 + 0.08), Vector3(w + 0.4, 0.3, 0.3), "timber")
		box(bt, xf, Vector3(0, y, -d * 0.5 - 0.08), Vector3(w + 0.4, 0.3, 0.3), "timber")
		box(bt, xf, Vector3(w * 0.5 + 0.08, y, 0), Vector3(0.3, 0.3, d + 0.4), "timber")
		box(bt, xf, Vector3(-w * 0.5 - 0.08, y, 0), Vector3(0.3, 0.3, d + 0.4), "timber")
	# Tall arched windows on every face.
	var faces := [[Vector3(0, 0, d * 0.5 + 0.17), Basis(), w], [Vector3(0, 0, -d * 0.5 - 0.17), Basis(Vector3.UP, PI), w],
		[Vector3(w * 0.5 + 0.17, 0, 0), Basis(Vector3.UP, PI * 0.5), d], [Vector3(-w * 0.5 - 0.17, 0, 0), Basis(Vector3.UP, -PI * 0.5), d]]
	for fi in faces.size():
		var fc: Vector3 = faces[fi][0]; var fb: Basis = faces[fi][1]; var ln: float = faces[fi][2]
		var n := maxi(1, int(ln / 3.2))
		for f in floors:
			for k in n:
				var along := -ln * 0.5 + (k + 0.5) * ln / n
				if fi == 0 and f == 0 and absf(along) < door_w: continue
				var wx := xf * Transform3D(fb, fc + fb * Vector3(along, ph + f * fh + 0.9, 0))
				add(bt, arch_panel(1.1, 2.1), wx, "glass_g" if (fi == 1 and interior) else "glass", false)
				arch_frame(bt, wx * Transform3D(Basis(), Vector3(0, 0, 0.06)), 1.3, 2.25, 0.16)
				GKit.beam(bt, wx, Vector3(0, 0, 0.07), Vector3(0, 1.6, 0.07), 0.08)
				box(bt, wx, Vector3(0, -0.12, 0.15), Vector3(1.6, 0.14, 0.36), "timber")
	# Arched double door with iron straps, flanked by flower barrels; door leaves stand open on halls.
	var dx := xf * Transform3D(Basis(), Vector3(0, ph + 0.05, d * 0.5 + 0.18))
	arch_frame(bt, dx, door_w + 0.3, door_h + 0.2, 0.3)
	if interior:
		for s in [-1.0, 1.0]:
			var leaf := dx * Transform3D(Basis(Vector3.UP, s * 1.9), Vector3(s * door_w * 0.5, 0, 0))
			box(bt, leaf, Vector3(-s * door_w * 0.25, door_h * 0.42, 0), Vector3(door_w * 0.5, door_h * 0.84, 0.1), "plank_dark")
			for yy in [0.6, 1.8]:
				box(bt, leaf, Vector3(-s * door_w * 0.25, yy, 0.07), Vector3(door_w * 0.46, 0.1, 0.03), "iron")
	else:
		add(bt, arch_panel(door_w, door_h), dx * Transform3D(Basis(), Vector3(0, 0, -0.04)), "plank_dark")
		for yy in [0.7, 1.9]:
			box(bt, dx, Vector3(0, yy, 0.03), Vector3(door_w * 0.92, 0.1, 0.04), "iron")
		box(bt, dx, Vector3(0, 0, 0.02), Vector3(0.06, door_h * 1.6, 0.05), "timber")
	for s in [-1.0, 1.0]:
		flower_barrel(bt, xf * Vector3(s * (door_w * 0.5 + 0.9), ph, d * 0.5 + 0.9), s)
	# Raised deck and stairs before the door.
	var deck_d := 2.6
	if o.get("deck", true):
		box(bt, xf, Vector3(0, ph - 0.05, d * 0.5 + deck_d * 0.5), Vector3(door_w + 3.4, 0.22, deck_d), "plank", true)
		for s in [-1.0, 1.0]:
			box(bt, xf, Vector3(s * (door_w * 0.5 + 1.6), ph * 0.5 - 0.6, d * 0.5 + deck_d - 0.2), Vector3(0.3, ph + 1.2, 0.3), "timber")
		GKit.railing(bt, [xf * Vector3(-(door_w * 0.5 + 1.6), ph, d * 0.5 + 0.3), xf * Vector3(-(door_w * 0.5 + 1.6), ph, d * 0.5 + deck_d - 0.2)], 1.0)
		GKit.railing(bt, [xf * Vector3(door_w * 0.5 + 1.6, ph, d * 0.5 + 0.3), xf * Vector3(door_w * 0.5 + 1.6, ph, d * 0.5 + deck_d - 0.2)], 1.0)
		var top := xf * Vector3(0, ph, d * 0.5 + deck_d)
		var bottom := xf * Vector3(0, 0, d * 0.5 + deck_d + maxf(1.2, ph * 1.4))
		bottom.y = p.y - 0.05
		GKit.stairs(bt, bottom, top, door_w + 0.6, "plank")
	# Gold leaf awning over the door.
	if o.get("awning", true):
		add(bt, leaf_awning(), xf * Transform3D(Basis.from_scale(Vector3(0.75, 0.8, 0.75)), Vector3(0, ph + door_h + 0.9, d * 0.5 + 0.2)), "awning", false)
		for s in [-1.0, 1.0]:
			GKit.beam(bt, xf, Vector3(s * 1.5, ph + door_h + 0.2, d * 0.5 + 0.25), Vector3(s * 1.1, ph + door_h + 0.75, d * 0.5 + 1.6), 0.12)
	# Bell roof along the longer axis, gable infill, ridge beam and carved ridge ends.
	var along_z := d >= w
	var span := w if along_z else d
	var length := d if along_z else w
	var rise := span * float(o.get("pitch", 0.55))
	var rb := xf * Transform3D(Basis(Vector3.UP, 0.0 if along_z else PI * 0.5), Vector3(0, ph + H, 0))
	add(bt, bell_roof(span, length, rise, 1.1, 0.8, span * 0.06), rb, roofk)
	add(bt, GKit.gable_wall(span, rise + span * 0.05), rb * Transform3D(Basis(), Vector3(0, 0, length * 0.5 - 0.15)), "wall_d")
	add(bt, GKit.gable_wall(span, rise + span * 0.05), rb * Transform3D(Basis(), Vector3(0, 0, -length * 0.5 + 0.15)), "wall_d")
	box(bt, rb, Vector3(0, rise + span * 0.05 + 0.18, 0), Vector3(0.45, 0.3, length + 2.4), "timber")
	for s in [-1.0, 1.0]:
		var ez: float = s * (length * 0.5 + 1.15)
		GKit.beam(bt, rb, Vector3(0, rise + 0.2, ez), Vector3(0, rise + 1.3, ez + s * 0.5), 0.2)
		var gz: float = s * (length * 0.5 - 0.1)
		add(bt, arch_panel(1.0, 1.6), rb * Transform3D(Basis(Vector3.UP, 0.0 if s > 0 else PI), Vector3(0, rise * 0.25, gz + s * 0.06)), "glass", false)
	if o.get("turret", false):
		var tp := xf * Vector3(w * 0.5 - 0.4, 0, -d * 0.5 + 0.4)
		turret(bt, tp, 2.6, H + ph + 2.5, o.get("turret_roof", "roof_r"))
	var info := {"floor": p.y + ph + 0.1, "door": xf * Vector3(0, 0, d * 0.5 + deck_d + maxf(1.2, ph * 1.4) + 1.0)}
	info["inside"] = xf * Vector3(0, ph + 0.1, 0)
	info["counter"] = xf * Vector3(0, ph + 0.1, -d * 0.5 + 2.6)
	if interior:
		_furnish(bt, root, xf, w, d, ph, H, o.get("kind", "hall"))
	return info


## Round cottage with a domed terracotta roof and a little deck.
static func cottage(bt: Batcher, p: Vector3, yaw: float, r: float, o := {}) -> Vector3:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var ph := 0.8
	var h := 3.4
	bt.add(GKit._cyl(r + 0.4, 3.6, r + 0.6, 18), xf * Transform3D(Basis(), Vector3(0, ph - 1.8, 0)), "stone", M("stone"))
	bt.add(GKit._cyl(r, h, r, 18), xf * Transform3D(Basis(), Vector3(0, ph + h * 0.5, 0)), "wall_d", M("wall_d"))
	for k in 9:
		var a := TAU * k / 9.0
		var dd := Vector3(cos(a), 0, sin(a))
		box(bt, xf, dd * (r + 0.05) + Vector3(0, ph + h * 0.5, 0), Vector3(0.3, h, 0.3), "timber", false, Basis(Vector3.UP, -a))
		if k % 3 == 1:
			var wx := xf * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), dd * (r + 0.12) + Vector3(0, ph + 0.9, 0))
			add(bt, arch_panel(0.9, 1.7), wx, "glass", false)
			arch_frame(bt, wx * Transform3D(Basis(), Vector3(0, 0, 0.05)), 1.05, 1.85, 0.13)
	bt.add(GKit._cyl(r + 0.15, 0.3, r + 0.15, 18), xf * Transform3D(Basis(), Vector3(0, ph + h, 0)), "timber", M("timber"))
	add(bt, dome_roof(r, r * 1.1, 1.0, r * 0.25), xf * Transform3D(Basis(), Vector3(0, ph + h + 0.05, 0)), o.get("roof", "roof_o"))
	var dx := xf * Transform3D(Basis(), Vector3(0, ph, r + 0.1))
	add(bt, arch_panel(1.6, 2.6), dx, "plank_dark")
	arch_frame(bt, dx * Transform3D(Basis(), Vector3(0, 0, 0.06)), 1.8, 2.75, 0.2)
	box(bt, xf, Vector3(0, ph * 0.5, r + 0.9), Vector3(2.4, ph, 1.6), "stone")
	flower_barrel(bt, xf * Vector3(1.6, ph, r + 0.8), 1.0)
	var cs := CylinderShape3D.new(); cs.radius = r + 0.3; cs.height = h + ph
	bt.collider(cs, xf * Transform3D(Basis(), Vector3(0, (h + ph) * 0.5, 0)))
	return xf * Vector3(0, 0, r + 2.4)


static func turret(bt: Batcher, p: Vector3, r: float, h: float, roof := "roof_r") -> void:
	bt.add(GKit._cyl(r + 0.4, 3.0, r + 0.6, 16), Transform3D(Basis(), p + Vector3(0, -1.0, 0)), "stone", M("stone"))
	bt.add(GKit._cyl(r, h, r, 16), Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), "wall_d", M("wall_d"))
	for k in 8:
		var a := TAU * k / 8.0
		var dd := Vector3(cos(a), 0, sin(a))
		box(bt, Transform3D(), p + dd * (r + 0.04) + Vector3(0, h * 0.5, 0), Vector3(0.26, h, 0.26), "timber", false, Basis(Vector3.UP, -a))
		if k % 2 == 0:
			var wx := Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p + dd * (r + 0.1) + Vector3(0, h - 3.2, 0))
			add(bt, arch_panel(0.8, 1.5), wx, "glass", false)
	add(bt, dome_roof(r, r * 1.7, 0.9, r * 0.3, 16), Transform3D(Basis(), p + Vector3(0, h, 0)), roof)
	bt.add(GKit._cyl(0.1, 2.0, 0.02, 6), Transform3D(Basis(), p + Vector3(0, h + r * 1.7 + 1.2, 0)), "brass", M("brass"))
	var cs := CylinderShape3D.new(); cs.radius = r + 0.3; cs.height = h
	bt.collider(cs, Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)))


## Interior furnishing for walk-in halls.
static func _furnish(bt: Batcher, root: Node3D, xf: Transform3D, w: float, d: float, ph: float, H: float, kind: String) -> void:
	var fy := ph + 0.1
	box(bt, xf, Vector3(0, fy + 0.02, 0.5), Vector3(w * 0.45, 0.03, d * 0.4), "rug" if kind != "inn" else "rug_r")
	# Counter across the back with shelves of goods behind it.
	box(bt, xf, Vector3(0, fy + 0.55, -d * 0.5 + 2.0), Vector3(w * 0.55, 1.1, 0.8), "plank_dark", true)
	box(bt, xf, Vector3(0, fy + 1.13, -d * 0.5 + 2.0), Vector3(w * 0.58, 0.08, 1.0), "timber")
	for yy in [0.9, 1.7, 2.5]:
		box(bt, xf, Vector3(0, fy + yy, -d * 0.5 + 0.55), Vector3(w * 0.7, 0.08, 0.5), "timber")
		var gx := -w * 0.32
		var i := 0
		while gx < w * 0.32:
			box(bt, xf, Vector3(gx, fy + yy + 0.2, -d * 0.5 + 0.55), Vector3(0.36, 0.32, 0.3), ["goods_a", "goods_b", "goods_c", "goods_d"][i % 4])
			gx += 0.6; i += 1
	# Tables and stools.
	var tables: Array = [Vector3(-w * 0.28, 0, 1.0), Vector3(w * 0.28, 0, 1.0), Vector3(-w * 0.28, 0, d * 0.5 - 2.6), Vector3(w * 0.28, 0, d * 0.5 - 2.6)]
	for tp in tables:
		bt.add(GKit._cyl(0.85, 0.08, 0.85, 14), xf * Transform3D(Basis(), tp + Vector3(0, fy + 0.85, 0)), "timber_l", M("timber_l"))
		bt.add(GKit._cyl(0.14, 0.8, 0.2, 8), xf * Transform3D(Basis(), tp + Vector3(0, fy + 0.42, 0)), "timber", M("timber"))
		var cs := CylinderShape3D.new(); cs.radius = 0.85; cs.height = 0.9
		bt.collider(cs, xf * Transform3D(Basis(), tp + Vector3(0, fy + 0.45, 0)))
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			bt.add(GKit._cyl(0.25, 0.5, 0.25, 8), xf * Transform3D(Basis(), tp + Vector3(cos(a) * 1.2, fy + 0.25, sin(a) * 1.2)), "timber_l", M("timber_l"))
		bt.add(GKit._cyl(0.1, 0.2, 0.08, 8), xf * Transform3D(Basis(), tp + Vector3(0.2, fy + 1.0, 0)), "lamp", M("lamp"), false)
	# A gallery along the back wall, reached by stairs, with a railing.
	if H > 5.0:
		var gy := fy + 3.5
		box(bt, xf, Vector3(0, gy, -d * 0.5 + 1.6), Vector3(w - 0.8, 0.25, 2.8), "plank", true)
		GKit.railing(bt, [xf * Vector3(-w * 0.5 + 0.5, gy, -d * 0.5 + 3.0), xf * Vector3(w * 0.5 - 3.4, gy, -d * 0.5 + 3.0)], 1.0)
		for s in [-1.0, 1.0]:
			box(bt, xf, Vector3(s * (w * 0.5 - 1.6), gy * 0.5 + fy * 0.5 - 0.1, -d * 0.5 + 2.9), Vector3(0.3, gy - fy, 0.3), "timber")
		GKit.stairs(bt, xf * Vector3(w * 0.5 - 1.6, fy - 0.02, -d * 0.5 + 8.2), xf * Vector3(w * 0.5 - 1.6, gy + 0.1, -d * 0.5 + 3.0), 1.8, "plank")
	# Stained glass on the back wall, banners and hanging lamps.
	for s in [-1.0, 1.0]:
		var gx2 := xf * Transform3D(Basis(Vector3.UP, 0.0), Vector3(s * w * 0.22, fy + H - 3.3, -d * 0.5 + 0.34))
		add(bt, arch_panel(1.4, 2.6), gx2, "glass_g" if s < 0 else "glass_y", false)
		GKit.banner(bt, xf * Vector3(s * (w * 0.5 - 0.4), fy + H - 0.8, 0), atan2(xf.basis.x.x, xf.basis.x.z) + s * PI * 0.5 - PI * 0.5, 2.6, "cloth_g")
	for k in 3:
		var lp := Vector3(-w * 0.3 + k * w * 0.3, fy + H - 0.9, 0.2)
		GKit.hang_lamp(bt, xf * Transform3D(Basis(), lp))
	if kind == "inn":
		for k in 2:
			box(bt, xf, Vector3(-w * 0.5 + 1.4, fy + 0.35, -1.0 + k * 3.0), Vector3(1.9, 0.5, 2.5), "rug_r", true)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffc888"); l.light_energy = 2.6; l.omni_range = maxf(w, d) * 1.1; l.shadow_enabled = false
	l.distance_fade_enabled = true; l.distance_fade_begin = 40.0; l.distance_fade_length = 12.0
	l.position = xf * Vector3(0, fy + H * 0.6, 0)
	root.add_child(l)
	var l2 := OmniLight3D.new()
	l2.light_color = Color("#ffd8a0"); l2.light_energy = 1.6; l2.omni_range = maxf(w, d) * 0.7; l2.shadow_enabled = false
	l2.distance_fade_enabled = true; l2.distance_fade_begin = 40.0; l2.distance_fade_length = 12.0
	l2.position = xf * Vector3(0, fy + 2.4, -d * 0.5 + 3.5)
	root.add_child(l2)


# ----------------------------------------------------------------------------- city furniture
static func flower_barrel(bt: Batcher, p: Vector3, seed_s: float) -> void:
	bt.add(GKit._cyl(0.42, 0.75, 0.38, 12), Transform3D(Basis(), p + Vector3(0, 0.38, 0)), "plank_dark", M("plank_dark"))
	bt.add(GKit._cyl(0.44, 0.06, 0.44, 12), Transform3D(Basis(), p + Vector3(0, 0.6, 0)), "iron", M("iron"))
	bt.add(GKit._cyl(0.44, 0.06, 0.44, 12), Transform3D(Basis(), p + Vector3(0, 0.15, 0)), "iron", M("iron"))
	bt.add(flowers_mesh(1 if seed_s > 0 else 0), Transform3D(Basis().scaled(Vector3.ONE * 0.45), p + Vector3(0, 0.72, 0)), "flowers%d" % (1 if seed_s > 0 else 0), flower_mat(1 if seed_s > 0 else 0), false)


## Post-and-rail fence of dark timber.
static func fence(bt: Batcher, pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 2.2))
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			GKit.beam(bt, Transform3D(), q - Vector3(0, 0.3, 0), q + Vector3(0, 1.15, 0), 0.16, "timber")
		GKit.beam(bt, Transform3D(), a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0), 0.1, "timber")
		GKit.beam(bt, Transform3D(), a + Vector3(0, 0.55, 0), b + Vector3(0, 0.55, 0), 0.08, "timber")


static func flower_mat(v: int) -> ShaderMaterial:
	var cols: Array = [["#e87a2a", "#f2b23a", "#ffd860"], ["#e85a8a", "#f4a0c0", "#ffffff"], ["#f2d24a", "#fff0a0", "#ffffff"], ["#9a6ae0", "#c8a0f0", "#ffffff"]][v % 4]
	return GKit.leaf_mat(2, cols[0], cols[1], cols[2], 0.08)


## A clump of blossoms (flower cards) on a few leaf cards.
static func flowers_mesh(v: int) -> ArrayMesh:
	var key := "fl|%d" % v
	if _c.has(key): return _c[key]
	var rng := RandomNumberGenerator.new(); rng.seed = 91 + v
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	GKit._cluster(st, Vector3(0, 0.45, 0), 0.65, 22, 0.55, rng, 0.6)
	st.set_material(flower_mat(v))
	var m := st.commit()
	_c[key] = m
	return m


## Flowering shrub: leafy mass dotted with blossoms (orange by default).
static func flowering_shrub(v: int) -> ArrayMesh:
	var key := "fs|%d" % v
	if _c.has(key): return _c[key]
	var rng := RandomNumberGenerator.new(); rng.seed = 51 + v
	var leaf := SurfaceTool.new(); leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	GKit._cluster(leaf, Vector3(0, 0.6, 0), 1.0, 30, 0.9, rng, 0.7)
	var fl := SurfaceTool.new(); fl.begin(Mesh.PRIMITIVE_TRIANGLES)
	GKit._cluster(fl, Vector3(0, 0.75, 0), 1.05, 26, 0.45, rng, 0.65)
	leaf.set_material(GKit.leaf_mat(0, "#2e4a1c", "#4a6a24", "#6a7a2a", 0.05))
	var am := leaf.commit()
	fl.set_material(flower_mat(v))
	am = fl.commit(am)
	_c[key] = am
	return am


## A planter box of flowers.
static func planter(bt: Batcher, p: Vector3, yaw: float, v: int) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	box(bt, xf, Vector3(0, 0.3, 0), Vector3(2.4, 0.6, 0.9), "plank_dark", true)
	box(bt, xf, Vector3(0, 0.58, 0), Vector3(2.2, 0.06, 0.7), "dark")
	for k in 3:
		bt.add(flowers_mesh(v), xf * Transform3D(Basis().scaled(Vector3.ONE * 0.5), Vector3(-0.7 + k * 0.7, 0.55, 0)), "flowers%d" % v, flower_mat(v), false)


# ----------------------------------------------------------------------------- aether
## The city's Aetheryte: a great blue crystal turning slowly within a ring of brass arms on a
## stepped stone dais.
static func aetheryte(root: Node3D, bt: Batcher, p: Vector3) -> void:
	for k in 3:
		bt.add(GKit._cyl(4.2 - k * 1.0, 0.45, 4.3 - k * 1.0, 24), Transform3D(Basis(), p + Vector3(0, 0.22 + k * 0.45, 0)), "stone", M("stone"))
	var top := p + Vector3(0, 1.35, 0)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var d := Vector3(cos(a), 0, sin(a))
		var prev := top + d * 1.9
		for i in range(1, 7):
			var t := float(i) / 6.0
			var q := top + d * (1.9 + sin(t * PI) * 0.9) + Vector3(0, t * 6.2, 0)
			GKit.beam(bt, Transform3D(), prev, q, 0.22, "brass")
			prev = q
		bt.add(GKit._cyl(0.25, 0.4, 0.05, 8), Transform3D(Basis(), prev + Vector3(0, 0.3, 0)), "brass", M("brass"))
	bt.add(GKit._cyl(2.3, 0.18, 2.3, 24), Transform3D(Basis(), top + Vector3(0, 0.1, 0)), "brass", M("brass"))
	bt.add(GKit._cyl(2.6, 0.12, 2.6, 24), Transform3D(Basis(), top + Vector3(0, 6.3, 0)), "brass", M("brass"))
	var cr := PrismMesh.new(); cr.size = Vector3(1.5, 4.0, 1.5)
	var m := Props.glow("#6fd8ff", 2.8)
	for spec in [[Vector3(0, 4.2, 0), 1.0, 0.0], [Vector3(0, 1.6, 0), 0.45, 180.0]]:
		var mi := MeshInstance3D.new(); mi.mesh = cr; mi.material_override = m
		mi.position = top + spec[0]; mi.scale = Vector3(1, spec[1], 1); mi.rotation_degrees.x = spec[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var spin := mi.create_tween().set_loops()
		spin.tween_property(mi, "rotation:y", TAU, 8.0).from(0.0)
	var light := OmniLight3D.new(); light.light_color = Color("#8fe0ff"); light.omni_range = 12.0; light.light_energy = 1.8
	light.position = top + Vector3(0, 3.5, 0); light.shadow_enabled = false
	root.add_child(light)
	ZoneBuilder._sign(root, top + Vector3(0, 8.4, 0), "Aetheryte", 24)


## An aethernet shard: a small crystal floating over a carved stone post.
static func shard(root: Node3D, bt: Batcher, p: Vector3, label: String) -> void:
	bt.add(GKit._cyl(0.8, 0.4, 1.0, 12), Transform3D(Basis(), p + Vector3(0, 0.2, 0)), "stone", M("stone"))
	bt.add(GKit._cyl(0.35, 1.3, 0.5, 10), Transform3D(Basis(), p + Vector3(0, 1.05, 0)), "stone", M("stone"))
	bt.add(GKit._cyl(0.6, 0.12, 0.6, 12), Transform3D(Basis(), p + Vector3(0, 1.72, 0)), "brass", M("brass"))
	for k in 3:
		var a := TAU * k / 3.0
		GKit.beam(bt, Transform3D(), p + Vector3(cos(a) * 0.55, 1.75, sin(a) * 0.55), p + Vector3(cos(a) * 0.3, 2.6, sin(a) * 0.3), 0.08, "brass")
	var cr := PrismMesh.new(); cr.size = Vector3(0.45, 0.9, 0.45)
	var mi := MeshInstance3D.new(); mi.mesh = cr; mi.material_override = Props.glow("#7fdcff", 2.6)
	mi.position = p + Vector3(0, 2.45, 0); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var mi2 := MeshInstance3D.new(); mi2.mesh = cr; mi2.material_override = mi.material_override
	mi2.position = p + Vector3(0, 1.95, 0); mi2.scale = Vector3(1, 0.4, 1); mi2.rotation_degrees.x = 180
	root.add_child(mi2)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "rotation:y", TAU, 5.0).from(0.0)
	var l := OmniLight3D.new(); l.light_color = Color("#8fe0ff"); l.light_energy = 0.8; l.omni_range = 5.0; l.shadow_enabled = false
	l.position = p + Vector3(0, 2.4, 0); l.distance_fade_enabled = true; l.distance_fade_begin = 40.0; l.distance_fade_length = 10.0
	root.add_child(l)
	ZoneBuilder._sign(root, p + Vector3(0, 3.6, 0), label, 18)


# ----------------------------------------------------------------------------- airship
## A docked airship: a timber hull with a gilded rail, a gas envelope above, and side fins.
static func airship(bt: Batcher, p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var hull := SphereMesh.new(); hull.radius = 1.0; hull.height = 2.0; hull.radial_segments = 16; hull.rings = 8; hull.is_hemisphere = true
	add(bt, hull, xf * Transform3D(Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(2.6, 2.0, 9.0)), Vector3(0, 0, 0)), "plank_dark")
	box(bt, xf, Vector3(0, 0.05, 0), Vector3(5.0, 0.2, 16.0), "plank")
	GKit.railing(bt, [xf * Vector3(-2.4, 0.1, -7.5), xf * Vector3(-2.4, 0.1, 7.5)], 1.0, "brass")
	GKit.railing(bt, [xf * Vector3(2.4, 0.1, -7.5), xf * Vector3(2.4, 0.1, 7.5)], 1.0, "brass")
	var env := SphereMesh.new(); env.radius = 1.0; env.height = 2.0; env.radial_segments = 18; env.rings = 10
	add(bt, env, xf * Transform3D(Basis.from_scale(Vector3(3.6, 3.2, 11.0)), Vector3(0, 7.5, 0)), "cloth_w")
	for z in [-5.0, 0.0, 5.0]:
		for s in [-1.0, 1.0]:
			GKit.beam(bt, xf, Vector3(s * 2.2, 0.2, z), Vector3(s * 2.0, 4.8, z), 0.12, "iron")
	for s in [-1.0, 1.0]:
		box(bt, xf, Vector3(s * 3.3, 1.5, -6.0), Vector3(2.4, 0.12, 3.2), "cloth_y", false, Basis(Vector3.BACK, s * 0.3))
	box(bt, xf, Vector3(0, 8.5, -11.5), Vector3(0.15, 4.0, 3.0), "cloth_y")
	bt.add(GKit._cyl(0.5, 1.2, 0.3, 10), xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.6, -9.2)), "brass", M("brass"))
