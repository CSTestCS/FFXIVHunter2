class_name WeaponBuilder
## Builds weapon meshes from primitives merged into a single ArrayMesh per weapon
## (metal / grip / gem surfaces), cached by type and tier. Weapons are modelled along +Y from the grip.

static var _cache := {}

const TIER_METAL := ["#7d7466", "#b8834a", "#8a8e94", "#c4c8cc", "#b9d6ef", "#5b7fc4", "#3f5a48"]
const GEM := {"cane": "#ffffff", "rod": "#ff6a30", "star_globe": "#b8a0ff", "nouliths": "#80f0ff", "rapier": "#ff4060",
	"grimoire": "#60c0ff", "codex": "#ffd060", "gunblade": "#60a0ff", "scythe": "#d050ff"}


static func build(type: String, tier: int) -> Array:
	var key := "%s_%d" % [type, tier]
	if not _cache.has(key): _cache[key] = _make(type, tier)
	var spec: Array = _cache[key]
	var main := _instance(spec[0], spec[2])
	var off: Node3D = _instance(spec[1], spec[3]) if spec[1] != null else null
	return [main, off]


static func _instance(mesh: Mesh, length: float) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	root.set_meta("length", length)
	return root


static func _mats(type: String, tier: int) -> Array:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(TIER_METAL[clampi(tier, 0, TIER_METAL.size() - 1)])
	metal.metallic = 0.92 if tier > 0 else 0.6
	metal.roughness = 0.55 - tier * 0.05 if tier > 0 else 0.7
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color("#3a2a1e") if tier < 4 else Color("#2a2236")
	grip.roughness = 0.75
	var gem := StandardMaterial3D.new()
	gem.albedo_color = Color(GEM.get(type, "#a0d0ff"))
	gem.emission_enabled = true
	gem.emission = Color(GEM.get(type, "#a0d0ff"))
	gem.emission_energy_multiplier = 1.5 + tier * 0.4
	gem.roughness = 0.1
	return [metal, grip, gem]


