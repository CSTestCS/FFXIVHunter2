class_name MonsterBuilder
## Builds creature bodies from primitive meshes with PBR materials. Returns a rig dictionary
## of named pivots that Monster animates procedurally (no skeleton, very cheap).

static var _mat_cache := {}


static func pbr(hex: String, rough := 0.7, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [hex, rough, metal, emit]
	if _mat_cache.has(key): return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true; m.emission = Color(hex); m.emission_energy_multiplier = emit
	_mat_cache[key] = m
	return m


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _pivot(parent: Node3D, pos: Vector3, name := "") -> Node3D:
	var n := Node3D.new(); n.position = pos
	if name != "": n.name = name
	parent.add_child(n)
	return n


static func sph(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0 if h < 0 else h; s.radial_segments = 16; s.rings = 8; return s


static func cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, r * 2.0); c.radial_segments = 12; c.rings = 4; return c


static func cyl(r: float, h: float, r2 := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new(); c.bottom_radius = r; c.top_radius = r if r2 < 0 else r2; c.height = h; c.radial_segments = 10; c.rings = 1; return c


static func cone(r: float, h: float) -> CylinderMesh:
	return cyl(r, h, 0.001)


## Legs: returns [hip pivot, knee pivot]
static func _leg(parent: Node3D, pos: Vector3, len: float, r: float, mat: Material, foot := false) -> Array:
	var hip := _pivot(parent, pos)
	_mi(hip, cap(r, len * 0.55), mat, Vector3(0, -len * 0.25, 0))
	var knee := _pivot(hip, Vector3(0, -len * 0.5, 0))
	_mi(knee, cap(r * 0.8, len * 0.55), mat, Vector3(0, -len * 0.25, 0))
	if foot: _mi(knee, sph(r * 1.1), mat, Vector3(0, -len * 0.5, r * 0.6), Vector3.ZERO, Vector3(1, 0.5, 1.5))
	return [hip, knee]


static func build(d: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var body := _pivot(root, Vector3.ZERO, "body")
	var c1 := pbr(d["col"], 0.75)
	var c2 := pbr(d["col2"], 0.6)
	var eye := pbr("#fff4c0" if d.get("large", false) else "#202020", 0.2, 0.0, 1.5 if d.get("large", false) else 0.0)
	var rig := {"root": root, "body": body, "legs": [], "head": null, "tail": [], "wings": [], "parts": {}, "height": 1.0, "radius": 0.5, "glow": []}
	match d["body"]:
		"quad": _quad(d, rig, c1, c2, eye)
		"biped": _biped(d, rig, c1, c2, eye)
		"bird": _bird(d, rig, c1, c2, eye)
		"plant": _plant(d, rig, c1, c2, eye)
		"blob": _blob(d, rig, c1, c2, eye)
		"insect": _insect(d, rig, c1, c2, eye)
		"cactuar": _cactuar(d, rig, c1, c2, eye)
		"wyvern": _wyvern(d, rig, c1, c2, eye)
	_merge(root, rig)
	var s: float = d.get("size", 1.0)
	root.scale = Vector3.ONE * s
	rig["height"] *= s
	rig["radius"] *= s
	return rig


static func _quad(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	var leg_len := 0.55 if not d.get("shell", false) else 0.35
	b.position.y = leg_len + 0.1
	_mi(b, cap(0.3, 1.2), c1, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 1, 0.95))
	_mi(b, sph(0.27), c2, Vector3(0, -0.08, 0.1), Vector3.ZERO, Vector3(0.9, 0.7, 1.6))
	if d.get("shell", false):
		var shell := _mi(b, sph(0.75, 0.9), pbr(d["col2"], 0.5), Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.75, 1.15))
		rig["parts"]["shell"] = shell
	if d.get("mane", false):
		rig["parts"]["mane"] = _mi(b, sph(0.42), pbr(d["col2"], 0.9), Vector3(0, 0.1, 0.5), Vector3.ZERO, Vector3(1.2, 1.2, 0.9))
	var neck := _pivot(b, Vector3(0, 0.12, 0.62))
	var head := _pivot(neck, Vector3(0, 0.08, 0.18))
	_mi(head, sph(0.22), c1, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.25))
	_mi(head, sph(0.12), c2, Vector3(0, -0.06, 0.2), Vector3.ZERO, Vector3(1.1, 0.8, 1.2))
	for s in [-1.0, 1.0]:
		_mi(head, sph(0.035), eye, Vector3(0.11 * s, 0.07, 0.17))
		_mi(head, cone(0.06, 0.16), c1, Vector3(0.12 * s, 0.2, -0.02), Vector3(-15, 0, -20 * s))
		if d.get("horns", false):
			var horn := _mi(head, cone(0.06, 0.5), pbr("#e8e0c8", 0.4), Vector3(0.14 * s, 0.18, 0.0), Vector3(-60, 0, -35 * s))
			rig["parts"]["horns"] = horn
		if d.get("tusks", false):
			_mi(head, cone(0.03, 0.18), pbr("#f0ead8", 0.3), Vector3(0.08 * s, -0.08, 0.3), Vector3(70, 0, 0))
		if d.get("whiskers", false):
			var w := _mi(head, cyl(0.012, 0.5, 0.004), pbr(d["col2"], 0.4, 0.0, 1.2), Vector3(0.25 * s, 0.05, -0.15), Vector3(-20, 0, -60 * s))
			rig["parts"]["whiskers"] = w
			rig["glow"].append(w)
	rig["head"] = neck
	for z in [0.42, -0.42]:
		for x in [-0.2, 0.2]:
			rig["legs"].append(_leg(b, Vector3(x, -0.05, z), leg_len + 0.1, 0.085, c1, true))
	var tail := _pivot(b, Vector3(0, 0.1, -0.6))
	tail.rotation_degrees.x = 30
	var prev := tail
	for i in 4:
		_mi(prev, cap(0.06 * (1.0 - i * 0.18), 0.32), c1, Vector3(0, 0, -0.15), Vector3(90, 0, 0))
		var nx := _pivot(prev, Vector3(0, 0, -0.3)); prev = nx
		rig["tail"].append(nx)
	rig["height"] = 1.1
	rig["radius"] = 0.7


static func _biped(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	b.position.y = 0.75
	_mi(b, sph(0.38), c1, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1.15, 0.85))
	_mi(b, sph(0.3), c2, Vector3(0, 0.22, 0.12), Vector3.ZERO, Vector3(0.9, 1.0, 0.7))
	var head := _pivot(b, Vector3(0, 0.78, 0.05))
	_mi(head, sph(0.28), c1, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.85, 1.05))
	_mi(head, sph(0.18), c2, Vector3(0, -0.1, 0.18), Vector3.ZERO, Vector3(1.2, 0.5, 0.7))
	for s in [-1.0, 1.0]:
		_mi(head, sph(0.06), eye, Vector3(0.14 * s, 0.08, 0.2))
	if d.get("fishy", false):
		rig["parts"]["fin"] = _mi(head, PrismMesh.new(), c2, Vector3(0, 0.32, -0.05), Vector3(0, 90, 0), Vector3(0.05, 0.35, 0.5))
	rig["head"] = head
	for s in [-1.0, 1.0]:
		var arm := _pivot(b, Vector3(0.42 * s, 0.5, 0))
		arm.rotation_degrees.z = 20 * s
		_mi(arm, cap(0.09, 0.6), c1, Vector3(0, -0.25, 0))
		_mi(arm, sph(0.12), c2, Vector3(0, -0.58, 0.02))
		rig["parts"]["arm" + ("L" if s < 0 else "R")] = arm
	for x in [-0.18, 0.18]:
		rig["legs"].append(_leg(b, Vector3(x, 0.0, 0), 0.75, 0.11, c1, true))
	rig["height"] = 1.7
	rig["radius"] = 0.55


