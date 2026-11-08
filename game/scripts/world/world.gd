extends Node3D
## Runs one zone: builds it, owns the actors, environment, interactions, zone lines,
## mission objectives, and the HUD / menus / cutscene layers on top.

var zone_id := ""
var zd: Dictionary
var info: Dictionary
var heights: PackedFloat32Array
var hn := ZoneBuilder.N
var hsize := ZoneData.SIZE
var actors: Array = []
var player: Player
var companions: Array = []
var fx: FX
var hud: HUD
var menu: GameMenu
var services: Services
var dialogue: Dialogue
var cutscene: Cutscene
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var boss: Monster
var dangers: Array = []
var effect_zones: Array = []
var interactables: Array = []
var mission_runner: MissionRunner
var _respawn_q: Array = []
var _exit_cool := 2.0
var _lod_t := 0.0
var _dodge_cool := 0.0
var _snow: GPUParticles3D
var storm := false


func _ready() -> void:
	var ps: Dictionary = Game.pending_spawn
	zone_id = ps.get("zone", "gridania")
	zd = Data.zones[zone_id]
	Game.state["zone"] = zone_id
	fx = FX.new(); fx.name = "FX"; add_child(fx)
	info = ZoneBuilder.build(zone_id)
	heights = info["heights"]
	hn = info["n"]; hsize = info["size"]
	add_child(info["root"])
	_build_environment(info["biome"])
	# player
	player = Player.new()
	player.name = "Player"
	player.world = self
	add_child(player)
	var pos: Vector3 = ps.get("pos", Vector3.ZERO)
	if ps.get("at_aetheryte", false): pos = info["aetheryte"] + Vector3(3, 0, 3)
	if ps.get("at_ferry", false):
		for n in info["npcs"]:
			if n["role"] == "ferry": pos = n["pos"] + Vector3(2, 0, 0)
	if ps.get("from_zone", "") != "":
		for e in info["exits"]:
			if e["to"] == ps["from_zone"]:
				pos = e["pos"] - Vector3(e["pos"].x, 0, e["pos"].z).normalized() * 14.0
	if ps.get("mission", false) and not Game.mission.is_empty(): pos = info["camp"]
	pos.y = ground_height(pos.x, pos.z) + 0.3
	player.global_position = pos
	player.rotation.y = atan2(pos.x, pos.z)
	player._cam_rot.x = player.rotation.y
	actors.append(player)
	if not Game.state["attuned"].has(zone_id) and zd["type"] == "city":
		Game.state["attuned"].append(zone_id)
	# npcs
	for n in info["npcs"]:
		var npc := NPC.new()
		add_child(npc)
		npc.global_position = Vector3(n["pos"].x, ground_height(n["pos"].x, n["pos"].z), n["pos"].z)
		if n["role"] == "citizen":
			npc.rotation.y = n.get("face", 0.0)
		else:
			# Service NPCs stand facing the plaza / zone centre, where players approach from.
			var to_c: Vector3 = Vector3.ZERO - npc.global_position
			npc.rotation.y = atan2(-to_c.x, -to_c.z)
		npc.setup(n, self)
		interactables.append({"node": npc, "kind": "npc"})
	interactables.append({"pos": info["aetheryte"], "kind": "aetheryte", "prompt": "Aetheryte"})
	# party
	if zd["type"] == "field":
		var idx := 0
		for rid in Game.state.get("party", []):
			for rec in ItemData.RECRUITS:
				if rec["id"] == rid:
					var c := Companion.new()
					add_child(c)
					c.global_position = pos + Vector3(idx * 1.5 - 1.5, 0.5, 2.0)
					c.setup(rec, self, idx)
					companions.append(c)
					actors.append(c)
					idx += 1
	# UI layers
	hud = HUD.new(); add_child(hud); hud.setup(self)
	dialogue = Dialogue.new(); add_child(dialogue)
	services = Services.new(); add_child(services); services.setup(self)
	menu = GameMenu.new(); add_child(menu); menu.setup(self)
	cutscene = Cutscene.new(); add_child(cutscene); cutscene.setup(self)
	player.hud_event.connect(hud.on_player_event)
	Inputs.device_changed.connect(func(_pad): hud._refresh_hotbar())
	Game.quest_updated.connect(func():
		for it in interactables:
			if it.get("node") is NPC and is_instance_valid(it["node"]): it["node"].refresh_marker())
	Game.toast.connect(hud.toast)
	Game.level_up.connect(func(_j, _l): Sfx.play("levelup", -2.0); fx.nova(player.global_position, 4.0, Color(1, 0.9, 0.5)); player._refresh_stats(); player.hp = player.max_hp)
	# monsters / mission
	if zd["type"] == "field":
		if ps.get("mission", false) and not Game.mission.is_empty():
			mission_runner = MissionRunner.new(); add_child(mission_runner); mission_runner.setup(self, Game.mission)
		_spawn_ambient()
	_spawn_echo()
	Sfx.music(info["biome"].get("music", "forest"))
	hud.zone_banner(zd["name"], zd["region"])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cs: String = ps.get("cutscene", "")
	Game.pending_spawn = {}
	var cmds: Array = ps.get("cutscene_cmds", [])
	if not cmds.is_empty():
		cutscene.play_cmds(cmds)
	elif cs != "" and Data.cutscenes.has(cs):
		cutscene.play(cs)
	elif not Game.mission.is_empty() and mission_runner:
		hud.toast(Game.mission["name"] + ": " + mission_runner.objective_text())
	Game.save_game()


