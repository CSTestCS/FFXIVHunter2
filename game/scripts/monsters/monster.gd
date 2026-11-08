class_name Monster
extends Actor
## Monster AI. Each attack is telegraphed (wind-up pose + ground marker) and then lands hard.
## Large monsters enrage at half health, can have parts broken, topple when staggered,
## and can be carved after they fall.

var id := ""
var d: Dictionary
var rig: Dictionary
var model: CharModel           # humanoid enemies use a VRoid body
var state := "idle"
var state_t := 0.0
var home := Vector3.ZERO
var wander_to := Vector3.ZERO
var target: Actor
var threat := {}
var cds := {}
var atk_now: Dictionary = {}
var atk_origin := Vector3.ZERO
var atk_dir := Vector3.FORWARD
var atk_points: Array = []
var atk_hits_done := 0
var enraged := false
var large := false
var part_hp := 0.0
var part_broken := false
var carves := 0
var speed := 4.0
var anim_t := 0.0
var lod_far := false
var mission_tag := ""
var aggressive := true
var leash := 55.0
var _base_y := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _tele: Array = []


func setup(species: String, lvl: int, w: Node) -> void:
	id = species
	world = w
	d = Data.monsters[species]
	large = d.get("large", false)
	display_name = d["name"]
	level = maxi(lvl, 1)
	team = 1
	var ls := 1.0 + 0.2 * (level - 1)
	max_hp = float(d["hp"]) * ls * (1.0 if large else 1.0)
	hp = max_hp
	atk = float(d["atk"]) * (1.0 + 0.13 * (level - 1)) * (8.5 if large else 5.0)
	defense = 20.0 * float(d.get("defense", 0.0)) * 4.0
	speed = float(d.get("speed", 4.0))
	stagger_max = 260.0 if large else 60.0
	part_hp = max_hp * 0.16
	collision_layer = 4
	collision_mask = 1
	if d["body"] == "humanoid":
		model = CharModel.new()
		add_child(model)
		var races := ["hyur", "hyur", "roegadyn", "elezen", "miqote"]
		var r: String = races[randi() % races.size()]
		var ap := RaceData.default_appearance(r, RaceData.RACES[r]["clans"][randi() % 2], "m" if randf() < 0.75 else "f")
		ap["hair_style"] = randi() % 3
		ap["hair_color"] = RaceData.HAIR_COLORS[randi() % 8]
		ap["skin"] = RaceData.CLANS[ap["clan"]]["skin"][randi() % 3]
		var wpn = d["weapon"] if d.has("weapon") else "bow" if d.get("ranged", false) else ("greataxe" if large else ["sword_shield", "daggers", "greatsword"][randi() % 3])
		model.build(ap, {"armor": {"body": 1, "legs": 1, "feet": 1, "head": 1 if randf() < 0.5 else -1}, "dyes": {"body": d["col"], "legs": d["col2"], "head": d["col2"]}, "weapon": wpn, "tier": 1 if large else 0})
		model.set_drawn(true)
		model.play("idle_combat")
		if large: model.scale *= float(d.get("size", 1.0))
		radius = 0.45 * float(d.get("size", 1.0))
		_add_collider(0.4, 1.7 * float(d.get("size", 1.0)))
	else:
		rig = MonsterBuilder.build(d)
		add_child(rig["root"])
		rig["root"].rotation.y = PI
		radius = rig["radius"]
		_add_collider(rig["radius"] * 0.7, maxf(rig["height"], rig["radius"] * 1.5))
		_base_y = rig["body"].position.y
	home = global_position
	wander_to = home
	aggressive = large or randf() < 0.75


func _add_collider(r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(r, 0.2)
	shape.height = maxf(h, shape.radius * 2.0 + 0.01)
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)


func center() -> Vector3:
	if rig.is_empty(): return global_position + Vector3(0, 1.0 * (model.scale.y if model else 1.0), 0)
	return global_position + Vector3(0, rig["height"] * 0.55, 0)