static func _bird(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	b.position.y = 0.7
	_mi(b, sph(0.35), c1, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.85, 1.2))
	var neck := _pivot(b, Vector3(0, 0.2, 0.28))
	_mi(neck, cap(0.09, 0.45), c1, Vector3(0, 0.18, 0.04), Vector3(15, 0, 0))
	var head := _pivot(neck, Vector3(0, 0.45, 0.08))
	_mi(head, sph(0.13), c1)
	_mi(head, cone(0.06, 0.2), c2, Vector3(0, -0.02, 0.17), Vector3(90, 0, 0))
	for s in [-1.0, 1.0]:
		_mi(head, sph(0.025), eye, Vector3(0.08 * s, 0.04, 0.08))
		var wing := _pivot(b, Vector3(0.3 * s, 0.1, 0))
		_mi(wing, sph(0.2), c1, Vector3(0.08 * s, 0, -0.05), Vector3.ZERO, Vector3(0.4, 0.8, 1.3))
		rig["wings"].append(wing)
	rig["head"] = neck
	for x in [-0.14, 0.14]:
		rig["legs"].append(_leg(b, Vector3(x, -0.2, 0), 0.55, 0.04, c2, true))
	rig["height"] = 1.4
	rig["radius"] = 0.5


static func _plant(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	if d.get("tentacles", false):
		b.position.y = 0.6
		_mi(b, sph(0.6), c1, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.9, 1.1))
		var head := _pivot(b, Vector3(0, 0.35, 0.35))
		_mi(head, sph(0.3), c2, Vector3.ZERO, Vector3.ZERO, Vector3(1.4, 0.6, 0.8))
		_mi(head, sph(0.22), pbr("#300808", 0.9), Vector3(0, 0, 0.12), Vector3.ZERO, Vector3(1.3, 0.4, 0.6))
		rig["head"] = head
		var tents := _pivot(b, Vector3.ZERO)
		rig["parts"]["tentacles"] = tents
		for i in 8:
			var a := i * TAU / 8.0
			var t := _pivot(tents, Vector3(cos(a) * 0.5, -0.2, sin(a) * 0.5))
			t.rotation = Vector3(0, -a + PI * 0.5, 0)
			var prev := t
			for k in 3:
				var seg := _pivot(prev, Vector3(0, 0, 0.0 if k == 0 else 0.35))
				seg.rotation_degrees.x = 25
				_mi(seg, cap(0.08 * (1.0 - k * 0.25), 0.4), c1, Vector3(0, 0, 0.18), Vector3(90, 0, 0))
				prev = seg
			rig["tail"].append(t)
		rig["height"] = 1.3
		rig["radius"] = 1.0
	elif d.get("branches", false):
		b.position.y = 0.0
		_mi(b, cyl(0.22, 1.6, 0.14), c1, Vector3(0, 0.8, 0))
		var head := _pivot(b, Vector3(0, 1.6, 0))
		_mi(head, sph(0.55), c2, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.2, 0.9, 1.2))
		for s in [-1.0, 1.0]:
			_mi(head, sph(0.05), pbr("#ffd040", 0.3, 0.0, 2.0), Vector3(0.1 * s, -0.25, 0.2))
			var arm := _pivot(b, Vector3(0.15 * s, 1.2, 0)); arm.rotation_degrees.z = -50 * s
			_mi(arm, cyl(0.07, 0.7, 0.03), c1, Vector3(0, 0.35, 0))
			rig["parts"]["arm" + ("L" if s < 0 else "R")] = arm
		rig["head"] = head
		rig["height"] = 2.2
		rig["radius"] = 0.6
	else:
		b.position.y = 0.0
		_mi(b, cyl(0.16, 0.5, 0.12), pbr("#efe2c8", 0.8), Vector3(0, 0.25, 0))
		var head := _pivot(b, Vector3(0, 0.5, 0))
		_mi(head, sph(0.4, 0.4), c2, Vector3(0, 0.08, 0), Vector3.ZERO, Vector3(1.1, 1.0, 1.1))
		for s in [-1.0, 1.0]:
			_mi(b, sph(0.04), eye, Vector3(0.08 * s, 0.38, 0.13))
		rig["head"] = head
		rig["height"] = 0.9
		rig["radius"] = 0.45