# ------------------------------------------------------------------ environment
func _build_environment(b: Dictionary) -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(b["sky_top"])
	sky_mat.sky_horizon_color = Color(b["sky_horizon"])
	sky_mat.ground_horizon_color = Color(b["sky_horizon"])
	sky_mat.ground_bottom_color = Color(b["fog"]).darkened(0.5)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sky_curve = 0.12
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_radius = 1.2; env.ssao_intensity = 1.6
	env.glow_intensity = 0.5; env.glow_bloom = 0.05; env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(b["fog"])
	env.fog_density = float(b["fog_density"]) * 0.5
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.4
	env.volumetric_fog_density = float(b["fog_density"]) * 0.8
	env.volumetric_fog_albedo = Color(b["fog"])
	env.volumetric_fog_length = 90.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(b["sun"])
	sun.light_energy = float(b["sun_e"])
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	add_child(sun)
	Settings.apply_env(env, sun)
	Settings.changed.connect(func(): Settings.apply_env(env, sun))
	if not Game.state.has("tod"): Game.state["tod"] = 9.0
	_update_sun(0.0)
	if b.get("snowfall", false) or zd.get("snow", false): _make_snow()


func _make_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.amount = int(800 * float(Settings.gfx["grass"])) + 100
	_snow.lifetime = 6.0
	_snow.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.initial_velocity_min = 1.0; pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -0.6, 0)
	pm.turbulence_enabled = false
	_snow.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1, 1, 1, 0.85); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	_snow.draw_pass_1 = q
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_snow)


func set_storm(v: bool) -> void:
	storm = v
	_update_sun(0.0)


func _update_sun(delta: float) -> void:
	var tod: float = fmod(float(Game.state.get("tod", 9.0)) + delta / 100.0, 24.0)
	Game.state["tod"] = tod
	var day := tod >= 6.0 and tod < 19.0
	var k := (tod - 6.0) / 13.0 if day else fmod(tod + 5.0, 24.0) / 11.0
	var elev := sin(k * PI) * (62.0 if day else 40.0) + 6.0
	sun.rotation_degrees = Vector3(-elev, -40.0 + k * 140.0, 0)
	var b: Dictionary = info["biome"]
	var dawn := 1.0 - smoothstep(0.0, 0.18, minf(k, 1.0 - k)) if day else 0.0
	var base_e: float = float(b["sun_e"])
	if day:
		sun.light_color = Color(b["sun"]).lerp(Color("#ffb070"), dawn * 0.7)
		sun.light_energy = base_e * (0.55 + 0.45 * sin(k * PI))
		sky_mat.sky_top_color = Color(b["sky_top"]).lerp(Color("#5a4a7a"), dawn * 0.5)
		sky_mat.sky_horizon_color = Color(b["sky_horizon"]).lerp(Color("#f0a070"), dawn * 0.6)
		env.ambient_light_energy = 1.0
		sky_mat.sky_energy_multiplier = 1.0
	else:
		sun.light_color = Color("#9ab0ff")
		sun.light_energy = 0.22
		sky_mat.sky_top_color = Color("#070b1a")
		sky_mat.sky_horizon_color = Color("#1a2238")
		env.ambient_light_energy = 0.45
		sky_mat.sky_energy_multiplier = 0.5
	if storm:
		sky_mat.sky_top_color = Color("#20142e"); sky_mat.sky_horizon_color = Color("#3a2a48")
		sun.light_energy *= 0.4; sun.light_color = Color("#b080ff")


