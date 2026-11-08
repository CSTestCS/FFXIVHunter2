class_name MissionRunner
extends Node
## Runs the objective of a departed quest or guildleve: small hunts, large hunts, gathering,
## defending a camp from waves, and escorting a traveller. Three faints fail the mission.

var world: Node
var q: Dictionary
var kind := ""
var counts := {}
var need := {}
var failed := false
var done := false
var faints := 0
var boss: Monster
var objective: Actor
var wave := 0
var wave_mobs: Array = []
var gathered := 0
var nodes: Array = []
var escort_path: Array = []
var _ambush := [false, false]
var _t := 0.0
var _return_t := -1.0


class Barricade extends Actor:
	var mi: MeshInstance3D
	func _ready() -> void:
		team = 0
		display_name = "Camp Barricade"
		radius = 2.4
		collision_layer = 1
		var bt := Batcher.new()
		var wood := Props.pbr("#6a4c30", 0.85)
		for i in 7:
			bt.box(Vector3(i * 1.0 - 3.0, 1.0, 0), Vector3(0.35, 2.0 + (i % 2) * 0.4, 0.35), "wood", wood)
		bt.box(Vector3(0, 1.3, 0.1), Vector3(7.2, 0.3, 0.3), "wood", wood)
		bt.box(Vector3(0, 0.6, 0.1), Vector3(7.2, 0.3, 0.3), "wood", wood)
		bt.commit(self)
	func center() -> Vector3:
		return global_position + Vector3(0, 1.0, 0)
	func _physics_process(delta: float) -> void:
		tick_status(delta)


class Escortee extends Actor:
	var model: CharModel
	var path: Array = []
	var idx := 0
	var arrived := false
	func setup(w: Node, label: String) -> void:
		world = w
		team = 0
		display_name = label
		max_hp = 1800.0 + Game.level() * 160.0
		hp = max_hp
		defense = 30.0
		collision_layer = 2
		collision_mask = 1
		var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
		cs.shape = cap; cs.position.y = 0.85; add_child(cs)
		model = CharModel.new(); add_child(model)
		model.build(NPC.random_look(hash(label)), {"armor": {"body": 0, "legs": 0, "feet": 0}})
		var cart := Batcher.new()
		cart.box(Vector3(0, 0.9, 1.8), Vector3(1.6, 0.8, 2.2), "cart", Props.pbr("#7a5a38", 0.85), false)
		cart.cyl(Vector3(0.85, 0.45, 1.8), 0.45, 0.15, "wheel", Props.pbr("#3a2a1a", 0.9), false)
		cart.commit(self)
	func _physics_process(delta: float) -> void:
		tick_status(delta)
		if dead or arrived or path.is_empty():
			model.play("idle" if not dead else "lie"); return
		if not is_on_floor(): velocity.y -= gravity * delta
		var threat := false
		for a in world.actors:
			if a.team == 1 and not a.dead and a.global_position.distance_to(global_position) < 13.0: threat = true
		var target: Vector3 = path[idx]
		var to := target - global_position
		to.y = 0
		if threat:
			velocity.x = 0; velocity.z = 0
			model.play("idle")
		elif to.length() < 2.0:
			idx += 1
			if idx >= path.size(): arrived = true
		else:
			var d := to.normalized()
			velocity.x = d.x * 2.6; velocity.z = d.z * 2.6
			rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 4.0 * delta)
			model.play("walk")
		move_and_slide()


