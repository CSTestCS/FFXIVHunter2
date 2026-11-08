class_name FX
extends Node3D
## Pooled combat visuals: damage numbers, hit sparks, novas, beams, weapon trails and
## ground telegraphs (decals, so they follow uneven terrain). Everything is unshaded and
## light-free to stay cheap; nothing allocates per frame once the pools are warm.

static var _tex := {}
static var _mats := {}
static var _tele_shader: Shader = preload("res://shaders/telegraph.gdshader")
var _numbers: Array[Label3D] = []
var _num_i := 0
var _sphere := SphereMesh.new()
var _ring := TorusMesh.new()
var cam_shake := 0.0
var hitstop := 0.0


func _ready() -> void:
	_sphere.radial_segments = 16; _sphere.rings = 8
	_ring.inner_radius = 0.9; _ring.outer_radius = 1.0; _ring.rings = 32; _ring.ring_segments = 4
	for i in 24:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.font_size = 40
		l.outline_size = 10
		l.visible = false
		add_child(l)
		_numbers.append(l)


func _process(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta / maxf(Engine.time_scale, 0.01)
		if hitstop <= 0.0: Engine.time_scale = 1.0


func do_hitstop(t := 0.06) -> void:
	hitstop = t
	Engine.time_scale = 0.05


func shake(amount: float) -> void:
	cam_shake = maxf(cam_shake, amount * float(Settings.v["cam_shake"]))


static func mat(color: Color, energy := 2.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), energy, alpha]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if alpha < 1.0 else BaseMaterial3D.BLEND_MODE_MIX
	m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = energy
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_mats[key] = m
	return m


func number(pos: Vector3, text: String, color: Color, big := false) -> void:
	var l := _numbers[_num_i]
	_num_i = (_num_i + 1) % _numbers.size()
	l.text = text
	l.modulate = color
	l.font_size = 52 if big else 38
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	l.visible = true
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.1, 0), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(func(): l.visible = false)


func burst(pos: Vector3, color: Color, size := 1.0, time := 0.25) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = mat(color, 3.0, 0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.2
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "transparency", 1.0, time)
	tw.tween_callback(mi.queue_free)


func nova(pos: Vector3, radius: float, color: Color, time := 0.45) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring
	mi.material_override = mat(color, 3.0, 0.8)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(0.2, 1.0, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1.0 + radius * 0.1, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(mi, "transparency", 1.0, time)
	tw.tween_callback(mi.queue_free)
	burst(pos + Vector3(0, 0.8, 0), color, radius * 0.6, time)


func beam(from: Vector3, to: Vector3, color: Color, width := 0.35, time := 0.35) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = width; c.bottom_radius = width; c.height = 1.0; c.radial_segments = 10; c.rings = 1
	mi.mesh = c
	mi.material_override = mat(color, 4.0, 0.75)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var len := from.distance_to(to)
	mi.global_position = (from + to) * 0.5
	if len > 0.01:
		var up := (to - from).normalized()
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		mi.global_transform.basis = Basis(side, up, side.cross(up)).scaled(Vector3(1, len, 1))
	var tw := mi.create_tween()
	tw.tween_property(mi, "transparency", 1.0, time)
	tw.tween_callback(mi.queue_free)


## Arc-shaped slash ribbon in front of an actor (cheap stand-in for a per-frame trail).
func slash(origin: Vector3, fwd: Vector3, color: Color, radius := 2.0, arc := 120.0, tilt := 0.0) -> void:
	fwd = Vector3(fwd.x, 0, fwd.z).normalized() if Vector2(fwd.x, fwd.z).length() > 0.01 else Vector3.FORWARD
	var im := ImmediateMesh.new()
	var segs := 14
	var right := fwd.cross(Vector3.UP).normalized()
	var up := Vector3.UP.rotated(fwd, deg_to_rad(tilt))
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var a := deg_to_rad(-arc * 0.5 + arc * i / segs)
		var dir := (fwd * cos(a) + right * sin(a)).rotated(fwd, deg_to_rad(tilt)).normalized()
		var fade := sin(PI * i / segs)
		im.surface_set_color(Color(color, fade))
		im.surface_add_vertex(dir * radius * 0.55)
		im.surface_set_color(Color(color, fade * 0.9))
		im.surface_add_vertex(dir * radius + up * 0.05)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := mat(color, 3.0, 0.75).duplicate()
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = origin
	var tw := mi.create_tween()
	tw.tween_property(mi, "transparency", 1.0, 0.22)
	tw.tween_callback(mi.queue_free)


# --------------------------------------------------------------------------- telegraphs
## shape: circle | cone | line | donut. Returns the node; it frees itself after `time`.
## params: radius, arc (deg), width, length, inner (donut ratio 0..1)
func telegraph(shape: String, pos: Vector3, dir: Vector3, p: Dictionary, time: float, color := Color(1.0, 0.45, 0.15), danger := true) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var w := get_parent()
	if danger and w.has_method("add_danger"): w.add_danger(shape, pos, dir, p, time)
	if dir.length() > 0.01:
		var d := Vector3(dir.x, 0, dir.z).normalized()
		root.global_transform.basis = Basis.looking_at(d, Vector3.UP)
	var key := shape
	var rect := Rect2()   # local XZ extent (x, z); forward is -Z
	match shape:
		"circle":
			rect = Rect2(-p["radius"], -p["radius"], p["radius"] * 2.0, p["radius"] * 2.0)
		"cone":
			key = "cone_%d" % int(p.get("arc", 90.0))
			rect = Rect2(-p["radius"], -p["radius"], p["radius"] * 2.0, p["radius"] * 2.0)
		"donut":
			key = "donut_%d" % int(p.get("inner", 0.4) * 100.0)
			rect = Rect2(-p["radius"], -p["radius"], p["radius"] * 2.0, p["radius"] * 2.0)
		"line":
			var wd: float = p.get("width", 2.0)
			var ln: float = p.get("length", 10.0)
			rect = Rect2(-wd * 0.5, -ln, wd, ln)
	var mi := MeshInstance3D.new()
	mi.mesh = _draped_mesh(root, rect, w)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _tele_shader
	m.set_shader_parameter("shape_tex", _shape_tex(key))
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("linear_fill", shape == "line")
	mi.material_override = m
	root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, time)
	tw.tween_callback(root.queue_free)
	if danger and not Settings.v["aoe_markers"]: root.visible = false
	return root


