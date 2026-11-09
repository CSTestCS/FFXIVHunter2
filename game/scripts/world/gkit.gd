class_name GKit
## Architecture and forest kit for the Black Shroud: Gridanian timber-framed houses on stone
## footings with steep flared shingle roofs, round towers, arched bridges, stairs, lanterns and
## railings, plus generated trees (buttress-rooted giants, oaks, saplings), bushes and ferns.
## Everything is built from generated meshes and procedural materials (shaders/surface.gdshader),
## merged per material by Batcher, so a whole district renders in a few draw calls.

static var _c := {}


# ----------------------------------------------------------------------------- materials
static func surf(kind: int, a: String, b: String, scale := 1.0, moss := 0.0, rough := 0.85) -> ShaderMaterial:
	var key := "s|%d|%s|%s|%s|%s|%s" % [kind, a, b, scale, moss, rough]
	if _c.has(key): return _c[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/surface.gdshader")
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("base", Color(a)); m.set_shader_parameter("base2", Color(b))
	m.set_shader_parameter("scale", scale); m.set_shader_parameter("moss", moss); m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("noise_tex", Props.noise())
	_c[key] = m
	return m


## Named palette shared by the whole city.
static func M(name: String) -> Material:
	match name:
		"stone": return surf(0, "#8e8a7c", "#6c695f", 1.0, 0.55, 0.9)
		"stone_dark": return surf(0, "#6e675a", "#57524a", 0.8, 0.75, 0.92)
		"timber": return surf(1, "#4e3322", "#3a2618", 1.0, 0.0, 0.8)
		"timber_l": return surf(1, "#80603e", "#66482c", 1.0, 0.05, 0.8)
		"plaster": return surf(2, "#e2d6b8", "#cbbb98", 1.0, 0.12, 0.9)
		"plaster_g": return surf(2, "#d2d4b4", "#b8bc98", 1.0, 0.15, 0.9)
		"roof_g": return surf(3, "#50693c", "#36502a", 1.0, 0.45, 0.82)
		"roof_b": return surf(3, "#74503a", "#5a3a28", 1.0, 0.35, 0.82)
		"roof_t": return surf(3, "#4a5a40", "#3a4632", 0.8, 0.6, 0.85)
		"bark": return surf(4, "#5e4a38", "#3a2c22", 1.0, 0.55, 0.95)
		"bark_pale": return surf(4, "#7a6c5a", "#54483c", 1.0, 0.45, 0.95)
		"rock": return surf(5, "#5e5a4c", "#44423a", 1.0, 0.8, 0.95)
		"plank": return surf(6, "#8a6840", "#6a4c30", 1.0, 0.1, 0.8)
		"plank_dark": return surf(6, "#5e4630", "#4a3624", 1.0, 0.25, 0.85)
		"cloth_g": return Props.pbr("#4f7a3a", 0.9)
		"cloth_y": return Props.pbr("#d6b048", 0.85)
		"cloth_w": return Props.pbr("#e8e0c8", 0.9)
		"iron": return Props.pbr("#2c2a28", 0.5, 0.6)
		"brass": return Props.pbr("#b08a40", 0.4, 0.8)
		"lamp": return Props.glow("#ffcf80", 3.2)
		"pane": return Props.glow("#ffd59a", 0.55)
		"dark": return Props.pbr("#1a1410", 0.9)
	return Props.pbr("#ff00ff")


static func leaf_mat(mode := 0, a := "#2c4a1c", b := "#4a6a24", c := "#7a8a2c", sway := 0.12) -> ShaderMaterial:
	var key := "leaf|%d|%s|%s|%s|%s" % [mode, a, b, c, sway]
	if _c.has(key): return _c[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/leafcard.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("tint", Color(a)); m.set_shader_parameter("tint2", Color(b)); m.set_shader_parameter("tint3", Color(c))
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("noise_tex", Props.noise())
	_c[key] = m
	return m


# ----------------------------------------------------------------------------- mesh helpers
static func boxm(s: Vector3) -> BoxMesh:
	var key := "b|%.2f|%.2f|%.2f" % [s.x, s.y, s.z]
	if _c.has(key): return _c[key]
	var b := BoxMesh.new(); b.size = s
	_c[key] = b
	return b


## A box placed in a local frame `xf`, centred at local `c`, optionally rotated.
static func bx(bt: Batcher, xf: Transform3D, c: Vector3, s: Vector3, key: String, rot := Basis(), shadow := true) -> void:
	bt.add(boxm(s), xf * Transform3D(rot, c), key, M(key), shadow)


## A beam between two local points (square section).
static func beam(bt: Batcher, xf: Transform3D, a: Vector3, b: Vector3, t: float, key := "timber") -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01: return
	var y := d / l
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	bt.add(boxm(Vector3(t, l, t)), xf * Transform3D(Basis(x, y, z), (a + b) * 0.5), key, M(key))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot treats clockwise triangles as front faces.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b; b = c; c = t
	for v in [a, b, c]:
		st.set_normal(n); st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n); _tri(st, a, c, d, n)


## Smooth-shaded triangle with per-vertex normals, colours and UVs.
static func _tri_s(st: SurfaceTool, v: Array, n: Array, col: Array, uv: Array) -> void:
	var avg: Vector3 = (n[0] + n[1] + n[2]) as Vector3
	var order := [0, 1, 2]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(avg) > 0.0: order = [0, 2, 1]
	for i in order:
		st.set_normal(n[i]); st.set_color(col[i]); st.set_uv(uv[i]); st.add_vertex(v[i])


# ----------------------------------------------------------------------------- roofs
## Gable roof: ridge along local Z over a wall span `w`, roof length `d`. The slope curves upward
## at the eaves (`flare`), the slabs have real thickness and overhang the walls by `over`.
static func gable_roof(w: float, d: float, rise: float, over := 0.9, thick := 0.24, flare := 0.45) -> ArrayMesh:
	var key := "gr|%.2f|%.2f|%.2f|%.2f|%.2f" % [w, d, rise, over, flare]
	if _c.has(key): return _c[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	var steps := 9
	var z0 := -d * 0.5 - over
	var z1 := d * 0.5 + over
	for s in [-1.0, 1.0]:
		var prof := []
		for i in steps + 1:
			var t := float(i) / steps
			var x := t * (hw + over)
			prof.append(Vector2(x * s, rise * (1.0 - x / hw) + flare * pow(t, 3.0)))
		for i in steps:
			var a: Vector2 = prof[i]; var b: Vector2 = prof[i + 1]
			var tg := (b - a).normalized()
			var n2 := Vector2(-tg.y, tg.x) if s > 0 else Vector2(tg.y, -tg.x)
			var n := Vector3(n2.x, n2.y, 0)
			var ao := Vector3(a.x, a.y, 0); var bo := Vector3(b.x, b.y, 0)
			var dn := -n * thick
			_quad(st, ao + Vector3(0, 0, z0), bo + Vector3(0, 0, z0), bo + Vector3(0, 0, z1), ao + Vector3(0, 0, z1), n)
			_quad(st, ao + dn + Vector3(0, 0, z0), bo + dn + Vector3(0, 0, z0), bo + dn + Vector3(0, 0, z1), ao + dn + Vector3(0, 0, z1), -n)
			for zz in [[z0, -1.0], [z1, 1.0]]:
				_quad(st, ao + Vector3(0, 0, zz[0]), bo + Vector3(0, 0, zz[0]), bo + dn + Vector3(0, 0, zz[0]), ao + dn + Vector3(0, 0, zz[0]), Vector3(0, 0, zz[1]))
		var e: Vector2 = prof[steps]; var e2: Vector2 = prof[steps - 1]
		var eo := Vector3(e.x, e.y, 0)
		var tg2 := (e - e2).normalized()
		var en := Vector3(tg2.x, tg2.y, 0)
		var edn := -Vector3(-tg2.y, tg2.x, 0) * thick if s > 0 else -Vector3(tg2.y, -tg2.x, 0) * thick
		_quad(st, eo + Vector3(0, 0, z0), eo + Vector3(0, 0, z1), eo + edn + Vector3(0, 0, z1), eo + edn + Vector3(0, 0, z0), en)
	var m := st.commit()
	_c[key] = m
	return m


## Conical roof with flared eaves, for towers and pavilions.
static func cone_roof(r: float, rise: float, over := 0.8, thick := 0.24, flare := 0.6, segs := 20) -> ArrayMesh:
	var key := "cr|%.2f|%.2f|%.2f|%.2f|%d" % [r, rise, over, flare, segs]
	if _c.has(key): return _c[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 8
	var prof := []
	for i in steps + 1:
		var t := float(i) / steps
		var x := t * (r + over)
		prof.append(Vector2(x, rise * (1.0 - x / r) + flare * pow(t, 3.0)))
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0)); var d1 := Vector3(cos(a1), 0, sin(a1))
		for i in steps:
			var p: Vector2 = prof[i]; var q: Vector2 = prof[i + 1]
			var tg := (q - p).normalized()
			var nn := Vector2(-tg.y, tg.x)
			var mid := (d0 + d1).normalized()
			var n := (mid * nn.x + Vector3(0, nn.y, 0)).normalized()
			var v := [d0 * p.x + Vector3(0, p.y, 0), d1 * p.x + Vector3(0, p.y, 0), d1 * q.x + Vector3(0, q.y, 0), d0 * q.x + Vector3(0, q.y, 0)]
			_quad(st, v[0], v[1], v[2], v[3], n)
			var off := -n * thick
			_quad(st, v[0] + off, v[1] + off, v[2] + off, v[3] + off, -n)
		var e: Vector2 = prof[steps]
		_quad(st, d0 * e.x + Vector3(0, e.y, 0), d1 * e.x + Vector3(0, e.y, 0), d1 * e.x + Vector3(0, e.y - thick, 0), d0 * e.x + Vector3(0, e.y - thick, 0), (d0 + d1).normalized())
	var m := st.commit()
	_c[key] = m
	return m


## Triangular gable wall (front and back faces), base `w` wide, `rise` high, `t` thick.
static func gable_wall(w: float, rise: float, t := 0.2) -> ArrayMesh:
	var key := "gw|%.2f|%.2f" % [w, rise]
	if _c.has(key): return _c[key]
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		var z: float = s * t * 0.5
		_tri(st, Vector3(-w * 0.5, 0, z), Vector3(w * 0.5, 0, z), Vector3(0, rise, z), Vector3(0, 0, s))
	var m := st.commit()
	_c[key] = m
	return m


# ----------------------------------------------------------------------------- buildings
## A Gridanian house. `p` is the ground point at the front-centre footprint middle, `yaw` turns
## the front (door side, local +Z) toward where it should face. Returns the doorstep position.
## Options: roof ("roof_g"/"roof_b"), plaster, plinth, chimney, door (false for none), tree (a
## living trunk rising through the roof), lantern (light at the door).
static func house(bt: Batcher, root: Node3D, p: Vector3, yaw: float, w: float, d: float, floors := 1, o := {}) -> Vector3:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var ph: float = o.get("plinth", 0.7)
	var fh := 3.1
	var plaster: String = o.get("plaster", "plaster")
	var roofk: String = o.get("roof", "roof_g")
	bx(bt, xf, Vector3(0, (ph - 3.0) * 0.5, 0), Vector3(w + 0.5, ph + 3.0, d + 0.5), "stone")
	bx(bt, xf, Vector3(0, ph - 0.04, 0), Vector3(w + 0.62, 0.1, d + 0.62), "stone_dark")
	for f in floors:
		var y0 := ph + f * fh
		var jet := f * 0.35
		var fw := w + jet * 2.0
		var fd := d + jet * 2.0
		bx(bt, xf, Vector3(0, y0 + fh * 0.5, 0), Vector3(fw - 0.16, fh, fd - 0.16), plaster)
		_frame(bt, xf, y0, fw, fd, fh, f == 0 and o.get("door", true))
		if f > 0:
			# Brackets carrying the jettied upper floor.
			for s in [-1.0, 1.0]:
				var k := -fw * 0.5 + 0.6
				while k < fw * 0.5 - 0.4:
					beam(bt, xf, Vector3(k, y0 - 0.9, s * (fd * 0.5 - jet - 0.1)), Vector3(k, y0 - 0.05, s * (fd * 0.5 - 0.1)), 0.16)
					k += 1.7
	var top := ph + floors * fh
	var jt := (floors - 1) * 0.35
	var rw := w + jt * 2.0
	var rd := d + jt * 2.0
	var along_z := rd >= rw
	var span := rw if along_z else rd
	var length := rd if along_z else rw
	var rise := span * float(o.get("pitch", 0.62))
	var rb := xf * Transform3D(Basis(Vector3.UP, 0.0 if along_z else PI * 0.5), Vector3(0, top, 0))
	bt.add(gable_roof(span, length, rise, 0.9, 0.24, 0.45), rb, roofk, M(roofk))
	bt.add(gable_wall(span, rise), rb * Transform3D(Basis(), Vector3(0, 0, length * 0.5 - 0.12)), plaster, M(plaster))
	bt.add(gable_wall(span, rise), rb * Transform3D(Basis(), Vector3(0, 0, -length * 0.5 + 0.12)), plaster, M(plaster))
	for s in [-1.0, 1.0]:
		var gz: float = s * (length * 0.5 - 0.02)
		# Gable framing: king post, collar and struts.
		beam(bt, rb, Vector3(0, 0, gz), Vector3(0, rise - 0.1, gz), 0.22)
		beam(bt, rb, Vector3(-span * 0.3, rise * 0.4, gz), Vector3(span * 0.3, rise * 0.4, gz), 0.2)
		beam(bt, rb, Vector3(-span * 0.45, 0.05, gz), Vector3(0, rise * 0.4, gz), 0.16)
		beam(bt, rb, Vector3(span * 0.45, 0.05, gz), Vector3(0, rise * 0.4, gz), 0.16)
		# Bargeboards and a crossed finial at the ridge end.
		var ez: float = s * (length * 0.5 + 0.92)
		beam(bt, rb, Vector3(0, rise + 0.15, ez), Vector3(-(span * 0.5 + 0.9), -0.12 + 0.45, ez), 0.18, "timber")
		beam(bt, rb, Vector3(0, rise + 0.15, ez), Vector3(span * 0.5 + 0.9, -0.12 + 0.45, ez), 0.18, "timber")
		beam(bt, rb, Vector3(0, rise + 0.1, ez), Vector3(-0.5, rise + 0.95, ez + s * 0.2), 0.14)
		beam(bt, rb, Vector3(0, rise + 0.1, ez), Vector3(0.5, rise + 0.95, ez + s * 0.2), 0.14)
	bx(bt, rb, Vector3(0, rise + 0.12, 0), Vector3(0.38, 0.24, length + 1.9), "timber")
	if o.get("chimney", false):
		bx(bt, xf, Vector3(w * 0.25, top + rise * 0.8, -d * 0.2), Vector3(0.8, rise * 1.2 + 1.0, 0.8), "stone_dark")
	if o.get("tree", false):
		trees_extra(root, xf * Vector3(w * 0.2, 0, -d * 0.15))
	var col := BoxShape3D.new(); col.size = Vector3(w + 0.4, top + 0.5, d + 0.4)
	bt.collider(col, xf * Transform3D(Basis(), Vector3(0, (top + 0.5) * 0.5, 0)))
	var door := xf * Vector3(0, 0, d * 0.5 + 1.3)
	if o.get("door", true):
		bx(bt, xf, Vector3(0, ph * 0.5, d * 0.5 + 0.55), Vector3(2.2, ph, 1.1), "stone")
		if o.get("lantern", true):
			hang_lamp(bt, xf * Transform3D(Basis(), Vector3(1.25, ph + 2.55, d * 0.5 + 0.1)))
	return door


## Timber frame for one storey: corner posts, sills and plates, studs, braces, windows and a door.
static func _frame(bt: Batcher, xf: Transform3D, y0: float, fw: float, fd: float, fh: float, door: bool) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bx(bt, xf, Vector3(sx * (fw * 0.5 - 0.1), y0 + fh * 0.5, sz * (fd * 0.5 - 0.1)), Vector3(0.36, fh, 0.36), "timber")
	for yy in [y0 + 0.13, y0 + fh - 0.13]:
		bx(bt, xf, Vector3(0, yy, fd * 0.5 - 0.06), Vector3(fw + 0.08, 0.26, 0.3), "timber")
		bx(bt, xf, Vector3(0, yy, -fd * 0.5 + 0.06), Vector3(fw + 0.08, 0.26, 0.3), "timber")
		bx(bt, xf, Vector3(fw * 0.5 - 0.06, yy, 0), Vector3(0.3, 0.26, fd + 0.08), "timber")
		bx(bt, xf, Vector3(-fw * 0.5 + 0.06, yy, 0), Vector3(0.3, 0.26, fd + 0.08), "timber")
	# Four faces: (centre offset, along axis, length, outward normal).
	var faces := [[Vector3(0, 0, fd * 0.5), Vector3.RIGHT, fw, Vector3(0, 0, 1)], [Vector3(0, 0, -fd * 0.5), Vector3.RIGHT, fw, Vector3(0, 0, -1)],
		[Vector3(fw * 0.5, 0, 0), Vector3.BACK, fd, Vector3(1, 0, 0)], [Vector3(-fw * 0.5, 0, 0), Vector3.BACK, fd, Vector3(-1, 0, 0)]]
	for fi in faces.size():
		var fc: Vector3 = faces[fi][0]; var ax: Vector3 = faces[fi][1]; var ln: float = faces[fi][2]; var nrm: Vector3 = faces[fi][3]
		var nb := maxi(2, int(round(ln / 1.75)))
		var bay := ln / nb
		var door_bay := nb / 2 if (door and fi == 0) else -1
		var surf_c := fc + nrm * 0.02
		for k in range(1, nb):
			var along := -ln * 0.5 + k * bay
			if door_bay >= 0 and (k == door_bay or k == door_bay + 1) and nb % 2 == 1: pass
			bx(bt, xf, surf_c + ax * along + Vector3(0, y0 + fh * 0.5, 0), Vector3(0.22, fh - 0.4, 0.22) if ax == Vector3.RIGHT else Vector3(0.22, fh - 0.4, 0.22), "timber")
		for k in nb:
			var c0 := -ln * 0.5 + k * bay
			var mid := c0 + bay * 0.5
			if k == door_bay:
				_door(bt, xf, surf_c + ax * mid + Vector3(0, y0, 0), ax, nrm, minf(bay - 0.3, 1.5))
				continue
			if k == 0 or k == nb - 1:
				# Braces in the end bays.
				var lo := surf_c + ax * (c0 if k == 0 else c0 + bay) + Vector3(0, y0 + 0.25, 0)
				var hi := surf_c + ax * mid + Vector3(0, y0 + fh - 0.25, 0)
				beam(bt, xf, lo, hi, 0.18)
			elif k % 2 == 1 or nb <= 3:
				_window(bt, xf, surf_c + ax * mid + Vector3(0, y0 + 1.75, 0), ax, nrm, minf(bay - 0.5, 1.0))
		bx(bt, xf, surf_c + Vector3(0, y0 + 1.05, 0), (Vector3(ln, 0.14, 0.16) if ax == Vector3.RIGHT else Vector3(0.16, 0.14, ln)), "timber")


static func _window(bt: Batcher, xf: Transform3D, c: Vector3, ax: Vector3, nrm: Vector3, ww: float) -> void:
	var wh := 1.15
	var flat := func(a: float, b: float, depth: float) -> Vector3: return (ax * a + Vector3(0, b, 0) + nrm * depth).abs() + Vector3(0.0001, 0.0001, 0.0001)
	bx(bt, xf, c - nrm * 0.02, ax.abs() * ww + Vector3(0, wh, 0) + nrm.abs() * 0.08, "pane", Basis(), false)
	bx(bt, xf, c + nrm * 0.06 + Vector3(0, wh * 0.5, 0), ax.abs() * (ww + 0.3) + Vector3(0, 0.14, 0) + nrm.abs() * 0.2, "timber")
	bx(bt, xf, c + nrm * 0.1 - Vector3(0, wh * 0.5 + 0.05, 0), ax.abs() * (ww + 0.4) + Vector3(0, 0.12, 0) + nrm.abs() * 0.32, "timber")
	for s in [-1.0, 1.0]:
		bx(bt, xf, c + nrm * 0.06 + ax * s * (ww * 0.5 + 0.06), ax.abs() * 0.12 + Vector3(0, wh, 0) + nrm.abs() * 0.2, "timber")
	bx(bt, xf, c + nrm * 0.05, ax.abs() * 0.07 + Vector3(0, wh, 0) + nrm.abs() * 0.12, "timber")
	bx(bt, xf, c + nrm * 0.05, ax.abs() * ww + Vector3(0, 0.07, 0) + nrm.abs() * 0.12, "timber")
	# A flower box under some windows.
	bx(bt, xf, c + nrm * 0.32 - Vector3(0, wh * 0.5 + 0.2, 0), ax.abs() * (ww + 0.2) + Vector3(0, 0.26, 0) + nrm.abs() * 0.3, "plank_dark")
	flat.call(0, 0, 0)


static func _door(bt: Batcher, xf: Transform3D, base: Vector3, ax: Vector3, nrm: Vector3, dw: float) -> void:
	var dh := 2.35
	bx(bt, xf, base + Vector3(0, dh * 0.5, 0) - nrm * 0.02, ax.abs() * dw + Vector3(0, dh, 0) + nrm.abs() * 0.1, "plank_dark")
	for s in [-1.0, 1.0]:
		bx(bt, xf, base + ax * s * (dw * 0.5 + 0.1) + Vector3(0, dh * 0.5, 0) + nrm * 0.05, ax.abs() * 0.22 + Vector3(0, dh, 0) + nrm.abs() * 0.26, "timber")
	bx(bt, xf, base + Vector3(0, dh + 0.12, 0) + nrm * 0.06, ax.abs() * (dw + 0.7) + Vector3(0, 0.26, 0) + nrm.abs() * 0.32, "timber")
	# Little hood over the door.
	var hb := Basis(ax.cross(Vector3.UP).normalized() * -1.0 if false else ax, Vector3.UP, nrm)
	bt.add(boxm(Vector3(dw + 1.0, 0.1, 0.9)), xf * Transform3D(hb * Basis(Vector3.RIGHT, deg_to_rad(-22)), base + Vector3(0, dh + 0.55, 0) + nrm * 0.45), "roof_b", M("roof_b"))
	for s in [-1.0, 1.0]:
		beam(bt, xf, base + ax * s * (dw * 0.5 + 0.2) + Vector3(0, dh - 0.35, 0) + nrm * 0.05, base + ax * s * (dw * 0.5 + 0.3) + Vector3(0, dh + 0.4, 0) + nrm * 0.75, 0.12)


## Round tower with a plaster drum, timber posts and rings, slit windows and a flared cone roof.
static func tower(bt: Batcher, p: Vector3, r: float, h: float, o := {}) -> void:
	var xf := Transform3D(Basis(), p)
	var segs := 14
	bt.add(_cyl(r + 0.35, 3.6, r + 0.5, segs), xf * Transform3D(Basis(), Vector3(0, -1.2, 0)), "stone", M("stone"))
	bt.add(_cyl(r, h, r, segs), xf * Transform3D(Basis(), Vector3(0, 0.6 + h * 0.5, 0)), o.get("plaster", "plaster"), M(o.get("plaster", "plaster")))
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		bx(bt, xf, d * (r + 0.06) + Vector3(0, 0.6 + h * 0.5, 0), Vector3(0.26, h, 0.26), "timber", Basis(Vector3.UP, -a))
		if k % 2 == 1:
			bx(bt, xf, d * (r + 0.02) + Vector3(0, 0.6 + h * 0.62, 0), Vector3(0.12, 1.1, 0.5), "pane", Basis(Vector3.UP, -a), false)
	for yy in [0.75, 0.6 + h * 0.5, 0.6 + h - 0.1]:
		bt.add(_cyl(r + 0.1, 0.24, r + 0.1, segs), xf * Transform3D(Basis(), Vector3(0, yy, 0)), "timber", M("timber"))
	var rk: String = o.get("roof", "roof_g")
	bt.add(cone_roof(r, r * 1.5, 0.9, 0.24, 0.55, 18), xf * Transform3D(Basis(), Vector3(0, 0.6 + h, 0)), rk, M(rk))
	bt.add(_cyl(0.08, 2.2, 0.02, 6), xf * Transform3D(Basis(), Vector3(0, 0.6 + h + r * 1.5 + 1.0, 0)), "brass", M("brass"))
	var cs := CylinderShape3D.new(); cs.radius = r + 0.3; cs.height = h + 1.0
	bt.collider(cs, xf * Transform3D(Basis(), Vector3(0, (h + 1.0) * 0.5, 0)))


static func _cyl(r: float, h: float, r2: float, seg := 12) -> CylinderMesh:
	var key := "c|%.2f|%.2f|%.2f|%d" % [r, h, r2, seg]
	if _c.has(key): return _c[key]
	var c := CylinderMesh.new(); c.bottom_radius = r; c.top_radius = r2; c.height = h; c.radial_segments = seg; c.rings = 1
	_c[key] = c
	return c


## Open round pavilion: timber columns on a stone dais under a flared cone roof.
static func pavilion(bt: Batcher, p: Vector3, r: float, h: float, roof := "roof_g", posts := 8) -> void:
	var xf := Transform3D(Basis(), p)
	bt.add(_cyl(r + 0.8, 1.2, r + 1.1, 24), xf * Transform3D(Basis(), Vector3(0, -0.2, 0)), "stone", M("stone"))
	bt.add(_cyl(r + 0.5, 0.12, r + 0.5, 24), xf * Transform3D(Basis(), Vector3(0, 0.42, 0)), "plank", M("plank"))
	for k in posts:
		var a := TAU * k / posts
		var d := Vector3(cos(a), 0, sin(a)) * r
		bt.add(_cyl(0.22, h, 0.18, 8), xf * Transform3D(Basis(), d + Vector3(0, 0.4 + h * 0.5, 0)), "timber", M("timber"))
		beam(bt, xf, d + Vector3(0, 0.4 + h - 0.9, 0), d * 0.82 + Vector3(0, 0.4 + h, 0), 0.14)
		var cs := CylinderShape3D.new(); cs.radius = 0.25; cs.height = h
		bt.collider(cs, xf * Transform3D(Basis(), d + Vector3(0, 0.4 + h * 0.5, 0)))
	bt.add(_cyl(r + 0.1, 0.3, r + 0.1, 24), xf * Transform3D(Basis(), Vector3(0, 0.4 + h, 0)), "timber", M("timber"))
	bt.add(cone_roof(r, r * 0.95, 1.2, 0.26, 0.7, 24), xf * Transform3D(Basis(), Vector3(0, 0.55 + h, 0)), roof, M(roof))
	var dais := CylinderShape3D.new(); dais.radius = r + 1.0; dais.height = 1.0
	bt.collider(dais, xf * Transform3D(Basis(), Vector3(0, -0.1, 0)))


# ----------------------------------------------------------------------------- street furniture
static func hang_lamp(bt: Batcher, xf: Transform3D) -> void:
	bt.add(boxm(Vector3(0.08, 0.5, 0.08)), xf * Transform3D(Basis(), Vector3(0, 0.2, 0)), "iron", M("iron"))
	bt.add(boxm(Vector3(0.34, 0.42, 0.34)), xf * Transform3D(Basis(), Vector3(0, -0.2, 0)), "lamp", M("lamp"), false)
	bt.add(_cyl(0.32, 0.18, 0.04, 4), xf * Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0.08, 0)), "iron", M("iron"))
	for s in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		bt.add(boxm(Vector3(0.04, 0.46, 0.04)), xf * Transform3D(Basis(), Vector3(s.x * 0.17, -0.2, s.z * 0.17)), "iron", M("iron"))