func setup(w: Node, quest: Dictionary) -> void:
	world = w
	q = quest
	kind = q["kind"]
	var lvl := maxi(int(q.get("lvl", 1)), Data.zone_level(world.zone_id))
	var camp: Vector3 = world.info["camp"]
	_build_camp(camp)
	match kind:
		"hunt":
			need = q["targets"].duplicate()
			for sp in need:
				counts[sp] = 0
				for i in int(need[sp]) + 1:
					var p := _far_spawn(camp, 25.0) + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
					world.spawn_monster(sp, p, lvl, "mission")
		"large_hunt":
			var far := _far_spawn(camp, 90.0)
			# Story hunts scale to the quest; leves use the mark's own level.
			var blv := int(q.get("lvl", 1)) + 1 if not q.get("leve", false) else maxi(lvl, int(Data.monsters[q["boss"]]["lvl"]))
			boss = world.spawn_monster(q["boss"], far, blv, "mission")
		"gather":
			var cands: Array = world.info["nodes"].duplicate()
			cands.shuffle()
			if q.get("underwater", false):
				cands = []
				for wtr in world.info["waters"]:
					for i in 8:
						var p: Vector3
						if wtr["kind"] == "lake":
							var a := randf() * TAU
							var c: Vector2 = wtr["center"]
							p = Vector3(c.x + cos(a) * randf_range(4, 14), 0, c.y + sin(a) * randf_range(4, 14))
						else:
							var dv: Vector2 = wtr["dir"]
							var base := Vector2(dv.x, dv.y) * (ZoneData.SIZE * 0.5 - 30.0)
							p = Vector3(base.x + randf_range(-40, 40), 0, base.y + randf_range(-40, 40))
						p.y = world.ground_height(p.x, p.z) + 0.3
						cands.append(p)
			for i in mini(int(q["count"]) + 2, cands.size()):
				_make_node(cands[i], q.get("node", "Supply Crate"))
			for sp in q.get("spawn", {}):
				for i in int(q["spawn"][sp]):
					world.spawn_monster(sp, _far_spawn(camp, 30.0), lvl, "mission")
		"defense":
			objective = Barricade.new()
			world.add_child(objective)
			var lm: Vector3 = world.info["landmarks"][mini(1, world.info["landmarks"].size() - 1)]["pos"] if not world.info["landmarks"].is_empty() else camp
			var op := camp.lerp(lm, 0.35)
			op.y = world.ground_height(op.x, op.z)
			objective.global_position = op
			objective.world = world
			objective.max_hp = 3500.0 + lvl * 400.0
			objective.hp = objective.max_hp
			world.actors.append(objective)
			_t = 6.0
		"escort":
			var e := Escortee.new()
			world.add_child(e)
			e.global_position = camp + Vector3(2, 0.5, 2)
			e.setup(world, q.get("escortee", "Merchant"))
			objective = e
			world.actors.append(e)
			var dest: Vector3 = _far_spawn(camp, 100.0)
			for k in range(1, 9):
				var p := camp.lerp(dest, k / 8.0)
				p.y = world.ground_height(p.x, p.z)
				escort_path.append(p)
			e.path = escort_path
			world.fx.telegraph("circle", dest, Vector3.FORWARD, {"radius": 4.0}, 9999.0, Color("#80ff90"), false)
			for sp in q.get("spawn", {}):
				for i in int(q["spawn"][sp]):
					world.spawn_monster(sp, escort_path[4 + i % 3] + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)), lvl, "mission")


func _build_camp(p: Vector3) -> void:
	var bt := Batcher.new()
	var tent := PrismMesh.new(); tent.size = Vector3(4, 3, 4.5)
	bt.add(tent, Transform3D(Basis(), p + Vector3(-4, 1.5, -3)), "canvas", Props.pbr("#d8ccb0", 0.9))
	bt.box(p + Vector3(3, 0.4, -2), Vector3(1.2, 0.8, 0.8), "box", Props.pbr("#3a5a8a", 0.6))
	bt.commit(world.info["root"])
	ZoneBuilder._sign(world.info["root"], p + Vector3(3, 2.0, -2), "Supply Box", 20)
	var taken := {"v": false}
	world.interactables.append({"pos": p + Vector3(3, 0, -2), "kind": "node", "prompt": "Supply Box", "on_use": func(_it):
		if taken["v"]: world.toast_small("The supply box is empty."); return
		taken["v"] = true
		Game.add_item("potion", 2)
		world.toast_small("Took 2 Hi-Potions from the supply box.")})