static func _blob(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	b.position.y = 0.55
	if d.get("crystal", false):
		var cm := pbr(d["col"], 0.1, 0.2, 2.5)
		var m := _mi(b, PrismMesh.new(), cm, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(0.55, 0.6, 0.55))
		_mi(b, PrismMesh.new(), cm, Vector3(0, -0.3, 0), Vector3(180, 0, 0), Vector3(0.55, 0.5, 0.55))
		rig["glow"].append(m)
	elif d.get("rocky", false):
		b.position.y = 0.45
		_mi(b, sph(0.45), c1, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.9, 1))
		for i in 5:
			_mi(b, sph(0.18), c1, Vector3(cos(i * 1.3) * 0.35, 0.2 + sin(i * 2.1) * 0.15, sin(i * 1.3) * 0.35))
		var lamp := _mi(b, sph(0.12), pbr(d["col2"], 0.2, 0.0, 3.0), Vector3(0, 0.25, 0.38))
		rig["glow"].append(lamp)
		for x in [-0.22, 0.22]:
			rig["legs"].append(_leg(b, Vector3(x, -0.3, 0), 0.3, 0.09, c1, true))
	else:
		var m := _mi(b, sph(0.5), pbr(d["col"], 0.5, 0.0, 1.6))
		rig["glow"].append(m)
		_mi(b, sph(0.2), pbr(d["col2"], 0.5, 0.0, 2.5), Vector3(0, 0.35, 0.15))
		for s in [-1.0, 1.0]:
			_mi(b, sph(0.07), pbr("#101010", 0.3), Vector3(0.18 * s, 0.1, 0.43))
		_mi(b, sph(0.12), pbr("#301010", 0.9), Vector3(0, -0.12, 0.45), Vector3.ZERO, Vector3(1.6, 0.6, 0.5))
	rig["head"] = b
	rig["height"] = 1.0
	rig["radius"] = 0.55