func _physics_process(delta: float) -> void:
	if lod_far: return
	tick_status(delta)
	state_t += delta
	for k in cds.keys(): cds[k] = float(cds[k]) - delta
	if dead:
		_dead_tick(delta); return
	if not is_on_floor() and d.get("fly", 0.0) <= 0.0:
		velocity.y -= gravity * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	var spd := speed * (0.55 if slow > 0.0 else 1.0) * (1.2 if enraged else 1.0)
	match state:
		"idle": _idle(delta, spd)
		"chase": _chase(delta, spd)
		"wind": _wind(delta)
		"act": _act(delta)
		"recover":
			_brake(delta)
			if state_t > (0.9 if large else 0.7) * (0.8 if enraged else 1.0): _set_state("chase")
		"topple":
			_brake(delta)
			if state_t > 3.2: _set_state("chase")
		"return":
			_move_to(home, spd, delta)
			heal(max_hp * 0.2 * delta, false)
			if global_position.distance_to(home) < 3.0: _set_state("idle")
	if stagger >= stagger_max and state != "topple":
		stagger = 0.0
		_clear_tele()
		_set_state("topple")
		if world: world.fx.shake(0.4); world.toast_small("%s is staggered!" % display_name)
	move_and_slide()
	if d.get("fly", 0.0) > 0.0 and state != "act":
		var gy: float = world.ground_height(global_position.x, global_position.z) + float(d["fly"])
		global_position.y = lerpf(global_position.y, gy, delta * 3.0)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)


func _face_to(p: Vector3, delta: float, rate := 6.0) -> void:
	var dir := p - global_position
	dir.y = 0
	if dir.length() < 0.05: return
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(rate * delta, 0.0, 1.0))


func _move_to(p: Vector3, spd: float, delta: float) -> void:
	var dir := p - global_position
	dir.y = 0
	if dir.length() < 0.3:
		_brake(delta); return
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face_to(p, delta, 5.0)


func _pick_target() -> Actor:
	var best: Actor = null
	var best_score := -1.0
	for a in world.actors:
		if a.team == team or a.dead: continue
		var dist = a.global_position.distance_to(global_position)
		if dist > 45.0: continue
		var score: float = float(threat.get(a.get_instance_id(), 0.0)) + 200.0 / (1.0 + dist)
		if score > best_score: best_score = score; best = a
	return best


func _idle(delta: float, spd: float) -> void:
	if state_t > 3.0 and randf() < 0.01:
		var a := randf() * TAU
		wander_to = home + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 10.0)
		state_t = 0.0
	_move_to(wander_to, spd * 0.35, delta)
	var p: Actor = world.player
	if p and not p.dead and aggressive:
		var aggro := 24.0 if large else 11.0
		if p.global_position.distance_to(global_position) < aggro:
			target = p
			if large: world.on_boss_engaged(self)
			_set_state("chase")


func _chase(delta: float, spd: float) -> void:
	target = _pick_target()
	if target == null:
		_set_state("return" if not large else "idle"); return
	if global_position.distance_to(home) > leash and not large and mission_tag == "":
		target = null; _set_state("return"); return
	var dist := global_position.distance_to(target.global_position)
	var choice := _choose_attack(dist)
	if not choice.is_empty():
		atk_now = choice
		_begin_attack()
		return
	var keep: float = 9.0 if d.get("ranged", false) else 1.5 + radius
	if dist > keep:
		_move_to(target.global_position, spd, delta)
	else:
		_brake(delta)
		_face_to(target.global_position, delta)


func _choose_attack(dist: float) -> Dictionary:
	if stun > 0.0 or state_t < (0.35 if large else 0.8): return {}
	var opts := []
	var total := 0.0
	for atk_d in d["attacks"]:
		if int(atk_d["phase"]) == 1 and not enraged: continue
		if float(cds.get(atk_d["name"], 0.0)) > 0.0: continue
		var reach: float = float(atk_d["range"]) + radius
		var shape: String = atk_d["shape"]
		var ok := false
		if shape in ["proj", "charge", "leap", "line"] or atk_d.get("target", false): ok = dist <= reach + 2.0 and dist > 1.0
		else: ok = dist <= reach * 0.85 + 0.5
		if atk_d.get("self", false) and shape == "circle": ok = dist <= reach
		if ok:
			opts.append(atk_d); total += float(atk_d["weight"])
	if opts.is_empty(): return {}
	var r := randf() * total
	for o in opts:
		r -= float(o["weight"])
		if r <= 0.0: return o
	return opts[0]