# ------------------------------------------------------------------ queries
func ground_height(x: float, z: float) -> float:
	return ZoneBuilder.sample(heights, x, z, hn, hsize)


func water_level(x: float, z: float) -> float:
	for w in info["waters"]:
		match w["kind"]:
			"sea":
				var p := Vector2(x, z)
				if w["from"] < -900.0 or p.dot(w["dir"]) > float(w["from"]): return float(w["level"])
				if ground_height(x, z) < float(w["level"]): return float(w["level"])
			"lake":
				if Vector2(x, z).distance_to(w["center"]) < float(w["radius"]): return float(w["level"])
			"river":
				if absf(z - float(w["z"])) < float(w["half"]): return float(w["level"])
	return -1000.0


## Camera position near `desired` with an unobstructed view of `target` (a face).
## Walls, terrain and the player's body count as blockers; the speaker's own body can be excluded.
## Tries the requested angle first, then swings around the target, then pulls in closer.
## Characters that may block a conversation shot (the player plus anyone on stage in a scene).
var shot_blockers: Array = []


func clear_shot(target: Vector3, desired: Vector3, exclude: Array = [], allowed: Array = []) -> Vector3:
	var space := get_world_3d().direct_space_state
	var off := desired - target
	var cands: Array = [desired]
	# Swing around the subject, but never behind them: a conversation shot must see the face.
	for deg in [20, -20, 40, -40, 65, -65, 90, -90]:
		cands.append(target + off.rotated(Vector3.UP, deg_to_rad(deg)))
	for deg in [0, 30, -30, 60, -60]:
		cands.append(target + off.rotated(Vector3.UP, deg_to_rad(deg)) * 0.65 + Vector3(0, 0.55, 0))
	for c in cands:
		if c.y < ground_height(c.x, c.z) + 0.3: continue
		if _sight_clear(space, target, c, exclude, allowed): return c
	var q := PhysicsRayQueryParameters3D.create(target, desired, 1 | 2, exclude)
	var hit := space.intersect_ray(q)
	if hit.is_empty(): return desired
	return target.lerp(hit["position"], 0.85)