## Lantern post: stone foot, timber post, a bracket and a hanging lantern. Optionally a real light.
static func lamp_post(bt: Batcher, root: Node3D, p: Vector3, yaw: float, light := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	bx(bt, xf, Vector3(0, 0.25, 0), Vector3(0.55, 0.5, 0.55), "stone")
	bx(bt, xf, Vector3(0, 2.0, 0), Vector3(0.2, 3.2, 0.2), "timber")
	beam(bt, xf, Vector3(0, 3.4, 0), Vector3(0.85, 3.4, 0), 0.12)
	beam(bt, xf, Vector3(0, 2.9, 0), Vector3(0.55, 3.38, 0), 0.08)
	hang_lamp(bt, xf * Transform3D(Basis(), Vector3(0.8, 3.0, 0)))
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc878"); l.light_energy = 1.2; l.omni_range = 9.0; l.shadow_enabled = false
		l.distance_fade_enabled = true; l.distance_fade_begin = 45.0; l.distance_fade_length = 15.0
		l.position = xf * Vector3(0.8, 2.8, 0)
		root.add_child(l)


## Railing along a path of points (top rail, mid rail and posts).
static func railing(bt: Batcher, pts: Array, h := 1.0, key := "timber") -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		beam(bt, Transform3D(), a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.12, key)
		beam(bt, Transform3D(), a + Vector3(0, h * 0.5, 0), b + Vector3(0, h * 0.5, 0), 0.08, key)
		var n := maxi(1, int(a.distance_to(b) / 1.6))
		for k in n + 1:
			var q := a.lerp(b, float(k) / n)
			beam(bt, Transform3D(), q - Vector3(0, 0.05, 0), q + Vector3(0, h + 0.08, 0), 0.14, key)


## Arched footbridge from a to b (deck centreline), with stone abutments and railings.
static func bridge(bt: Batcher, a: Vector3, b: Vector3, width := 4.0, arch := 1.6) -> void:
	var dir := Vector3(b.x - a.x, 0, b.z - a.z)
	var len := dir.length()
	dir /= len
	var side := Vector3(-dir.z, 0, dir.x)
	var segs := 12
	var left := []; var right := []
	for i in segs:
		var t0 := float(i) / segs; var t1 := float(i + 1) / segs
		var p0 := a.lerp(b, t0) + Vector3(0, arch * sin(t0 * PI), 0)
		var p1 := a.lerp(b, t1) + Vector3(0, arch * sin(t1 * PI), 0)
		var fwd := (p1 - p0).normalized()
		var up := side.cross(fwd).normalized() * -1.0
		if up.y < 0: up = -up
		var basis := Basis(side, up, -fwd).orthonormalized()
		var mid := (p0 + p1) * 0.5
		var seg_len := p0.distance_to(p1) + 0.05
		bt.add(boxm(Vector3(width, 0.22, seg_len)), Transform3D(basis, mid), "plank", M("plank"))
		bt.add(boxm(Vector3(width + 0.3, 0.3, seg_len)), Transform3D(basis, mid - up * 0.24), "timber", M("timber"))
		var sh := BoxShape3D.new(); sh.size = Vector3(width, 0.3, seg_len)
		bt.collider(sh, Transform3D(basis, mid))
		left.append(p0 + side * (width * 0.5 - 0.1)); right.append(p0 - side * (width * 0.5 - 0.1))
		if i == segs - 1:
			left.append(p1 + side * (width * 0.5 - 0.1)); right.append(p1 - side * (width * 0.5 - 0.1))
	railing(bt, left, 1.05); railing(bt, right, 1.05)
	# Ring medallions set between the rails.
	for rail in [left, right]:
		for i in range(1, rail.size() - 1, 2):
			var q: Vector3 = rail[i]
			var face := Basis(Quaternion(Vector3.UP, side.normalized()))
			bt.add(_cyl(0.36, 0.08, 0.36, 16), Transform3D(face, q + Vector3(0, 0.62, 0)), "brass", M("brass"))
			bt.add(_cyl(0.24, 0.1, 0.24, 12), Transform3D(face, q + Vector3(0, 0.62, 0)), "timber", M("timber"))
	# Curved ribs under the deck.
	for s in [-1.0, 1.0]:
		var prev: Vector3 = a + side * s * (width * 0.5 - 0.3) - Vector3(0, 0.6, 0)
		for i in range(1, segs + 1):
			var t := float(i) / segs
			var q: Vector3 = a.lerp(b, t) + side * s * (width * 0.5 - 0.3) + Vector3(0, arch * sin(t * PI) - 0.6 - (1.0 - sin(t * PI)) * 0.8, 0)
			beam(bt, Transform3D(), prev, q, 0.3)
			prev = q
	for e in [[a, -1.0], [b, 1.0]]:
		var c: Vector3 = e[0] + dir * e[1] * 1.0
		bt.add(boxm(Vector3(width + 1.2, 3.0, 2.4)), Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)).orthonormalized(), c - Vector3(0, 1.62, 0)), "stone", M("stone"))
		for s in [-1.0, 1.0]:
			bx(bt, Transform3D(), c + side * s * (width * 0.5 + 0.35) + Vector3(0, 0.55, 0), Vector3(0.6, 1.3, 0.6), "stone")