func _wind_time() -> float:
	return float(atk_now["wind"]) * (0.82 if enraged else 1.0)


func _begin_attack() -> void:
	_set_state("wind")
	_brake(1.0)
	var to_t := target.global_position - global_position
	to_t.y = 0
	atk_dir = to_t.normalized() if to_t.length() > 0.01 else facing()
	rotation.y = atan2(-atk_dir.x, -atk_dir.z)
	atk_origin = global_position
	atk_points.clear()
	atk_hits_done = 0
	var a := atk_now
	var t := _wind_time()
	var shape: String = a["shape"]
	var col := Color(1.0, 0.42, 0.12) if not large else Color(1.0, 0.25, 0.1)
	match shape:
		"circle":
			var n := int(a.get("count", 1))
			if a.get("self", false):
				atk_points = [global_position]
			else:
				for i in n:
					var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(3.0, 7.0)
					var tp := target.global_position + off
					tp.y = world.ground_height(tp.x, tp.z)
					atk_points.append(tp)
			for p in atk_points:
				_tele.append(world.fx.telegraph("circle", p, atk_dir, {"radius": a["range"] if a.get("self", false) else a["range"]}, t, col))
		"cone", "combo":
			var dir := -atk_dir if a.get("behind", false) else atk_dir
			_tele.append(world.fx.telegraph("cone", global_position, dir, {"radius": float(a["range"]) + radius, "arc": a.get("arc", 100.0 if shape == "combo" else 90.0)}, t, col))
		"line", "charge":
			_tele.append(world.fx.telegraph("line", global_position, atk_dir, {"width": a.get("width", 2.0) + radius, "length": float(a["range"]) + radius}, t, col))
		"donut":
			_tele.append(world.fx.telegraph("donut", global_position, atk_dir, {"radius": a["range"], "inner": float(a.get("inner", 4.0)) / float(a["range"])}, t, col))
		"leap":
			var tp := target.global_position
			tp.y = world.ground_height(tp.x, tp.z)
			_leap_from = global_position; _leap_to = tp
			_tele.append(world.fx.telegraph("circle", tp, atk_dir, {"radius": a.get("range_aoe", 3.0)}, t, col))
		"proj":
			pass
	if large and t >= 1.4:
		Sfx.play_at("roar", global_position, -2.0, 0.8 if large else 1.4)
	if model: model.play({"combo": "slash_r", "cone": "slash_down", "charge": "dash", "leap": "leap", "proj": "shoot_bow", "circle": "roar"}.get(shape, "roar"), 0.1)


func _wind(delta: float) -> void:
	_brake(delta)
	if atk_now["shape"] == "proj" and target: _face_to(target.global_position, delta, 8.0)
	if stun > 0.0: _clear_tele(); _set_state("recover"); return
	if state_t >= _wind_time():
		_set_state("act")
		_on_act_start()


func _on_act_start() -> void:
	var a := atk_now
	cds[a["name"]] = float(a["cd"]) * (0.7 if enraged else 1.0) + randf_range(0.0, 1.5)
	var shape: String = a["shape"]
	Sfx.play_at("heavy" if large else "swing", global_position, 0.0, 0.7 if large else 1.0)
	match shape:
		"circle", "cone", "donut", "line":
			_resolve_hits()
		"proj":
			if target:
				var from := center() + facing() * radius
				var p := {"speed": 22.0, "radius": 0.4, "color": a.get("color", "#ffffff"), "aoe": a.get("aoe", 0.0), "life": 2.5, "homing": 1.5}
				Projectile.spawn(world, self, from, (target.center() - from).normalized(), p, _dmg_info(a), target)
		"charge":
			velocity = atk_dir * speed * 3.2
		"leap":
			pass
		"combo":
			_resolve_hits()
			atk_hits_done = 1
	if model:
		model.play({"combo": "slash_l", "cone": "slash_down", "charge": "dash", "leap": "heavy_down", "proj": "shoot_bow", "circle": "slam"}.get(shape, "slam"), 0.05, 2.0)


