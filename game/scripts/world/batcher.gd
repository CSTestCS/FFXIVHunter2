class_name Batcher
## Merges many primitive meshes into one ArrayMesh per material, so a whole city or camp
## renders in a handful of draw calls. Optional box colliders are gathered into one body.

var _st := {}       # key -> SurfaceTool
var _mats := {}     # key -> Material
var _shapes := []   # [Shape3D, Transform3D]
var _shadow := {}


func add(mesh: Mesh, xf: Transform3D, mat_key: String, mat: Material, shadow := true) -> void:
	if not _st.has(mat_key):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[mat_key] = s
		_mats[mat_key] = mat
		_shadow[mat_key] = shadow
	_st[mat_key].append_from(mesh, 0, xf)


func box(pos: Vector3, size: Vector3, key: String, mat: Material, collide := true, rot_y := 0.0) -> void:
	var b := BoxMesh.new(); b.size = size
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	add(b, xf, key, mat)
	if collide:
		var sh := BoxShape3D.new(); sh.size = size
		_shapes.append([sh, xf])


func cyl(pos: Vector3, r: float, h: float, key: String, mat: Material, collide := true, r2 := -1.0, seg := 12) -> void:
	var c := CylinderMesh.new(); c.bottom_radius = r; c.top_radius = r if r2 < 0 else r2; c.height = h; c.radial_segments = seg; c.rings = 1
	add(c, Transform3D(Basis(), pos), key, mat)
	if collide:
		var sh := CylinderShape3D.new(); sh.radius = maxf(r, r2 if r2 > 0 else r); sh.height = h
		_shapes.append([sh, Transform3D(Basis(), pos)])


func collider(shape: Shape3D, xf: Transform3D) -> void:
	_shapes.append([shape, xf])


func commit(parent: Node3D, vis_range := 0.0) -> void:
	for k in _st:
		var s: SurfaceTool = _st[k]
		s.set_material(_mats[k])
		var mesh := s.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "Batch_" + k
		if not _shadow[k]: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_range > 0.0: mi.visibility_range_end = vis_range
		parent.add_child(mi)
	if not _shapes.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		parent.add_child(body)
		for s in _shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[0]
			cs.transform = s[1]
			body.add_child(cs)
	_st.clear(); _shapes.clear()