class Kit:
	var st: Array = []   # SurfaceTools for metal, grip, gem
	var used := [false, false, false]

	func _init() -> void:
		for i in 3:
			var s := SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); st.append(s)

	func add(mesh: PrimitiveMesh, surf: int, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
		var b := Basis.from_euler(rot * (PI / 180.0)).scaled(scl)
		st[surf].append_from(mesh, 0, Transform3D(b, pos))
		used[surf] = true

	func commit(mats: Array) -> ArrayMesh:
		var am: ArrayMesh = null
		for i in 3:
			if not used[i]: continue
			st[i].set_material(mats[i])
			am = st[i].commit(am)
		return am


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b


static func cyl(r: float, h: float, r2 := -1.0, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r if r2 < 0 else r2; c.bottom_radius = r; c.height = h; c.radial_segments = seg; c.rings = 1; return c


static func sph(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = seg; s.rings = seg / 2; return s


static func prism(x: float, y: float, z: float) -> PrismMesh:
	var p := PrismMesh.new(); p.size = Vector3(x, y, z); return p


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = inner; t.outer_radius = outer; t.rings = 16; t.ring_segments = 6; return t


## Returns [main mesh, offhand mesh or null, main length, offhand length]
static func _make(type: String, tier: int) -> Array:
	var mats := _mats(type, tier)
	var k := Kit.new()
	var o: Kit = null
	var length := 0.8
	var big := 1.0 + tier * 0.04
	match type:
		"sword_shield":
			k.add(cyl(0.017, 0.2), 1, Vector3(0, 0, 0))
			k.add(box(0.2, 0.03, 0.04), 0, Vector3(0, 0.11, 0))
			k.add(box(0.055, 0.7, 0.012), 0, Vector3(0, 0.47, 0))
			k.add(prism(0.055, 0.1, 0.012), 0, Vector3(0, 0.87, 0))
			k.add(sph(0.025), 0, Vector3(0, -0.11, 0))
			o = Kit.new()
			o.add(box(0.42 * big, 0.55 * big, 0.03), 0, Vector3(0, 0.0, 0))
			o.add(prism(0.42 * big, 0.2, 0.03), 0, Vector3(0, -0.37 * big, 0), Vector3(0, 0, 180))
			o.add(box(0.36 * big, 0.48 * big, 0.02), 1, Vector3(0, 0.0, 0.017))
			o.add(sph(0.05), 0, Vector3(0, 0.03, 0.03))
			length = 0.9
		"greataxe":
			k.add(cyl(0.022, 1.1), 1, Vector3(0, 0.35, 0))
			k.add(box(0.07, 0.36 * big, 0.035), 0, Vector3(0.12, 0.8, 0))
			k.add(prism(0.36 * big, 0.2, 0.03), 0, Vector3(0.26, 0.8, 0), Vector3(0, 0, -90))
			k.add(prism(0.28 * big, 0.14, 0.03), 0, Vector3(-0.1, 0.8, 0), Vector3(0, 0, 90))
			k.add(cyl(0.03, 0.08), 0, Vector3(0, 0.95, 0))
			length = 1.0
		"greatsword":
			k.add(cyl(0.02, 0.32), 1, Vector3(0, 0.02, 0))
			k.add(box(0.32, 0.05, 0.06), 0, Vector3(0, 0.2, 0))
			k.add(box(0.13 * big, 1.15, 0.022), 0, Vector3(0, 0.8, 0))
			k.add(prism(0.13 * big, 0.2, 0.022), 0, Vector3(0, 1.47, 0))
			length = 1.5
		"gunblade":
			k.add(cyl(0.018, 0.22), 1, Vector3(0, 0, 0))
			k.add(box(0.1, 0.16, 0.07), 0, Vector3(0.02, 0.17, 0))
			k.add(cyl(0.035, 0.07), 0, Vector3(0.02, 0.17, 0.045), Vector3(90, 0, 0))
			k.add(box(0.07, 0.78, 0.016), 0, Vector3(0, 0.62, 0))
			k.add(prism(0.07, 0.12, 0.016), 0, Vector3(0, 1.07, 0))
			k.add(box(0.012, 0.5, 0.018), 2, Vector3(0, 0.55, 0))
			length = 1.1
		"cane", "rod":
			var h := 1.45 if type == "cane" else 1.25
			k.add(cyl(0.02, h, 0.016), 1, Vector3(0, h * 0.35, 0))
			k.add(torus(0.05, 0.075), 0, Vector3(0, h * 0.85 + 0.04, 0), Vector3(90, 0, 0))
			k.add(sph(0.045), 2, Vector3(0, h * 0.85 + 0.05, 0))
			k.add(cyl(0.03, 0.05), 0, Vector3(0, h * 0.85 - 0.04, 0))
			length = h
		"codex", "grimoire":
			k.add(box(0.2, 0.26, 0.05), 1, Vector3(0, 0.08, 0))
			k.add(box(0.21, 0.27, 0.035), 0, Vector3(0.004, 0.08, 0))
			k.add(sph(0.025), 2, Vector3(0, 0.08, 0.03))
			length = 0.25
		"star_globe":
			k.add(sph(0.09), 2, Vector3(0, 0.12, 0))
			k.add(torus(0.12, 0.135), 0, Vector3(0, 0.12, 0), Vector3(70, 0, 20))
			k.add(torus(0.12, 0.135), 0, Vector3(0, 0.12, 0), Vector3(-20, 30, 0))
			length = 0.3
		"nouliths":
			for i in 4:
				var a := i * 90.0
				k.add(prism(0.07, 0.3, 0.02), 0, Vector3(cos(deg_to_rad(a)) * 0.22, 0.15 + sin(deg_to_rad(a)) * 0.22, 0), Vector3(0, 0, a - 90))
				k.add(sph(0.02), 2, Vector3(cos(deg_to_rad(a)) * 0.22, 0.15 + sin(deg_to_rad(a)) * 0.22, 0.012))
			length = 0.4
		"fists":
			k.add(box(0.1, 0.06, 0.09), 0, Vector3(0, 0.0, 0))
			k.add(prism(0.09, 0.05, 0.08), 0, Vector3(0, 0.05, 0))
			o = Kit.new()
			o.add(box(0.1, 0.06, 0.09), 0, Vector3(0, 0.0, 0))
			o.add(prism(0.09, 0.05, 0.08), 0, Vector3(0, 0.05, 0))
			length = 0.2
		"lance":
			k.add(cyl(0.02, 2.1), 1, Vector3(0, 0.45, 0))
			k.add(prism(0.07, 0.36 * big, 0.025), 0, Vector3(0, 1.65, 0))
			k.add(box(0.18, 0.03, 0.03), 0, Vector3(0, 1.47, 0))
			k.add(cyl(0.03, 0.06), 0, Vector3(0, -0.6, 0))
			length = 1.85
		"daggers":
			k.add(cyl(0.015, 0.12), 1, Vector3(0, 0, 0))
			k.add(box(0.1, 0.02, 0.025), 0, Vector3(0, 0.07, 0))
			k.add(prism(0.035, 0.34, 0.01), 0, Vector3(0, 0.25, 0))
			o = Kit.new()
			o.add(cyl(0.015, 0.12), 1, Vector3(0, 0, 0))
			o.add(box(0.1, 0.02, 0.025), 0, Vector3(0, 0.07, 0))
			o.add(prism(0.035, 0.34, 0.01), 0, Vector3(0, 0.25, 0))
			length = 0.42
		"katana":
			k.add(cyl(0.016, 0.28), 1, Vector3(0, 0, 0))
			k.add(cyl(0.045, 0.012, -1, 12), 0, Vector3(0, 0.15, 0))
			for i in 6:
				k.add(box(0.03, 0.15, 0.008), 0, Vector3(i * i * 0.0012, 0.23 + i * 0.145, 0), Vector3(0, 0, -i * 1.2))
			length = 1.05
		"scythe":
			k.add(cyl(0.02, 1.7), 1, Vector3(0, 0.45, 0))
			for i in 7:
				var ang := -90.0 - i * 9.0
				k.add(box(0.12, 0.06 - i * 0.005, 0.015), 0, Vector3(cos(deg_to_rad(ang + 90)) * 0.06 - i * 0.1, 1.28 - i * i * 0.006, 0), Vector3(0, 0, i * 9.0))
			k.add(box(0.012, 0.3, 0.02), 2, Vector3(0, 1.0, 0))
			length = 1.4
		"bow":
			for i in range(-5, 6):
				var y := i * 0.12
				k.add(box(0.03, 0.13, 0.025), 1, Vector3(-absf(i) * absf(i) * 0.006, y, 0), Vector3(0, 0, i * 4.5))
			k.add(cyl(0.003, 1.3), 0, Vector3(-0.17, 0, 0))
			length = 0.7
		"gun":
			k.add(box(0.05, 0.12, 0.08), 1, Vector3(0, -0.02, 0))
			k.add(box(0.05, 0.2, 0.06), 0, Vector3(0, 0.12, 0))
			k.add(cyl(0.018, 0.7), 0, Vector3(0, 0.55, 0.01))
			k.add(box(0.05, 0.3, 0.07), 1, Vector3(0, -0.25, -0.02))
			k.add(box(0.02, 0.06, 0.02), 2, Vector3(0, 0.3, 0.05))
			length = 0.9
		"chakrams":
			k.add(torus(0.1, 0.13), 0, Vector3(0, 0.05, 0), Vector3(0, 0, 90))
			o = Kit.new()
			o.add(torus(0.1, 0.13), 0, Vector3(0, 0.05, 0), Vector3(0, 0, 90))
			length = 0.15
		"rapier":
			k.add(cyl(0.015, 0.14), 1, Vector3(0, 0, 0))
			k.add(torus(0.04, 0.05), 0, Vector3(0, 0.09, 0))
			k.add(cyl(0.008, 0.9, 0.003), 0, Vector3(0, 0.55, 0))
			o = Kit.new()
			o.add(sph(0.045, 8), 2, Vector3(0, 0.05, 0))
			o.add(torus(0.06, 0.07), 0, Vector3(0, 0.05, 0), Vector3(90, 0, 0))
			length = 1.0
		_:
			k.add(box(0.05, 0.8, 0.02), 0, Vector3(0, 0.4, 0))
	return [k.commit(mats), o.commit(mats) if o != null else null, length, 0.3]


## Hand socket transform. Hand bones run along +/-X in the T-pose with the thumb toward +Z,
## so the weapon's +Y axis is turned to point past the thumb.
static func grip(right: bool, type: String, off := false) -> Transform3D:
	var s := -1.0 if right else 1.0
	if type == "bow" and not off:
		return Transform3D(Basis(), Vector3(0.075, 0, 0.02))
	if type == "sword_shield" and off:
		return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90)) * Basis(Vector3.UP, deg_to_rad(90)), Vector3(-0.05, -0.05, 0.0))
	if type in ["codex", "grimoire", "star_globe"]:
		return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90)), Vector3(0.07 * s, -0.08, 0))
	if type == "chakrams" or type == "rapier" and off:
		return Transform3D(Basis(), Vector3(0.08 * s, 0, 0.02))
	if type == "nouliths":
		return Transform3D(Basis(), Vector3(0.1 * s, 0.15, 0))
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90)), Vector3(0.075 * s, -0.01, 0.0))