## A run of steps from `a` (bottom) to `b` (top), with a walkable ramp collider.
static func stairs(bt: Batcher, a: Vector3, b: Vector3, width := 3.0, key := "stone") -> void:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var run := flat.length()
	var dir := flat / run
	var side := Vector3(-dir.z, 0, dir.x)
	var rise := b.y - a.y
	var n := maxi(2, int(ceil(absf(rise) / 0.28)))
	var basis := Basis(side, Vector3.UP, -dir).orthonormalized()
	for i in n:
		var t := (i + 0.5) / n
		var top := a.y + rise * float(i + 1) / n
		var c := Vector3(a.x, 0, a.z) + dir * run * t
		var hgt := top - (a.y - 0.6)
		bt.add(boxm(Vector3(width, hgt, run / n + 0.02)), Transform3D(basis, Vector3(c.x, a.y - 0.6 + hgt * 0.5, c.z)), key, M(key))
	var ramp := BoxShape3D.new()
	var slope := Vector3(b.x - a.x, rise, b.z - a.z)
	ramp.size = Vector3(width, 0.3, slope.length())
	var fwd := slope.normalized()
	var up := side.cross(fwd) * -1.0
	if up.y < 0: up = -up
	bt.collider(ramp, Transform3D(Basis(side, up, -fwd).orthonormalized(), (a + b) * 0.5 - up * 0.12))
	for s in [-1.0, 1.0]:
		beam(bt, Transform3D(), a + side * s * (width * 0.5 + 0.2) + Vector3(0, 0.2, 0), b + side * s * (width * 0.5 + 0.2) + Vector3(0, 0.2, 0), 0.45, key)