## Grid mesh over `rect` (marker-local XZ) whose vertices follow the ground (or water surface).
func _draped_mesh(root: Node3D, rect: Rect2, w: Node) -> ArrayMesh:
	var nx := clampi(int(ceil(rect.size.x / 0.9)), 2, 44)
	var nz := clampi(int(ceil(rect.size.y / 0.9)), 2, 44)
	var xf := root.global_transform
	var base_y := xf.origin.y
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var has_ground := w.has_method("ground_height")
	for iz in nz + 1:
		for ix in nx + 1:
			var u := float(ix) / nx
			var v := float(iz) / nz
			var local := Vector3(rect.position.x + u * rect.size.x, 0, rect.position.y + v * rect.size.y)
			var wp := xf * local
			var gy := base_y
			if has_ground:
				gy = maxf(w.ground_height(wp.x, wp.z), w.water_level(wp.x, wp.z))
			local.y = gy - base_y + 0.06
			verts.append(local)
			uvs.append(Vector2(u, v))
	var idx := PackedInt32Array()
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			idx.append_array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _shape_tex(key: String) -> Texture2D:
	if _tex.has(key): return _tex[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var arc := 360.0
	var inner := 0.0
	if key.begins_with("cone_"): arc = float(key.substr(5))
	if key.begins_with("donut_"): inner = float(key.substr(6)) / 100.0
	for y in n:
		for x in n:
			var a := 0.0
			if key == "line":
				var ex := absf(x - n * 0.5 + 0.5) / (n * 0.5)
				var ey := absf(y - n * 0.5 + 0.5) / (n * 0.5)
				var e := maxf(ex, ey)
				a = 0.45 + 0.55 * smoothstep(0.86, 0.98, e) if e <= 1.0 else 0.0
			else:
				var dx := (x - n * 0.5 + 0.5) / (n * 0.5)
				var dy := (y - n * 0.5 + 0.5) / (n * 0.5)
				var r := sqrt(dx * dx + dy * dy)
				if r <= 1.0 and r >= inner:
					var ang := rad_to_deg(absf(atan2(dx, -dy)))
					if ang <= arc * 0.5:
						var edge := maxf(smoothstep(0.88, 0.99, r), smoothstep(inner + 0.08, inner, r) if inner > 0.0 else 0.0)
						if arc < 360.0: edge = maxf(edge, smoothstep(arc * 0.5 - 4.0, arc * 0.5, ang))
						a = 0.4 + 0.6 * edge
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


## Point-in-shape test matching the telegraph (used for hits and companion dodging).
static func inside(shape: String, origin: Vector3, dir: Vector3, p: Dictionary, point: Vector3, pad := 0.4) -> bool:
	var d := Vector3(point.x - origin.x, 0, point.z - origin.z)
	var dist := d.length()
	match shape:
		"circle":
			return dist <= float(p["radius"]) + pad
		"donut":
			return dist <= float(p["radius"]) + pad and dist >= float(p["radius"]) * float(p.get("inner", 0.4)) - pad
		"cone":
			if dist > float(p["radius"]) + pad: return false
			if dist < 0.8: return true
			var f := Vector3(dir.x, 0, dir.z).normalized()
			return rad_to_deg(f.angle_to(d.normalized())) <= float(p.get("arc", 90.0)) * 0.5 + 6.0
		"line":
			var f := Vector3(dir.x, 0, dir.z).normalized()
			var along := d.dot(f)
			var side := absf(d.dot(f.cross(Vector3.UP)))
			return along >= -pad and along <= float(p.get("length", 10.0)) + pad and side <= float(p.get("width", 2.0)) * 0.5 + pad
	return false