## Carry position on the back (upper chest bone space; model front is +Z).
static func sheath(type: String, idx: int) -> Transform3D:
	var back := Vector3(0, 0.02, -0.17)
	match type:
		"sword_shield":
			if idx == 1: return Transform3D(Basis(Vector3.UP, PI), back + Vector3(0, 0, -0.03))
			return Transform3D(Basis(Vector3.BACK, deg_to_rad(160)), back + Vector3(-0.1, 0.25, 0.0))
		"daggers", "fists", "chakrams":
			return Transform3D(Basis(Vector3.BACK, deg_to_rad(180 + (25 if idx == 0 else -25))), Vector3(0.12 if idx == 0 else -0.12, -0.32, -0.1))
		"codex", "grimoire":
			return Transform3D(Basis(Vector3.BACK, deg_to_rad(10)), Vector3(0.18, -0.38, -0.02))
		"star_globe":
			return Transform3D(Basis(), Vector3(0.0, 0.25, -0.25))
		"nouliths":
			return Transform3D(Basis(), Vector3(0.0, -0.1, -0.3))
		"rapier":
			if idx == 1: return Transform3D(Basis(), Vector3(-0.15, -0.35, 0.0))
			return Transform3D(Basis(Vector3.BACK, deg_to_rad(200)), Vector3(0.18, -0.25, -0.05))
		"bow":
			return Transform3D(Basis(Vector3.BACK, deg_to_rad(30)), back)
	return Transform3D(Basis(Vector3.BACK, deg_to_rad(155)), back + Vector3(0.0, 0.2, 0))