## Stone retaining wall following points along the ground, `h` tall above each point.
static func retaining(bt: Batcher, pts: Array, h: float, key := "stone", t := 0.8) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var d := Vector3(b.x - a.x, 0, b.z - a.z)
		var l := d.length()
		if l < 0.05: continue
		var basis := Basis(Vector3.UP, atan2(d.x, d.z))
		var c := (a + b) * 0.5
		var base := minf(a.y, b.y) - 2.0
		var top := maxf(a.y, b.y) + h
		bt.add(boxm(Vector3(t, top - base, l + t)), Transform3D(basis, Vector3(c.x, (top + base) * 0.5, c.z)), key, M(key))
		bt.add(boxm(Vector3(t + 0.2, 0.18, l + t + 0.1)), Transform3D(basis, Vector3(c.x, top + 0.09, c.z)), "stone_dark", M("stone_dark"))
		var sh := BoxShape3D.new(); sh.size = Vector3(t, top - base, l)
		bt.collider(sh, Transform3D(basis, Vector3(c.x, (top + base) * 0.5, c.z)))


## Market stall: counter, posts and a striped cloth canopy.
static func stall(bt: Batcher, p: Vector3, yaw: float, cloth := "cloth_g") -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	bx(bt, xf, Vector3(0, 0.5, 0.4), Vector3(3.0, 1.0, 0.9), "plank")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bx(bt, xf, Vector3(sx * 1.45, 1.3 + (0.3 if sz < 0 else 0.0), sz * 0.9 + 0.2), Vector3(0.14, 2.6 + (0.6 if sz < 0 else 0.0), 0.14), "timber")
	bt.add(boxm(Vector3(3.4, 0.06, 2.4)), xf * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(14)), Vector3(0, 2.75, 0.2)), cloth, M(cloth), false)
	bt.add(boxm(Vector3(3.4, 0.07, 0.5)), xf * Transform3D(Basis(), Vector3(0, 2.45, 1.4)), "cloth_y", M("cloth_y"), false)
	for k in 3:
		bx(bt, xf, Vector3(-0.9 + k * 0.9, 1.1, 0.4), Vector3(0.6, 0.22, 0.5), "plank_dark")
	var sh := BoxShape3D.new(); sh.size = Vector3(3.0, 1.0, 0.9)
	bt.collider(sh, xf * Transform3D(Basis(), Vector3(0, 0.5, 0.4)))


