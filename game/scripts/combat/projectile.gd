class_name Projectile
extends Node3D
## Lightweight projectile: moves itself and does distance checks against the opposing team.
## No physics bodies, no lights.

static var _mesh: SphereMesh

var source: Actor
var info := {}           # damage info passed to take_hit
var speed := 30.0
var radius := 0.35
var life := 2.0
var homing := 0.0
var aoe := 0.0
var pierce := false
var returning := false
var color := Color.WHITE
var target: Actor
var dir := Vector3.FORWARD
var _hit := {}
var _origin := Vector3.ZERO
var _back := false


static func spawn(world: Node, src: Actor, from: Vector3, direction: Vector3, p: Dictionary, dmg_info: Dictionary, tgt: Actor = null) -> Projectile:
	if _mesh == null:
		_mesh = SphereMesh.new(); _mesh.radial_segments = 10; _mesh.rings = 5
	var pr := Projectile.new()
	pr.source = src
	pr.info = dmg_info
	pr.speed = p.get("speed", 30.0)
	pr.radius = p.get("radius", 0.35)
	pr.life = p.get("life", 2.2)
	pr.homing = p.get("homing", 0.0)
	pr.aoe = p.get("aoe", 0.0)
	pr.pierce = p.get("pierce", false)
	pr.returning = p.get("return", false)
	pr.color = Color(p.get("color", "#ffffff"))
	pr.target = tgt
	pr.dir = direction.normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.scale = Vector3.ONE * pr.radius * 1.6
	mi.material_override = FX.mat(pr.color, 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pr.add_child(mi)
	var tail := MeshInstance3D.new()
	tail.mesh = _mesh
	tail.scale = Vector3(pr.radius, pr.radius, pr.radius * 4.0)
	tail.position = Vector3(0, 0, pr.radius * 2.5)
	tail.material_override = FX.mat(pr.color, 2.0, 0.5)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pr.add_child(tail)
	world.fx.add_child(pr)
	pr.global_position = from
	pr._origin = from
	pr._face()
	return pr


func _face() -> void:
	if dir.length() > 0.01:
		global_transform.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or source == null or not is_instance_valid(source):
		_finish(); return
	if returning and not _back and global_position.distance_to(_origin) > 14.0:
		_back = true; _hit.clear()
	if _back:
		dir = (source.center() - global_position).normalized()
		if global_position.distance_to(source.center()) < 1.0: queue_free(); return
	elif homing > 0.0 and target and is_instance_valid(target) and not target.dead:
		dir = dir.slerp((target.center() - global_position).normalized(), clampf(homing * delta, 0.0, 1.0)).normalized()
	global_position += dir * speed * delta
	_face()
	var w := source.world
	if w == null: return
	for a in w.actors:
		if a.team == source.team or a.dead or _hit.has(a): continue
		var r: float = radius + a.radius
		var c: Vector3 = a.center()
		if global_position.distance_squared_to(c) < r * r or (Vector2(global_position.x - c.x, global_position.z - c.z).length() < r and absf(global_position.y - c.y) < 1.4 * a.scale.y):
			_impact(a)
			if not pierce and not _back:
				_finish(); return
	if global_position.y < w.ground_height(global_position.x, global_position.z) - 0.2:
		_finish()


func _impact(a: Actor) -> void:
	_hit[a] = true
	var i := info.duplicate()
	i["source"] = source
	a.take_hit(i)
	source.world.fx.burst(global_position, color, 0.8)


func _finish() -> void:
	if aoe > 0.0 and source and is_instance_valid(source) and source.world:
		var w := source.world
		w.fx.nova(global_position, aoe, color, 0.4)
		for a in w.actors:
			if a.team != source.team and not a.dead and not _hit.has(a) and a.global_position.distance_to(global_position) <= aoe + a.radius:
				var i := info.duplicate(); i["source"] = source
				a.take_hit(i)
		Sfx.play_at("boom", global_position, -6.0, 1.3)
	queue_free()
