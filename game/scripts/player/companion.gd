class_name Companion
extends Actor
## Recruited party member. Follows the player, engages their target, fights according to role,
## heals when it is a healer, and steps out of telegraphed attacks.

var model: CharModel
var job := "PLD"
var jd: Dictionary
var role := "tank"
var rid := ""
var target: Actor
var state := "follow"
var t := 0.0
var combo := 0
var atk_t := 0.0
var heal_t := 0.0
var down_t := 0.0
var offset := Vector3.ZERO
var _dodge_to := Vector3.ZERO
var _dodging := 0.0


func setup(rec: Dictionary, w: Node, idx: int) -> void:
	world = w
	rid = rec["id"]
	job = rec["job"]
	jd = Data.jobs[job]
	role = jd["role"]
	display_name = rec["name"]
	team = 0
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.7
	cs.shape = cap; cs.position.y = 0.85
	add_child(cs)
	model = CharModel.new()
	add_child(model)
	var ap := RaceData.default_appearance(rec["race"], rec["clan"], rec["sex"])
	ap["hair_color"] = rec["hair"]
	ap["hair_style"] = 1 + idx % 2
	ap["skin"] = RaceData.CLANS[rec["clan"]]["skin"][idx % 2]
	var tier := clampi(int(Game.level() / 8), 1, 5)
	model.build(ap, {"armor": {"body": tier, "legs": tier, "feet": tier}, "weapon": jd["weapon"], "tier": tier})
	model.set_drawn(false)
	offset = [Vector3(-2.2, 0, 1.6), Vector3(2.2, 0, 1.6), Vector3(0, 0, 3.0)][idx % 3]
	level = maxi(int(rec["level"]), Game.level())
	max_hp = (600.0 + level * 110.0) * float(jd["hp_mult"])
	hp = max_hp
	atk = (22.0 + level * 6.0 + tier * 18.0) * 0.85
	defense = tier * 14.0


func _physics_process(delta: float) -> void:
	tick_status(delta)
	t += delta
	atk_t -= delta
	heal_t -= delta
	_dodging -= delta
	if dead:
		down_t += delta
		velocity = Vector3.ZERO
		model.play("lie")
		if down_t > 14.0:
			dead = false; hp = max_hp * 0.4; down_t = 0.0; invuln = 2.0
			world.toast_small("%s is back on their feet!" % display_name)
		return
	if not is_on_floor(): velocity.y -= gravity * delta
	var p: Player = world.player
	if p == null: return
	var wl: float = world.water_level(global_position.x, global_position.z)
	var swim := wl - global_position.y > 1.1
	# danger avoidance
	if _dodging <= 0.0:
		for dz in world.dangers:
			if FX.inside(dz["shape"], dz["origin"], dz["dir"], dz["p"], global_position, radius + 0.6):
				var away: Vector3 = (global_position - dz["origin"])
				away.y = 0
				if away.length() < 0.5: away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
				var dist: float = float(dz["p"].get("radius", dz["p"].get("width", 4.0))) + 2.0
				if dz["shape"] == "line": away = Vector3(dz["dir"].z, 0, -dz["dir"].x) * (1.0 if randf() < 0.5 else -1.0); dist = float(dz["p"]["width"]) + 1.5
				if dz["shape"] == "donut": away = -away; dist = 1.0
				_dodge_to = global_position + away.normalized() * dist
				_dodging = 1.0
				break
	if _dodging > 0.0:
		_move_to(_dodge_to, 8.0, delta)
		model.play("run")
		move_and_slide()
		return
	# target selection
	if target == null or target.dead or not is_instance_valid(target):
		target = null
		var pt = p.lock_target if p.lock_target and is_instance_valid(p.lock_target) and not p.lock_target.dead else null
		if pt: target = pt
		else:
			var best := 22.0
			for a in world.actors:
				if a.team == team or a.dead: continue
				if a is Monster and (a.state == "idle" or a.state == "return"): continue
				var d = a.global_position.distance_to(p.global_position)
				if d < best: best = d; target = a
	# healing
	if role == "healer" and heal_t <= 0.0:
		for m in world.party_members():
			if not m.dead and m.hp / m.max_hp < 0.6 and m.global_position.distance_to(global_position) < 25.0:
				m.heal(m.max_hp * 0.22)
				world.fx.burst(m.center(), Color(0.6, 1.0, 0.7), 1.2, 0.4)
				model.replay("heal", 0.08, 1.2)
				heal_t = 4.5
				velocity.x = 0; velocity.z = 0
				move_and_slide()
				return
	if target == null or swim:
		var goal := p.global_position + Basis(Vector3.UP, p.rotation.y) * offset
		var dd := global_position.distance_to(goal)
		if dd > 40.0:
			global_position = goal + Vector3(0, 1.0, 0)
		if dd > 1.2: _move_to(goal, 6.2 if dd > 5.0 else 4.0, delta)
		else:
			velocity.x = 0; velocity.z = 0
			_face(p.facing(), delta)
		var hs := Vector2(velocity.x, velocity.z).length()
		if swim: model.play("swim" if hs > 0.5 else "swim_idle")
		else: model.play("run" if hs > 4.5 else ("walk" if hs > 0.3 else "idle"))
		if t > 10.0: model.set_drawn(false)
		move_and_slide()
		return
	model.set_drawn(true)
	t = 0.0
	var ranged := role in ["ranged", "caster", "healer"]
	var want := 12.0 if ranged else target.radius + 1.6
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	if dist > want + 0.5:
		var pos := target.global_position - to.normalized() * want
		if role == "melee": pos += Vector3(-to.z, 0, to.x).normalized() * 1.5
		_move_to(pos, 6.0, delta)
		model.play("run")
	else:
		velocity.x = 0; velocity.z = 0
		_face(to, delta)
		if atk_t <= 0.0: _attack(ranged)
		elif not model.anim.is_playing() or model.current_anim in ["run", "walk", "idle"]: model.play("idle_combat")
	move_and_slide()