## A tall cloth banner hung from a crossbar.
static func banner(bt: Batcher, p: Vector3, yaw: float, h := 3.0, key := "cloth_g") -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	bx(bt, xf, Vector3(0, 0, 0), Vector3(1.5, 0.1, 0.1), "timber")
	bx(bt, xf, Vector3(0, -h * 0.5, 0), Vector3(1.2, h, 0.04), key, Basis(), false)
	bx(bt, xf, Vector3(0, -h + 0.1, 0), Vector3(1.2, 0.2, 0.05), "cloth_y", Basis(), false)


static func crates(bt: Batcher, p: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	bx(bt, xf, Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), "plank")
	bx(bt, xf, Vector3(0.9, 0.35, 0.2), Vector3(0.7, 0.7, 0.7), "plank_dark")
	bx(bt, xf, Vector3(0.3, 1.1, 0.1), Vector3(0.6, 0.6, 0.6), "plank")
	bt.add(_cyl(0.38, 1.0, 0.38, 10), xf * Transform3D(Basis(), Vector3(-0.9, 0.5, 0.3)), "plank_dark", M("plank_dark"))


# ----------------------------------------------------------------------------- trees and plants
## Tube along points with per-point radii (bark), smooth-shaded.
static func _tube(st: SurfaceTool, pts: Array, radii: Array, sides: int) -> void:
	var prev_n := Vector3.ZERO
	var rings := []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var t: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]) as Vector3).normalized()
		var n: Vector3
		if prev_n == Vector3.ZERO:
			n = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		else:
			n = (prev_n - t * prev_n.dot(t)).normalized()
		prev_n = n
		var bn := t.cross(n)
		var ring := []
		for k in sides:
			var a := TAU * k / sides
			var dir := n * cos(a) + bn * sin(a)
			ring.append([p + dir * float(radii[i]), dir])
		rings.append(ring)
	var c := Color(0, 0, 0)
	for i in rings.size() - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			var a: Array = rings[i][k]; var b: Array = rings[i][k1]; var cc: Array = rings[i + 1][k1]; var d: Array = rings[i + 1][k]
			_tri_s(st, [a[0], b[0], cc[0]], [a[1], b[1], cc[1]], [c, c, c], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
			_tri_s(st, [a[0], cc[0], d[0]], [a[1], cc[1], d[1]], [c, c, c], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


static func _bez(a: Vector3, c: Vector3, b: Vector3, n: int) -> Array:
	var out := []
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out


## Leaf cards scattered over an ellipsoid shell, shaded as one rounded mass.
static func _cluster(st: SurfaceTool, c: Vector3, r: float, count: int, size: float, rng: RandomNumberGenerator, squash := 0.7) -> void:
	for i in count:
		var u := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1.0), rng.randf_range(-1, 1)).normalized()
		var p := c + Vector3(u.x, u.y * squash, u.z) * r * rng.randf_range(0.5, 1.0)
		var fn := (u + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
		var tx := fn.cross(Vector3.UP if absf(fn.y) < 0.9 else Vector3.RIGHT).normalized().rotated(fn, rng.randf() * TAU)
		var ty := fn.cross(tx)
		var s := size * rng.randf_range(0.75, 1.2)
		var v := [p - tx * s * 0.5 - ty * s * 0.5, p + tx * s * 0.5 - ty * s * 0.5, p + tx * s * 0.5 + ty * s * 0.5, p - tx * s * 0.5 + ty * s * 0.5]
		var nn := (u + Vector3(0, 0.35, 0)).normalized()
		var sw := Color(clampf(0.4 + u.y * 0.3 + 0.3, 0.2, 1.0), 0, 0)
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		_tri_s(st, [v[0], v[1], v[2]], [nn, nn, nn], [sw, sw, sw], [uv[0], uv[1], uv[2]])
		_tri_s(st, [v[0], v[2], v[3]], [nn, nn, nn], [sw, sw, sw], [uv[0], uv[2], uv[3]])


## Generated tree meshes, cached by kind and variant. Kinds: "great" (the Lotus Stand's tree),
## "elder" (giant buttress-rooted Shroud trees), "oak", "slim", "bush", "fern".
static func tree(kind: String, variant := 0) -> ArrayMesh:
	var key := "tree|%s|%d" % [kind, variant]
	if _c.has(key): return _c[key]
	var rng := RandomNumberGenerator.new(); rng.seed = hash(key)
	var bark := SurfaceTool.new(); bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf := SurfaceTool.new(); leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lmat: Material = leaf_mat(0, "#26431a", "#41621f", "#7c8a2a", 0.06 if kind in ["elder", "great"] else 0.12)
	var bmat: Material = M("bark")
	match kind:
		"elder", "great":
			var big := 1.55 if kind == "great" else 1.0
			var H := rng.randf_range(26.0, 32.0) * big
			var rb := 2.6 * big
			var rt := 0.9 * big
			var pts := []; var radii := []
			var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 0.06
			for i in 10:
				var t := float(i) / 9.0
				var y := -1.0 + t * (H + 1.0)
				pts.append(Vector3(0, y, 0) + lean * y + Vector3(sin(t * 5.0 + variant) * 0.4, 0, cos(t * 4.0) * 0.4) * big)
				radii.append(rt + (rb - rt) * pow(1.0 - t, 1.6) + 1.6 * big * exp(-maxf(y, 0.0) / 1.6))
			_tube(bark, pts, radii, 14)
			for k in 7:
				var a := TAU * k / 7.0 + rng.randf_range(-0.3, 0.3)
				var d := Vector3(cos(a), 0, sin(a))
				var y0 := rng.randf_range(2.0, 4.0) * big
				var R := rb * rng.randf_range(2.4, 3.4)
				var root_pts := _bez(d * rb * 0.6 + Vector3(0, y0, 0), d * R * 0.55 + Vector3(0, y0 * 0.7, 0), d * R + Vector3(0, -0.9, 0), 7)
				var rr := []
				for i in root_pts.size(): rr.append(lerpf(1.25 * big, 0.25, float(i) / (root_pts.size() - 1)))
				_tube(bark, root_pts, rr, 8)
			var crown := pts[pts.size() - 1] as Vector3
			for k in 6:
				var a := TAU * k / 6.0 + rng.randf_range(-0.4, 0.4)
				var d := Vector3(cos(a), 0, sin(a))
				var y := H * rng.randf_range(0.5, 0.88)
				var start := Vector3(0, y, 0) + lean * y
				var L := rng.randf_range(9.0, 14.0) * big
				var end := start + d * L + Vector3(0, L * rng.randf_range(0.35, 0.6), 0)
				var lp := _bez(start, start + d * L * 0.5 + Vector3(0, L * 0.05, 0), end, 6)
				var lr := []
				for i in lp.size(): lr.append(lerpf(0.95 * big, 0.2, float(i) / (lp.size() - 1)))
				_tube(bark, lp, lr, 7)
				_cluster(leaf, end + Vector3(0, 1.0, 0), rng.randf_range(4.8, 6.5) * big, int(46 * big), 3.6 * big, rng)
				_cluster(leaf, start.lerp(end, 0.55) + Vector3(0, 2.0, 0), 3.8 * big, int(22 * big), 3.0 * big, rng)
			_cluster(leaf, crown + Vector3(0, 2.0, 0), 7.0 * big, int(60 * big), 3.8 * big, rng, 0.55)
		"oak":
			var H := rng.randf_range(8.0, 11.0)
			var pts := []; var radii := []
			for i in 6:
				var t := float(i) / 5.0
				pts.append(Vector3(sin(t * 3.0 + variant) * 0.25, -0.4 + t * H * 0.7, cos(t * 2.0) * 0.25))
				radii.append(lerpf(0.65, 0.28, t) + 0.35 * exp(-t * 8.0))
			_tube(bark, pts, radii, 9)
			var top := pts[pts.size() - 1] as Vector3
			for k in 4:
				var a := TAU * k / 4.0 + rng.randf_range(-0.4, 0.4)
				var d := Vector3(cos(a), 0, sin(a))
				var s := top - Vector3(0, H * 0.15, 0)
				var e := s + d * rng.randf_range(2.5, 3.5) + Vector3(0, rng.randf_range(1.5, 2.5), 0)
				var lp := _bez(s, s + d * 1.2 + Vector3(0, 0.4, 0), e, 4)
				_tube(bark, lp, [0.3, 0.25, 0.2, 0.15, 0.1], 6)
				_cluster(leaf, e + Vector3(0, 0.6, 0), rng.randf_range(2.3, 3.0), 34, 2.0, rng)
			_cluster(leaf, top + Vector3(0, 2.2, 0), 3.2, 40, 2.1, rng, 0.6)
		"slim":
			var H := rng.randf_range(14.0, 18.0)
			var pts := []; var radii := []
			for i in 7:
				var t := float(i) / 6.0
				pts.append(Vector3(sin(t * 2.0 + variant) * 0.35, -0.4 + t * H, 0))
				radii.append(lerpf(0.5, 0.16, t) + 0.25 * exp(-t * 10.0))
			bmat = M("bark_pale")
			_tube(bark, pts, radii, 8)
			for k in 4:
				var y := H * (0.5 + k * 0.13)
				_cluster(leaf, Vector3(rng.randf_range(-0.8, 0.8), y, rng.randf_range(-0.8, 0.8)), 2.6 - k * 0.3, 26, 2.0, rng, 0.8)
		"bush":
			for k in 3:
				_cluster(leaf, Vector3(rng.randf_range(-0.7, 0.7), 0.7, rng.randf_range(-0.7, 0.7)), rng.randf_range(0.8, 1.2), 20, 1.0, rng, 0.75)
			lmat = leaf_mat(0, "#2a4a1c", "#4a6e26", "#6a8a2a", 0.05)
		"fern":
			for k in 9:
				var a := TAU * k / 9.0 + rng.randf_range(-0.2, 0.2)
				var d := Vector3(cos(a), 0, sin(a))
				var side := Vector3(-d.z, 0, d.x)
				var L := rng.randf_range(0.9, 1.4)
				var prev := Vector3.ZERO
				for s in 4:
					var t0 := float(s) / 4.0; var t1 := float(s + 1) / 4.0
					var p0 := d * L * t0 + Vector3(0, L * 0.7 * sin(t0 * PI * 0.75), 0)
					var p1 := d * L * t1 + Vector3(0, L * 0.7 * sin(t1 * PI * 0.75), 0)
					var w0 := side * 0.22 * L; var w1 := side * 0.22 * L
					var nn := Vector3.UP
					var c0 := Color(t0, 0, 0); var c1 := Color(t1, 0, 0)
					_tri_s(leaf, [p0 - w0, p0 + w0, p1 + w1], [nn, nn, nn], [c0, c0, c1], [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1)])
					_tri_s(leaf, [p0 - w0, p1 + w1, p1 - w1], [nn, nn, nn], [c0, c1, c1], [Vector2(0, t0), Vector2(1, t1), Vector2(0, t1)])
					prev = p1
			lmat = leaf_mat(1, "#2e5020", "#5a7e2c", "#6a8a30", 0.08)
	var am := ArrayMesh.new()
	if kind != "bush" and kind != "fern":
		bark.set_material(bmat)
		am = bark.commit(am)
	leaf.set_material(lmat)
	am = leaf.commit(am)
	_c[key] = am
	return am