func _act(delta: float) -> void:
	var a := atk_now
	var shape: String = a["shape"]
	var dur := 0.35
	match shape:
		"charge":
			dur = float(a["range"]) / (speed * 3.2)
			velocity.x = atk_dir.x * speed * 3.2; velocity.z = atk_dir.z * speed * 3.2
			_charge_hits(a)
		"leap":
			dur = 0.55
			var k := clampf(state_t / dur, 0.0, 1.0)
			var p := _leap_from.lerp(_leap_to, k)
			p.y += sin(k * PI) * (3.0 + radius * 2.0)
			global_position = p
			velocity = Vector3.ZERO
			if k >= 1.0 and atk_hits_done == 0:
				atk_hits_done = 1
				atk_points = [_leap_to]
				_resolve_hits({"shape": "circle", "radius": a.get("range_aoe", 3.0)})
				world.fx.nova(_leap_to, float(a.get("range_aoe", 3.0)), Color(1, 0.8, 0.6))
				world.fx.shake(0.5 if large else 0.2)
		"combo":
			var n := int(a.get("hits", 3))
			dur = 0.32 * n
			_brake(delta)
			if atk_hits_done < n and state_t >= atk_hits_done * 0.32:
				if target: atk_dir = atk_dir.slerp((target.global_position - global_position).normalized() * Vector3(1, 0, 1), 0.5).normalized()
				rotation.y = atan2(-atk_dir.x, -atk_dir.z)
				global_position += atk_dir * 0.6
				_resolve_hits()
				atk_hits_done += 1
				Sfx.play_at("swing", global_position, -2.0, 0.8)
				if model: model.replay("slash_r" if atk_hits_done % 2 == 0 else "slash_l", 0.05, 2.5)
		_:
			_brake(delta)
	if state_t >= dur:
		_clear_tele()
		if a.get("suicide", false):
			hp = 0.0; dead = true; _on_death()
			return
		if a.get("blink", false) and target:
			global_position = target.global_position - target.facing() * 4.0
		_set_state("recover")
		if model: model.play("idle_combat", 0.2)


func _dmg_info(a: Dictionary) -> Dictionary:
	var info := {"amount": atk * float(a["dmg"]) * randf_range(0.92, 1.08), "source": self, "elem": a.get("elem", ""),
		"knock": float(a.get("knock", 4.0)) * (1.5 if large else 0.6), "heavy": large or float(a["dmg"]) >= 1.6,
		"dot": 0.3 if a.get("poison", false) else 0.0}
	if a.has("slow"): info["slow"] = true
	return info


func _resolve_hits(override := {}) -> void:
	var a := atk_now
	var shape: String = override.get("shape", a["shape"])
	var info := _dmg_info(a)
	if a.get("count", 1) > 1 or a.get("target", false) or not atk_points.is_empty() and shape == "circle":
		for p in atk_points:
			world.fx.burst(p + Vector3(0, 0.5, 0), Color(1, 0.6, 0.3), float(override.get("radius", a["range"])) * 0.8, 0.3)
	for t in world.actors:
		if t.team == team or t.dead: continue
		var hit := false
		match shape:
			"circle":
				var pts := atk_points if not atk_points.is_empty() else [global_position]
				for p in pts:
					if FX.inside("circle", p, atk_dir, {"radius": override.get("radius", a["range"])}, t.global_position, t.radius): hit = true
			"cone", "combo":
				var dir := -atk_dir if a.get("behind", false) else atk_dir
				hit = FX.inside("cone", global_position, dir, {"radius": float(a["range"]) + radius, "arc": a.get("arc", 100.0)}, t.global_position, t.radius)
			"line":
				hit = FX.inside("line", atk_origin, atk_dir, {"width": a.get("width", 2.0) + radius, "length": float(a["range"]) + radius}, t.global_position, t.radius)
			"donut":
				hit = FX.inside("donut", global_position, atk_dir, {"radius": a["range"], "inner": float(a.get("inner", 4.0)) / float(a["range"])}, t.global_position, t.radius)
		if hit:
			if a.get("los", false) and t.has_method("is_behind_cover") and t.is_behind_cover(global_position): continue
			var r = t.take_hit(info)
			if not r.get("miss", false) and t.has_method("knockback") and not r.get("guarded", false):
				t.knockback((t.global_position - global_position).normalized(), float(info["knock"]), bool(info["heavy"]))
	if shape in ["circle", "donut"] and (a.get("self", false) or shape == "donut"):
		world.fx.nova(global_position, float(a["range"]), Color(1, 0.7, 0.4))
		world.fx.shake(0.45 if large else 0.15)