func _far_spawn(from: Vector3, min_d: float) -> Vector3:
	var best: Vector3 = from + Vector3(40, 0, -40)
	var best_d := -1.0
	var spawns: Array = world.info["spawns"]
	for i in 30:
		if spawns.is_empty(): break
		var p: Vector3 = spawns[randi() % spawns.size()]
		var dd := p.distance_to(from)
		if dd >= min_d and (best_d < 0.0 or randf() < 0.35): best = p; best_d = dd
		elif best_d < 0.0 and dd > best_d: best = p; best_d = dd
	return best


func _make_node(p: Vector3, label: String) -> void:
	var root := Node3D.new()
	world.info["root"].add_child(root)
	root.global_position = p
	var mi := MeshInstance3D.new()
	if "Crystal" in label:
		var pm := PrismMesh.new(); pm.size = Vector3(0.8, 1.8, 0.8); mi.mesh = pm
		mi.material_override = Props.glow("#a090ff", 2.5)
		mi.position.y = 0.9
	else:
		var bm := BoxMesh.new(); bm.size = Vector3(1.0, 0.8, 0.8); mi.mesh = bm
		mi.material_override = Props.pbr("#8a6a40", 0.8)
		mi.position.y = 0.4
	root.add_child(mi)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.15; cm.bottom_radius = 0.15; cm.height = 8.0
	beam.mesh = cm; beam.position.y = 4.0
	beam.material_override = FX.mat(Color("#ffe080"), 2.0, 0.25)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	nodes.append(root)
	var entry := {"node": root, "kind": "node", "prompt": "Gather: " + label}
	entry["on_use"] = func(it):
		if not is_instance_valid(it["node"]): return
		var pl: Player = world.player
		pl._set_state("gather")
		pl.model.replay("gather", 0.1)
		await get_tree().create_timer(1.3).timeout
		if is_instance_valid(pl) and pl.state == "gather": pl._set_state("move")
		if not is_instance_valid(it["node"]): return
		it["node"].queue_free()
		world.interactables.erase(it)
		gathered += 1
		Sfx.play("coin", -6.0)
		world.toast_small("Recovered %s (%d/%d)" % [label, gathered, int(q["count"])])
		if gathered >= int(q["count"]): complete()
	world.interactables.append(entry)


func objective_text() -> String:
	match kind:
		"hunt":
			var parts := []
			for sp in need: parts.append("%s %d/%d" % [Data.monsters[sp]["name"], int(counts[sp]), int(need[sp])])
			return "Defeat: " + ", ".join(parts)
		"large_hunt":
			return "Hunt the %s" % Data.monsters[q["boss"]]["name"]
		"gather":
			return "Recover %s: %d/%d" % [q.get("node", "items"), gathered, int(q["count"])]
		"defense":
			var hp_txt := "%d%%" % int(objective.hp / objective.max_hp * 100.0) if is_instance_valid(objective) else "0%"
			return "Defend the barricade (wave %d/%d)  Barricade %s" % [mini(wave, int(q.get("waves", 2))), int(q.get("waves", 2)), hp_txt]
		"escort":
			var e := objective as Escortee
			if e == null: return ""
			return "Escort %s  (%d%%)  HP %d%%" % [e.display_name, int(float(e.idx) / maxf(1.0, escort_path.size()) * 100.0), int(e.hp / e.max_hp * 100.0)]
	return ""


func objective_point() -> Vector3:
	match kind:
		"large_hunt":
			if is_instance_valid(boss): return boss.global_position
		"defense", "escort":
			if is_instance_valid(objective): return objective.global_position
		"gather":
			for n in nodes:
				if is_instance_valid(n): return n.global_position
		"hunt":
			var best := Vector3.INF
			for a in world.actors:
				if a is Monster and not a.dead and need.has(a.id) and int(counts[a.id]) < int(need[a.id]):
					if best == Vector3.INF or a.global_position.distance_to(world.player.global_position) < best.distance_to(world.player.global_position): best = a.global_position
			return best
	return Vector3.INF