func _sight_clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, exclude: Array, allowed: Array = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 2, exclude)
	if not space.intersect_ray(q).is_empty(): return false
	# Characters have thin or no colliders, so also keep the lens clear of their heads and
	# shoulders, except characters the shot deliberately includes (e.g. the shoulder in an
	# over-the-shoulder shot).
	var people: Array = shot_blockers.duplicate()
	if player and is_instance_valid(player) and not people.has(player.model): people.append(player.model)
	var seg := b - a
	for m in people:
		if not is_instance_valid(m) or allowed.has(m) or not m.is_visible_in_tree(): continue
		var ph: Vector3 = m.head_pos() - Vector3(0, 0.2 * m.scale.y, 0)
		if a.distance_to(ph) < 0.7: continue   # the person being framed
		if b.distance_to(ph) < 0.75: return false   # someone right in front of the lens
		var t := clampf((ph - a).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if (a + seg * t).distance_to(ph) < 0.42 * maxf(m.scale.y, 0.6): return false
	return true


func party_members() -> Array:
	var out: Array = [player]
	out.append_array(companions)
	return out


func add_danger(shape: String, origin: Vector3, dir: Vector3, p: Dictionary, time: float) -> void:
	dangers.append({"shape": shape, "origin": origin, "dir": dir, "p": p, "until": Time.get_ticks_msec() + int(time * 1000.0)})


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	_update_sun(delta)
	if _snow and player: _snow.global_position = player.global_position + Vector3(0, 14, 0)
	var now := Time.get_ticks_msec()
	dangers = dangers.filter(func(d): return d["until"] > now)
	actors = actors.filter(func(a): return is_instance_valid(a))
	_tick_effect_zones(delta)
	_dodge_cool -= delta
	# LOD: far monsters stop thinking and hide
	_lod_t -= delta
	if _lod_t <= 0.0 and player:
		_lod_t = 0.5
		for a in actors:
			if a is Monster:
				var far: bool = a.global_position.distance_to(player.global_position) > (140.0 if a.large else 75.0)
				a.lod_far = far
				a.visible = not far or a.large
	# respawns
	for r in _respawn_q:
		r["t"] -= delta
	var due := _respawn_q.filter(func(r): return r["t"] <= 0.0)
	_respawn_q = _respawn_q.filter(func(r): return r["t"] > 0.0)
	for r in due: _spawn_monster(r["id"], _random_spawn(), r["lvl"])
	# zone lines
	_exit_cool -= delta
	if _exit_cool <= 0.0 and player and player.state != "cutscene" and not cutscene.active:
		for e in info["exits"]:
			if Vector2(player.global_position.x - e["pos"].x, player.global_position.z - e["pos"].z).length() < 4.5:
				_exit_cool = 2.0
				_take_exit(e)
				break
	_update_interact()


func _update_interact() -> void:
	if player == null or cutscene.active or menu.visible or services.is_open() or dialogue.active:
		if player: player.interact_target = null
		hud.set_prompt("")
		return
	var best = null
	var best_d := 2.8
	for it in interactables:
		var node = it.get("node")
		if node != null and not is_instance_valid(node): continue
		var p: Vector3 = node.global_position if node else it["pos"]
		var dd := p.distance_to(player.global_position)
		if it["kind"] == "aetheryte": dd -= 1.5
		if dd < best_d: best_d = dd; best = it
	for a in actors:
		if a is Monster and a.dead and a.carves > 0 and a.global_position.distance_to(player.global_position) < 2.2 + a.radius:
			best = {"kind": "carve", "node": a}
	player.interact_target = best
	if best == null:
		hud.set_prompt(""); return
	var label := ""
	match best["kind"]:
		"npc": label = "%s  (%s)" % [best["node"].prompt(), best["node"].npc_name]
		"carve": label = "Carve"
		_: label = best.get("prompt", "Interact")
	hud.set_prompt("[%s] %s" % [Inputs.glyph("interact"), label])
	if Input.is_action_just_pressed("interact") and player.state == "move":
		_interact(best)


func _interact(it: Dictionary) -> void:
	match it["kind"]:
		"npc": services.talk(it["node"])
		"aetheryte":
			if not Game.state["attuned"].has(zone_id):
				Game.state["attuned"].append(zone_id)
				hud.toast("Attuned to the aetheryte: %s" % zd["aetheryte"])
				fx.nova(info["aetheryte"], 5.0, Color("#8fe0ff"))
				Sfx.play("levelup", -6.0)
			services.open_teleport()
		"carve":
			var m: Monster = it["node"]
			player._set_state("gather")
			player.model.replay("gather", 0.1)
			var got := m.carve()
			get_tree().create_timer(1.1).timeout.connect(func():
				if is_instance_valid(player): player._set_state("move")
				if got != "": hud.toast("Carved: " + got))
		"node":
			if it.has("on_use"): it["on_use"].call(it)


func _take_exit(e: Dictionary) -> void:
	if not Game.mission.is_empty():
		hud.toast("You cannot leave while on a quest. Abandon it from the Journal.")
		return
	Game.state["hp_frac"] = player.hp / player.max_hp
	hud.fade_out(0.4)
	await get_tree().create_timer(0.45).timeout
	Game.goto_zone(e["to"], Vector3.ZERO, {"from_zone": zone_id})


func teleport(zone: String) -> void:
	Game.state["hp_frac"] = player.hp / player.max_hp
	fx.nova(player.global_position, 3.0, Color("#8fe0ff"))
	hud.fade_out(0.6)
	await get_tree().create_timer(0.65).timeout
	Game.goto_zone(zone, Vector3.ZERO, {"at_aetheryte": true})


func ferry(zone: String) -> void:
	hud.fade_out(0.8)
	await get_tree().create_timer(0.85).timeout
	Game.goto_zone(zone, Vector3.ZERO, {"at_ferry": true})


# ------------------------------------------------------------------ spawning
func _random_spawn() -> Vector3:
	var s: Array = info["spawns"]
	if s.is_empty(): return Vector3(randf_range(-80, 80), 0, randf_range(-80, 80))
	var p: Vector3 = s[randi() % s.size()]
	return p


func _spawn_ambient() -> void:
	var lv := Data.zone_level(zone_id)
	var hard := mission_runner != null and mission_runner.kind in ["defense", "escort"]
	for m in zd.get("mobs", []):
		for i in (int(m[1]) if not hard else int(m[1]) / 2):
			_spawn_monster(m[0], _random_spawn() + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), lv + randi() % 3)