func _move_to(p: Vector3, spd: float, delta: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.3: velocity.x = 0; velocity.z = 0; return
	d = d.normalized()
	velocity.x = d.x * spd; velocity.z = d.z * spd
	_face(d, delta)


func _face(d: Vector3, delta: float) -> void:
	if d.length() < 0.01: return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(10.0 * delta, 0.0, 1.0))


func _attack(ranged: bool) -> void:
	var keys := ["L1", "L2", "L3"]
	var mv: Dictionary = jd["moves"].get(keys[combo % 3], jd["moves"]["L1"])
	if combo % 5 == 4 and jd["moves"].has("H"): mv = jd["moves"]["H"]
	combo += 1
	atk_t = maxf(float(mv["dur"]) * 1.25, 0.55)
	model.replay(mv["anim"], 0.06, 1.0 / float(mv["dur"]))
	var pot: float = float(mv.get("potency", 1.0))
	var r := roll_damage(pot)
	if mv.has("proj"):
		var p: Dictionary = mv["proj"].duplicate(); p["homing"] = 4.0
		var from := center() + facing() * 0.6
		Projectile.spawn(world, self, from, (target.center() - from).normalized(), p, {"amount": r["amount"], "crit": r["crit"]}, target)
	else:
		var tgt := target
		get_tree().create_timer(float(mv["dur"]) * 0.4).timeout.connect(func():
			if is_instance_valid(tgt) and not tgt.dead and is_instance_valid(self) and tgt.global_position.distance_to(global_position) < tgt.radius + 3.2:
				tgt.take_hit({"amount": r["amount"], "crit": r["crit"], "source": self})
				world.fx.slash(center() + facing() * 0.3, facing(), Color("#e8f0ff"), 2.4, 140.0)
				Sfx.play_at("hit", tgt.center(), -4.0))


func knockback(dir: Vector3, force: float, heavy: bool) -> void:
	velocity += dir * force * 0.6
	if heavy: model.replay("knockdown", 0.05)


func _on_death() -> void:
	down_t = 0.0
	model.play("death", 0.1)
	world.toast_small("%s has been knocked out!" % display_name)