func _process(delta: float) -> void:
	if done or failed:
		if _return_t > 0.0:
			_return_t -= delta
			world.hud.set_objective(("Quest Complete! " if done else "Quest Failed. ") + "Returning in %d..." % int(ceil(_return_t)))
			if _return_t <= 0.0 and not world.cutscene.active:
				world.return_to_city()
				_return_t = -999.0
		return
	world.hud.set_objective(q["name"] + "\n" + objective_text())
	match kind:
		"defense":
			if not is_instance_valid(objective) or objective.dead:
				fail(); return
			wave_mobs = wave_mobs.filter(func(m): return is_instance_valid(m) and not m.dead)
			_t -= delta
			if wave_mobs.is_empty() and _t <= 0.0:
				if wave >= int(q.get("waves", 2)):
					complete(); return
				wave += 1
				_t = 4.0
				_spawn_wave()
		"escort":
			var e := objective as Escortee
			if not is_instance_valid(e) or e.dead:
				fail(); return
			var prog := float(e.idx) / maxf(1.0, escort_path.size())
			for i in 2:
				if not _ambush[i] and prog >= [0.3, 0.65][i]:
					_ambush[i] = true
					_spawn_ambush(e)
			if e.arrived: complete()


func _spawn_wave() -> void:
	var lvl := maxi(int(q.get("lvl", 1)), Data.zone_level(world.zone_id))
	var mob: String = q.get("mob", "")
	var pool: Array = []
	if mob != "": pool = [mob]
	elif q.has("pool"): pool = q["pool"]
	else:
		for m in world.zd.get("mobs", []): pool.append(m[0])
	world.toast_small("Wave %d incoming!" % wave)
	Sfx.play("roar", -4.0, 1.3)
	for i in 3 + wave * 2:
		var a := randf() * TAU
		var p: Vector3 = objective.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(28, 38)
		var m: Monster = world.spawn_monster(pool[randi() % pool.size()], p, lvl, "mission")
		m.target = objective if randf() < 0.6 else world.player
		m.aggressive = true
		m.state = "chase"
		m.home = objective.global_position
		wave_mobs.append(m)


func _spawn_ambush(e: Actor) -> void:
	var lvl := maxi(int(q.get("lvl", 1)), Data.zone_level(world.zone_id))
	var pool: Array = []
	for m in world.zd.get("mobs", []): pool.append(m[0])
	world.toast_small("Ambush!")
	for i in 3:
		var p: Vector3 = e.global_position + e.facing() * 16.0 + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		var m: Monster = world.spawn_monster(pool[randi() % pool.size()], p, lvl, "mission")
		m.target = e; m.aggressive = true; m.state = "chase"


func on_kill(m: Monster) -> void:
	if done or failed: return
	match kind:
		"hunt":
			if need.has(m.id):
				counts[m.id] = mini(int(counts[m.id]) + 1, int(need[m.id]))
				var all := true
				for sp in need:
					if int(counts[sp]) < int(need[sp]): all = false
				if all: complete()
		"large_hunt":
			if m == boss: complete()


func on_faint() -> void:
	faints += 1
	world.toast_small("Faints: %d / 3" % faints)
	if faints >= 3: fail()


func complete() -> void:
	if done or failed: return
	done = true
	Sfx.play("levelup", 0.0)
	var rew := Game.finish_mission(true)
	world.hud.banner("QUEST COMPLETE", rew)
	_return_t = 25.0 if kind == "large_hunt" else 9.0
	var outro: String = q.get("outro", "")
	if outro != "" and Data.cutscenes.has(outro):
		await get_tree().create_timer(2.5).timeout
		world.cutscene.play(outro)


func fail() -> void:
	if done or failed: return
	failed = true
	Game.finish_mission(false)
	world.hud.banner("QUEST FAILED", "")
	_return_t = 5.0