func _spawn_monster(id: String, pos: Vector3, lvl: int, tag := "") -> Monster:
	var m := Monster.new()
	add_child(m)
	pos.y = ground_height(pos.x, pos.z) + 0.3
	m.global_position = pos
	m.rotation.y = randf() * TAU
	m.setup(id, lvl, self)
	m.mission_tag = tag
	actors.append(m)
	return m


func spawn_monster(id: String, pos: Vector3, lvl: int, tag := "") -> Monster:
	return _spawn_monster(id, pos, lvl, tag)


# ------------------------------------------------------------------ combat callbacks
func on_hit(a: Actor, dealt: int, crit: bool, guarded: bool, perfect: bool, team: int) -> void:
	var pos := a.center() + Vector3(0, 0.6 * a.scale.y, 0)
	if perfect: fx.number(pos, "Perfect!", Color("#fff6b0"), true)
	elif guarded: fx.number(pos, "Block %d" % dealt, Color("#a8c8ff"))
	elif team == 1: fx.number(pos, ("%d!" % dealt) if crit else str(dealt), Color("#ffd040") if crit else Color.WHITE, crit)
	else: fx.number(pos, str(dealt), Color("#ff6a5a"))
	if team == 0 and a == player and dealt > 0:
		hud.flash_damage(clampf(float(dealt) / a.max_hp * 3.0, 0.15, 0.6))
		Sfx.play("heavy" if dealt > a.max_hp * 0.2 else "hit", -2.0, 0.8)


func on_heal(a: Actor, amount: int) -> void:
	fx.number(a.center() + Vector3(0, 0.7, 0), "+%d" % amount, Color("#7dff9a"))


func on_perfect_dodge() -> void:
	if _dodge_cool > 0.0: return
	_dodge_cool = 1.0
	player.stam = minf(player.max_stam, player.stam + 18.0)
	player.gauge = minf(100.0, player.gauge + 5.0)
	fx.number(player.center() + Vector3(0, 0.8, 0), "Evade", Color("#c0e8ff"))


func on_boss_engaged(m: Monster) -> void:
	if boss == m: return
	boss = m
	hud.show_boss(m)
	Sfx.music("battle")


func on_monster_killed(m: Monster) -> void:
	var lv := m.level
	var xp := int((60 + lv * 25) * (8.0 if m.large else 1.0))
	Game.add_xp(xp)
	var gil := int(m.d.get("gil", 4 + lv * 2)) * (6 if m.large else 1)
	Game.add_gil(gil)
	var got := []
	for k in m.d["drops"]:
		if randf() < float(m.d["drops"][k]):
			Game.add_item(k, 1); got.append(Data.item_name(k))
	if m.large or not got.is_empty() or gil > 0:
		hud.loot("%s defeated  +%d EXP  +%d gil%s" % [m.display_name, xp, gil, ("  " + ", ".join(got)) if not got.is_empty() else ""])
	if m == boss:
		boss = null
		hud.show_boss(null)
		Sfx.music(info["biome"].get("music", "forest"))
		fx.shake(0.6)
		if m.large: hud.toast("Carve the %s for materials!" % m.display_name)
	if player.lock_target == m: player.lock_target = null
	if mission_runner: mission_runner.on_kill(m)
	if not m.large and m.mission_tag == "" and zd["type"] == "field":
		_respawn_q.append({"id": m.id, "t": 45.0, "lvl": m.level})


func player_fainted() -> void:
	if Game.count("phoenix") > 0:
		Game.add_item("phoenix", -1)
		player.revive(0.5)
		fx.nova(player.global_position, 4.0, Color("#ffb060"))
		hud.toast("A Phoenix Down revives you!")
		return
	if mission_runner:
		mission_runner.on_faint()
		if not is_instance_valid(mission_runner) or mission_runner.failed: return
	if mission_runner == null:
		var lost := int(int(Game.state["gil"]) * 0.3)
		if lost > 0:
			Game.add_gil(-lost)
			Game.state["echo"] = {"zone": zone_id, "pos": [player.global_position.x, player.global_position.y, player.global_position.z], "gil": lost}
			hud.toast("You dropped %d gil where you fell. Return to recover it." % lost)
	hud.fade_out(0.8)
	await get_tree().create_timer(0.9).timeout
	if mission_runner == null: _spawn_echo()
	var p: Vector3 = info["camp"] if mission_runner else info["aetheryte"] + Vector3(3, 0, 3)
	p.y = ground_height(p.x, p.z) + 0.5
	player.global_position = p
	player.revive(1.0)
	hud.fade_in(0.8)