var _charged := {}
func _charge_hits(a: Dictionary) -> void:
	if state_t < 0.02: _charged.clear()
	for t in world.actors:
		if t.team == team or t.dead or _charged.has(t): continue
		if t.global_position.distance_to(global_position) < radius + t.radius + 0.8:
			_charged[t] = true
			var r = t.take_hit(_dmg_info(a))
			if not r.get("miss", false) and t.has_method("knockback") and not r.get("guarded", false):
				t.knockback(atk_dir, float(a.get("knock", 4.0)) * 1.6, true)


func _clear_tele() -> void:
	for t in _tele:
		if is_instance_valid(t): t.queue_free()
	_tele.clear()


## Damage taken from the player side: threat, enrage, part breaks, flinches.
func take_hit(info: Dictionary) -> Dictionary:
	var src = info.get("source")
	var was := hp
	var r := super.take_hit(info)
	if r.get("miss", false): return r
	if src and is_instance_valid(src):
		var mult := 3.0 if src.get("role") == "tank" else 1.0
		threat[src.get_instance_id()] = float(threat.get(src.get_instance_id(), 0.0)) + float(r["dealt"]) * mult
		if state == "idle" or state == "return":
			target = src; _set_state("chase")
			if large: world.on_boss_engaged(self)
	if large and not enraged and hp < max_hp * 0.5 and not dead:
		enraged = true
		_clear_tele()
		_set_state("recover")
		world.fx.nova(global_position, 6.0, Color(1, 0.2, 0.1))
		world.fx.shake(0.6)
		world.toast_small("%s is enraged!" % display_name)
		Sfx.play_at("roar", global_position, 2.0, 0.7)
		for g in rig.get("glow", []): g.material_override = MonsterBuilder.pbr("#ff3010", 0.3, 0.0, 3.0)
	if large and not part_broken and d.has("break") and src and is_instance_valid(src):
		var to_src: Vector3 = (src.global_position - global_position).normalized()
		if facing().dot(to_src) > 0.3:
			part_hp -= float(r["dealt"])
			if part_hp <= 0.0: _break_part()
	if not large and state in ["idle", "chase", "recover"] and float(r["dealt"]) > max_hp * 0.25:
		state_t = 0.0
	return r


func _break_part() -> void:
	part_broken = true
	var pname: String = d["break"]["part"]
	var part = rig.get("parts", {}).get(pname)
	if part and is_instance_valid(part):
		var tw = part.create_tween()
		tw.tween_property(part, "scale", part.scale * 0.35, 0.3)
	stagger = stagger_max
	world.toast_small("Broke the %s's %s!" % [display_name, pname])
	world.fx.burst(center(), Color(1, 1, 0.8), 2.5)
	Game.add_item(d["break"]["drop"], 1)


func _on_death() -> void:
	_clear_tele()
	velocity = Vector3.ZERO
	state_t = 0.0
	carves = 3 if large else 0
	collision_layer = 0
	if model: model.play("death", 0.1)
	if world: world.on_monster_killed(self)