static func _insect(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	b.position.y = 0.35
	var shell := pbr(d["col"], 0.25, 0.1)
	_mi(b, sph(0.32), shell, Vector3(0, 0.05, -0.15), Vector3.ZERO, Vector3(1, 0.75, 1.25))
	_mi(b, sph(0.2), c2, Vector3(0, 0, 0.22))
	var head := _pivot(b, Vector3(0, 0.02, 0.4))
	_mi(head, sph(0.16), c2)
	for s in [-1.0, 1.0]:
		_mi(head, sph(0.045), pbr("#101010", 0.1), Vector3(0.1 * s, 0.06, 0.1))
		_mi(head, cone(0.03, 0.2), c2, Vector3(0.07 * s, -0.05, 0.16), Vector3(80, 0, 15 * s))
	rig["head"] = head
	if d.get("fly", 0.0) > 0.0:
		for s in [-1.0, 1.0]:
			var w := _pivot(b, Vector3(0.1 * s, 0.25, 0))
			_mi(w, sph(0.25), pbr("#e0e8ff", 0.1, 0.0, 0.3), Vector3(0.2 * s, 0, -0.05), Vector3.ZERO, Vector3(1.0, 0.05, 0.6))
			rig["wings"].append(w)
	for z in [0.15, -0.05, -0.25]:
		for s in [-1.0, 1.0]:
			var hip := _pivot(b, Vector3(0.15 * s, -0.05, z))
			hip.rotation_degrees.z = 60 * s
			_mi(hip, cyl(0.025, 0.35), c2, Vector3(0, -0.17, 0))
			rig["legs"].append([hip, hip])
	rig["height"] = 0.7
	rig["radius"] = 0.45


static func _cactuar(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	b.position.y = 0.55
	_mi(b, cap(0.22, 0.95), c1, Vector3(0, 0.25, 0))
	for s in [-1.0, 1.0]:
		_mi(b, sph(0.04), pbr("#101010", 0.3), Vector3(0.08 * s, 0.55, 0.19))
		var arm := _pivot(b, Vector3(0.22 * s, 0.25, 0))
		arm.rotation_degrees.z = -80 * s
		_mi(arm, cap(0.07, 0.4), c1, Vector3(0, 0.18, 0))
		rig["parts"]["arm" + ("L" if s < 0 else "R")] = arm
	_mi(b, sph(0.04), pbr("#101010", 0.3), Vector3(0, 0.42, 0.21), Vector3.ZERO, Vector3(1.4, 2.0, 1.0))
	_mi(b, sph(0.08), pbr(d["col2"], 0.6), Vector3(0.08, 0.78, 0))
	rig["head"] = b
	for x in [-0.1, 0.1]:
		rig["legs"].append(_leg(b, Vector3(x, -0.15, 0), 0.45, 0.06, c1))
	rig["height"] = 1.3
	rig["radius"] = 0.35


static func _wyvern(d: Dictionary, rig: Dictionary, c1: Material, c2: Material, eye: Material) -> void:
	var b: Node3D = rig["body"]
	b.position.y = 0.95
	_mi(b, cap(0.35, 1.4), c1, Vector3.ZERO, Vector3(80, 0, 0))
	_mi(b, sph(0.3), c2, Vector3(0, -0.12, 0.2), Vector3.ZERO, Vector3(0.9, 0.7, 1.6))
	var neck := _pivot(b, Vector3(0, 0.3, 0.6))
	_mi(neck, cap(0.14, 0.8), c1, Vector3(0, 0.3, 0.15), Vector3(-30, 0, 0))
	var head := _pivot(neck, Vector3(0, 0.65, 0.35))
	_mi(head, sph(0.2), c1, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.7, 1.6))
	_mi(head, cone(0.12, 0.3), c2, Vector3(0, -0.05, 0.38), Vector3(90, 0, 0))
	for s in [-1.0, 1.0]:
		_mi(head, sph(0.035), pbr("#a0e8ff", 0.1, 0.0, 3.0), Vector3(0.12 * s, 0.07, 0.15))
		_mi(head, cone(0.05, 0.35), pbr("#d0d0c0", 0.4), Vector3(0.1 * s, 0.15, -0.15), Vector3(-130, 0, 0))
		var wing := _pivot(b, Vector3(0.3 * s, 0.25, 0.1))
		var arm := _mi(wing, cap(0.06, 1.5), c1, Vector3(0.7 * s, 0.15, 0), Vector3(0, 0, 80 * s))
		_mi(wing, PrismMesh.new(), pbr(d["col2"], 0.6), Vector3(0.75 * s, 0.05, -0.45), Vector3(90, 0, 0), Vector3(1.5, 0.9, 0.02))
		rig["wings"].append(wing)
		rig["parts"]["wings"] = wing
	rig["head"] = neck
	for x in [-0.25, 0.25]:
		rig["legs"].append(_leg(b, Vector3(x, -0.15, -0.15), 0.9, 0.12, c1, true))
	var tail := _pivot(b, Vector3(0, 0, -0.7))
	var prev := tail
	for i in 5:
		_mi(prev, cap(0.13 * (1.0 - i * 0.16), 0.5), c1, Vector3(0, 0, -0.22), Vector3(90, 0, 0))
		var nx := _pivot(prev, Vector3(0, 0, -0.45)); prev = nx
		rig["tail"].append(nx)
	rig["height"] = 2.0
	rig["radius"] = 1.0


## Merges the rigid mesh children of every pivot into one mesh per material, so a creature
## costs a handful of draw calls instead of dozens. Breakable/glowing parts stay separate.
static func _merge(n: Node3D, rig: Dictionary) -> void:
	var keep := {}
	for p in rig["parts"].values(): keep[p] = true
	for g in rig["glow"]: keep[g] = true
	_merge_node(n, keep)


static func _merge_node(n: Node3D, keep: Dictionary) -> void:
	var groups := {}
	for c in n.get_children():
		if c is MeshInstance3D and not keep.has(c):
			var m: Material = c.material_override
			var k := m.get_instance_id()
			if not groups.has(k): groups[k] = [m, []]
			groups[k][1].append(c)
	for k in groups:
		var list: Array = groups[k][1]
		if list.size() < 2: continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			st.append_from(mi.mesh, 0, mi.transform)
			n.remove_child(mi)
			mi.free()
		st.set_material(groups[k][0])
		var out := MeshInstance3D.new()
		out.mesh = st.commit()
		n.add_child(out)
	for c in n.get_children():
		if c is Node3D and not (c is MeshInstance3D): _merge_node(c, keep)