func rest_at_aetheryte() -> void:
	hud.fade_out(0.5)
	await get_tree().create_timer(0.55).timeout
	player.revive(1.0)
	player.mp = player.max_mp
	for a in actors.duplicate():
		if a is Monster and a.mission_tag == "" and not a.large:
			actors.erase(a); a.queue_free()
	_respawn_q.clear()
	if zd["type"] == "field": _spawn_ambient()
	Game.state["pos"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	Game.state["hp_frac"] = 1.0
	Game.save_game()
	hud.fade_in(0.6)
	hud.toast("You rest at the aetheryte. Your journey has been saved.")


## Elden Ring-style echo: gil dropped where you fell outside a quest, recoverable once.
func _spawn_echo() -> void:
	var e: Dictionary = Game.state.get("echo", {})
	if e.is_empty() or e.get("zone", "") != zone_id: return
	var p := Vector3(e["pos"][0], e["pos"][1], e["pos"][2])
	var root := Node3D.new()
	info["root"].add_child(root)
	root.global_position = p
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.35; sm.height = 0.7
	mi.mesh = sm; mi.material_override = FX.mat(Color("#ffd060"), 3.0, 0.8); mi.position.y = 0.8
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var entry := {"node": root, "kind": "node", "prompt": "Recover your lost %d gil" % int(e["gil"])}
	entry["on_use"] = func(it):
		Game.add_gil(int(Game.state["echo"].get("gil", 0)))
		hud.toast("Recovered %d gil." % int(Game.state["echo"].get("gil", 0)))
		Game.state["echo"] = {}
		Sfx.play("coin")
		interactables.erase(it)
		root.queue_free()
	interactables.append(entry)


func respawn_player() -> void:
	var p: Vector3 = info["aetheryte"] + Vector3(3, 0, 3)
	p.y = ground_height(p.x, p.z) + 1.0
	player.global_position = p
	player.velocity = Vector3.ZERO


func toast_small(t: String) -> void:
	hud.toast(t)


# ------------------------------------------------------------------ ground effect zones
func spawn_zone(owner: Actor, a: Dictionary) -> void:
	var pos := owner.global_position
	var col := Color(a.get("color", "#a0ffd0"))
	var ring := fx.telegraph("circle", pos, owner.facing(), {"radius": a["radius"]}, float(a["time"]), col, false)
	ring.visible = true
	effect_zones.append({"pos": pos, "a": a, "t": float(a["time"]), "tick": 0.0, "owner": owner})


func _tick_effect_zones(delta: float) -> void:
	for z in effect_zones:
		z["t"] -= delta
		z["tick"] -= delta
		if z["tick"] > 0.0: continue
		z["tick"] = 1.0
		var a: Dictionary = z["a"]
		var owner: Actor = z["owner"]
		if not is_instance_valid(owner): continue
		for t in actors:
			if t.global_position.distance_to(z["pos"]) > float(a["radius"]) + t.radius: continue
			match a["kind"]:
				"zone":
					if t.team != owner.team and not t.dead:
						var r := owner.roll_damage(float(a["pot"]))
						t.take_hit({"amount": r["amount"], "crit": r["crit"], "source": owner})
				"zone_heal":
					if t.team == owner.team:
						t.heal(t.max_hp * float(a["amount"]))
						if a.has("def"): t.add_buff("def", float(a["def"]), 1.5)
					elif a.has("pot") and not t.dead:
						t.take_hit({"amount": owner.roll_damage(float(a["pot"]))["amount"], "source": owner})
				"zone_buff":
					if t.team == owner.team: t.add_buff(a["buff"], float(a["amount"]), 1.5)
	effect_zones = effect_zones.filter(func(z): return z["t"] > 0.0)


# ------------------------------------------------------------------ mission end
func return_to_city() -> void:
	Game.state["hp_frac"] = 1.0
	hud.fade_out(1.0)
	await get_tree().create_timer(1.05).timeout
	var c := Game.city()
	Game.goto_zone(c, Vector3(0, 0, -16))