func _dead_tick(delta: float) -> void:
	velocity.x = 0; velocity.z = 0
	if not is_on_floor(): velocity.y -= gravity * delta
	move_and_slide()
	var keep := 90.0 if large and carves > 0 else 4.0
	if state_t > keep:
		queue_free()


func carve() -> String:
	if carves <= 0: return ""
	carves -= 1
	var drops: Dictionary = d["drops"]
	var keys := drops.keys()
	var k: String = keys[randi() % keys.size()]
	Game.add_item(k, 1)
	return Data.item_name(k)


# ------------------------------------------------------------------ procedural animation
func _process(delta: float) -> void:
	if lod_far or rig.is_empty():
		if model and not lod_far: _humanoid_anim()
		return
	anim_t += delta
	var b: Node3D = rig["body"]
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var gait := clampf(hspeed / maxf(speed, 0.1), 0.0, 2.5)
	var freq := 6.0 + gait * 5.0
	var i := 0
	for leg in rig["legs"]:
		var ph := anim_t * freq + (PI if i % 2 == 1 else 0.0) + (PI * 0.5 if i >= 2 else 0.0)
		leg[0].rotation.x = sin(ph) * 0.55 * gait
		if leg[1] != leg[0]: leg[1].rotation.x = maxf(0.0, -sin(ph)) * 0.6 * gait
		i += 1
	for w in rig["wings"]:
		var side := 1.0 if w.position.x > 0 else -1.0
		w.rotation.z = sin(anim_t * (12.0 if d.get("fly", 0.0) > 0.0 else 3.0)) * (0.6 if d.get("fly", 0.0) > 0.0 else 0.1) * side
	var k := 0
	for t in rig["tail"]:
		t.rotation.y = sin(anim_t * 2.0 + k * 0.7) * 0.18
		k += 1
	b.position.y = _base_y + absf(sin(anim_t * freq)) * 0.04 * gait
	b.rotation = Vector3.ZERO
	b.scale = Vector3.ONE
	var head: Node3D = rig["head"]
	if head and head != b: head.rotation = Vector3.ZERO
	if dead:
		var k2 := clampf(state_t / 0.8, 0.0, 1.0)
		b.rotation.z = k2 * 1.45
		b.position.y = _base_y * (1.0 - k2 * 0.6)
		return
	if state == "topple":
		b.rotation.z = 1.2 * minf(state_t * 4.0, 1.0); b.position.y = _base_y * 0.55
		return
	if state != "wind" and state != "act": return
	var wt := _wind_time()
	var p := clampf(state_t / maxf(wt, 0.01), 0.0, 1.0) if state == "wind" else clampf(state_t / 0.3, 0.0, 1.0)
	var an: String = atk_now.get("anim", "swipe")
	match an:
		"swipe", "bite":
			if head and head != b:
				head.rotation.x = (-0.5 * p) if state == "wind" else (0.6 * (1.0 - p))
			b.position.z = (-0.15 * p) if state == "wind" else 0.3 * (1.0 - p)
		"slam":
			b.position.y = _base_y + (0.5 * p if state == "wind" else 0.5 * (1.0 - minf(p * 3.0, 1.0)))
			b.rotation.x = -0.3 * p if state == "wind" else 0.2
		"spin":
			b.rotation.y = (-0.4 * p) if state == "wind" else p * TAU
		"roar", "swell":
			if head and head != b: head.rotation.x = -0.6 * p
			var sh := sin(anim_t * 40.0) * 0.02 * p
			b.position.x = sh
			if an == "swell": b.scale = Vector3.ONE * (1.0 + p * 0.5)
		"charge":
			b.rotation.x = 0.25 * p
		"spit":
			if head and head != b: head.rotation.x = (-0.3 * p) if state == "wind" else 0.4 * (1.0 - p)
		"leap":
			b.position.y = _base_y - 0.2 * p if state == "wind" else _base_y


func _humanoid_anim() -> void:
	if dead or state in ["wind", "act"]: return
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if state == "topple": model.play("knockdown"); return
	model.play("run" if hspeed > 2.5 else ("walk_combat" if hspeed > 0.3 else "idle_combat"))