## Scatter instances of a generated mesh in spatial chunks (MultiMesh per chunk).
static func scatter(parent: Node3D, mesh: Mesh, xforms: Array, vis_end: float, shadows := true, chunk := 64.0) -> void:
	var buckets := {}
	for xf in xforms:
		var key := Vector2i(floori(xf.origin.x / chunk), floori(xf.origin.z / chunk))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(xf)
	for key in buckets:
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size(): mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if vis_end < 150.0 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if not shadows: mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


## Placeholder hook for a trunk rising through a roof (used by house(tree=true)).
static func trees_extra(root: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = tree("oak", 3)
	mi.position = at
	mi.scale = Vector3.ONE * 1.3
	root.add_child(mi)


## Shafts of sunlight: crossed additive quads leaning with the sun.
static func light_shafts(root: Node3D, spots: Array, sun_dir: Vector3) -> void:
	var q := QuadMesh.new(); q.size = Vector2(3.5, 26.0); q.center_offset = Vector3(0, 13.0, 0)
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/lightshaft.gdshader")
	m.set_shader_parameter("noise_tex", Props.noise())
	q.material = m
	var lean := Basis(Vector3(sun_dir.z, 0, -sun_dir.x).normalized(), -acos(clampf(-sun_dir.y, -1.0, 1.0)) * 0.6) if absf(sun_dir.y) < 0.999 else Basis()
	var xfs := []
	for p in spots:
		for k in 2:
			xfs.append(Transform3D(lean * Basis(Vector3.UP, k * PI * 0.5 + p.x), p))
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = q
	mm.instance_count = xfs.size()
	for i in xfs.size(): mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 140.0
	root.add_child(mmi)
