class_name Player
extends Actor
## The adventurer. Monster Hunter / Elden Ring style controls: stamina-gated sprinting and
## dodge rolls with i-frames, guarding with a perfect-guard window, lock-on, swimming/diving,
## and a combo graph per job (light chain, heavy branches, charge attacks, specials, gauge).

signal hud_event(kind: String, data)

const WALK := 2.4
const RUN := 5.6
const SPRINT := 8.6
const SWIM := 3.4
const ROLL_T := 0.62
const BUFFER := 0.35

var model: CharModel
var cam_yaw: Node3D
var cam_pitch: Node3D
var arm: SpringArm3D
var camera: Camera3D
var job := "PLD"
var jd: Dictionary
var role := "tank"
var stats := {}
var max_mp := 10000.0
var mp := 10000.0
var max_stam := 100.0
var stam := 100.0
var stam_delay := 0.0
var gauge := 0.0
var sen := 0
var state := "move"        # move, attack, roll, guard, hit, down, dead, swim, drink, gather, busy, cutscene
var state_t := 0.0
var move_id := ""
var move: Dictionary = {}
var move_hit := {}
var hit_window := -1
var buffered := ""
var buffer_t := 0.0
var charge_t := 0.0
var charging := false
var lock_target: Actor
var combat_t := 0.0
var act_cd := [0.0, 0.0, 0.0, 0.0]
var breath := 1.0
var swimming := false
var diving := false
var knock_vel := Vector3.ZERO
var sprinting := false
var controls_enabled := true
var interact_target = null
var faints := 0
var roll_dir := Vector3.ZERO
var _cam_rot := Vector2(0.0, -0.25)
var _steps := 0.0
var armor_t := 0.0


func _ready() -> void:
	team = 0
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.7
	cs.shape = cap; cs.position.y = 0.85
	add_child(cs)
	radius = 0.4
	model = CharModel.new()
	add_child(model)
	cam_yaw = Node3D.new(); cam_yaw.top_level = true; add_child(cam_yaw)
	cam_pitch = Node3D.new(); cam_yaw.add_child(cam_pitch)
	arm = SpringArm3D.new(); arm.spring_length = 4.3; arm.collision_mask = 1; arm.margin = 0.25
	var sph := SphereShape3D.new(); sph.radius = 0.25; arm.shape = sph
	cam_pitch.add_child(arm)
	camera = Camera3D.new(); camera.far = 900.0; camera.near = 0.08
	arm.add_child(camera)
	camera.current = true
	rebuild()
	Game.state_changed.connect(_refresh_stats)


func rebuild() -> void:
	var s := Game.state
	job = Game.job()
	jd = Data.jobs[job]
	role = jd["role"]
	display_name = s.get("name", "Adventurer")
	var shown: Dictionary = s["armor"].duplicate()
	for k in s.get("armor_hidden", {}):
		if s["armor_hidden"][k]: shown[k] = -1
	model.build(s["appearance"], {"armor": shown, "dyes": s.get("dyes", {}), "weapon": jd["weapon"], "tier": int(s["weapons"][job]["tier"])})
	model.set_drawn(false)
	_refresh_stats()
	hp = max_hp * float(s.get("hp_frac", 1.0))
	gauge = 0.0
	sen = 0


func _refresh_stats() -> void:
	stats = Game.stats()
	level = Game.level()
	var frac := hp / max_hp if max_hp > 0 else 1.0
	max_hp = stats["hp"]
	hp = clampf(frac * max_hp, 1.0, max_hp)
	atk = stats["atk"]
	defense = stats["def"]
	crit = stats["crit"]
	max_mp = stats["mp"]
	max_stam = stats["stam"]
	res = {"fire": stats["res_fire"], "ice": stats["res_ice"], "all": stats["res_all"]}
	if job != Game.job():
		rebuild()


# --------------------------------------------------------------------------- input
func _unhandled_input(e: InputEvent) -> void:
	if not controls_enabled: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = 0.0025 * float(Settings.v["sens"])
		_cam_rot.x -= e.relative.x * s
		_cam_rot.y -= e.relative.y * s * (-1.0 if Settings.v["invert_y"] else 1.0)


func _buffer(a: String) -> void:
	buffered = a
	buffer_t = BUFFER


func _read_combat_input() -> void:
	if Input.is_action_just_pressed("light"): _buffer("light")
	elif Input.is_action_just_pressed("heavy"): _buffer("heavy")
	elif Input.is_action_just_pressed("special"): _buffer("special")
	if Input.is_action_just_pressed("dodge"): _buffer("dodge")
	for i in 4:
		if Input.is_action_just_pressed("act%d" % (i + 1)): use_action(i)
	if Input.is_action_just_pressed("item"): _buffer("item")
	if Input.is_action_just_pressed("lock_on"): _toggle_lock()


func _move_input() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if v.length() < 0.05: return Vector3.ZERO
	var basis := Basis(Vector3.UP, cam_yaw.rotation.y)
	var d := basis * Vector3(v.x, 0, v.y)
	return d.limit_length(1.0)


# --------------------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	tick_status(delta)
	state_t += delta
	buffer_t -= delta
	if buffer_t <= 0.0: buffered = ""
	for i in 4: act_cd[i] = maxf(0.0, act_cd[i] - delta * (1.0 + buff("haste")))
	combat_t += delta
	armor_t = maxf(0.0, armor_t - delta)
	_regen(delta)
	if controls_enabled and state != "dead" and state != "cutscene":
		_read_combat_input()
	_update_water(delta)
	var input := _move_input() if controls_enabled and state not in ["cutscene", "dead"] else Vector3.ZERO
	match state:
		"move": _st_move(delta, input)
		"attack": _st_attack(delta, input)
		"roll": _st_roll(delta)
		"guard": _st_guard(delta, input)
		"hit": _st_simple(delta, 0.38)
		"down": _st_down(delta)
		"drink": _st_drink(delta, input)
		"swim": _st_swim(delta, input)
		"dead": _st_dead(delta)
		"gather", "busy", "cutscene": _st_simple(delta, 9999.0)
	# gravity & knockback
	if state != "swim":
		if not is_on_floor(): velocity.y -= gravity * delta
		elif velocity.y < 0: velocity.y = -0.5
	knock_vel = knock_vel.move_toward(Vector3.ZERO, 22.0 * delta)
	var saved := velocity
	velocity += knock_vel
	move_and_slide()
	velocity = Vector3(saved.x, velocity.y, saved.z)
	if global_position.y < -60.0 and world: world.respawn_player()
	if combat_t > 12.0 and model.drawn and state == "move": model.set_drawn(false)


func _process(delta: float) -> void:
	_update_camera(delta)


func _regen(delta: float) -> void:
	if dead: return
	stam_delay -= delta
	if stam_delay <= 0.0 and not sprinting and state != "guard":
		stam = minf(max_stam, stam + 30.0 * (1.0 + float(stats.get("stam_regen", 0.0))) * delta)
	mp = minf(max_mp, mp + (70.0 + (40.0 if combat_t > 5.0 else 0.0)) * (1.0 + float(stats.get("mp_regen", 0.0))) * delta)
	if stats.get("regen", 0.0) > 0.0: hp = minf(max_hp, hp + max_hp * float(stats["regen"]) * delta)
	if combat_t > 8.0 and state == "move": hp = minf(max_hp, hp + max_hp * 0.02 * delta)


func use_stam(n: float) -> bool:
	if stam < n * 0.5: return false
	stam = maxf(0.0, stam - n)
	stam_delay = 0.7
	return true


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0


func _face_dir(d: Vector3, delta: float, rate := 12.0) -> void:
	if d.length() < 0.01: return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(rate * delta, 0.0, 1.0))


# --------------------------------------------------------------------------- locomotion
func _st_move(delta: float, input: Vector3) -> void:
	var want_sprint := Input.is_action_pressed("dodge") and input.length() > 0.2 and controls_enabled
	if want_sprint and Input.is_action_pressed("dodge") and state_t > 0.0 and _dodge_held > 0.25 and stam > 1.0:
		sprinting = true
	elif not Input.is_action_pressed("dodge") or input.length() < 0.2 or stam <= 0.0:
		sprinting = false
	_track_dodge(delta)
	if sprinting:
		stam = maxf(0.0, stam - 14.0 * delta); stam_delay = 0.6
		if model.drawn: model.set_drawn(false)
	var spd := (SPRINT if sprinting else (RUN if input.length() > 0.55 else WALK)) * (0.6 if slow > 0.0 else 1.0)
	if model.drawn and not sprinting: spd *= 0.9
	var target_v := input * spd
	var accel := 40.0 if is_on_floor() else 10.0
	velocity.x = move_toward(velocity.x, target_v.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_v.z, accel * delta)
	var hs := Vector2(velocity.x, velocity.z).length()
	var locked := lock_target != null and is_instance_valid(lock_target) and not lock_target.dead and not sprinting
	if locked:
		_face_dir(lock_target.global_position - global_position, delta, 10.0)
	elif input.length() > 0.05:
		_face_dir(input, delta)
	# animation
	if not is_on_floor() and absf(velocity.y) > 1.5:
		model.play("jump" if velocity.y > 0 else "fall", 0.15)
	elif hs > 0.3:
		if locked: model.play("strafe" if absf(input.dot(facing())) < 0.6 else "walk_combat", 0.15, hs / 4.0)
		elif sprinting: model.play("sprint", 0.15)
		elif model.drawn: model.play("walk_combat" if hs < 3.0 else "run", 0.15, maxf(0.7, hs / (3.0 if hs < 3.0 else RUN)))
		else: model.play("walk" if hs < 3.0 else "run", 0.15, maxf(0.7, hs / (WALK if hs < 3.0 else RUN)))
		_steps += hs * delta
		if _steps > 1.6: _steps = 0.0; Sfx.play("step", -22.0, randf_range(0.9, 1.1))
	else:
		model.play("idle_combat" if model.drawn else "idle", 0.25)
	if not controls_enabled: return
	if Input.is_action_just_pressed("jump") and is_on_floor() and not (interact_target and Inputs.using_pad):
		velocity.y = 7.2
		model.play("jump", 0.05)
	if Input.is_action_just_released("dodge") and _dodge_held < 0.25 and is_on_floor():
		_start_roll(input)
		return
	if Input.is_action_just_pressed("guard") and is_on_floor():
		_start_guard(); return
	if buffered == "item":
		buffered = ""; _start_drink(); return
	if buffered in ["light", "heavy", "special"] and is_on_floor():
		var b := buffered
		buffered = ""
		_start_move(_entry_for(b))


var _dodge_held := 0.0
func _track_dodge(delta: float) -> void:
	if Input.is_action_pressed("dodge"): _dodge_held += delta
	elif not Input.is_action_just_released("dodge"): _dodge_held = 0.0


func _start_roll(input: Vector3) -> void:
	if not use_stam(20.0): return
	sprinting = false
	_dodge_held = 0.0
	var dir := input
	var back := false
	if dir.length() < 0.1:
		dir = -facing(); back = true
	roll_dir = dir.normalized()
	if not back: rotation.y = atan2(-roll_dir.x, -roll_dir.z)
	_set_state("roll")
	move_id = "backstep" if back else "roll"
	model.replay("backstep" if back else "roll", 0.05, 1.0 / ROLL_T * (0.62 if not back else 0.45))
	Sfx.play("dodge", -8.0)


func _st_roll(delta: float) -> void:
	var dur := ROLL_T if move_id == "roll" else 0.45
	var k := state_t / dur
	invuln = 0.05 if k > 0.05 and k < 0.6 else invuln
	var spd := lerpf(9.5 if move_id == "roll" else 7.0, 2.0, k)
	velocity.x = roll_dir.x * spd
	velocity.z = roll_dir.z * spd
	if k > 0.7 and buffered in ["light", "heavy", "special"]:
		var b := buffered; buffered = ""
		_start_move(_entry_for(b)); return
	if k > 0.8 and buffered == "dodge":
		buffered = ""; _start_roll(_move_input()); return
	if k >= 1.0: _set_state("move")


func _start_guard() -> void:
	_set_state("guard")
	guarding = true
	perfect_guard = 0.18
	model.set_drawn(true)
	combat_t = 0.0
	model.play("guard", 0.08)


func _st_guard(delta: float, input: Vector3) -> void:
	velocity.x = move_toward(velocity.x, input.x * 1.6, 30.0 * delta)
	velocity.z = move_toward(velocity.z, input.z * 1.6, 30.0 * delta)
	if lock_target and is_instance_valid(lock_target): _face_dir(lock_target.global_position - global_position, delta)
	elif input.length() > 0.1: _face_dir(input, delta, 5.0)
	if not Input.is_action_pressed("guard") or stam <= 0.0:
		guarding = false; _set_state("move"); return
	if buffered == "light" and jd["moves"].has("guard_counter") and gauge >= 50.0:
		buffered = ""; guarding = false; _start_move("guard_counter"); return
	if buffered in ["light", "heavy"] and state_t > 0.1:
		var b := buffered; buffered = ""; guarding = false; _start_move(_entry_for(b)); return
	if buffered == "dodge":
		buffered = ""; guarding = false; _start_roll(input)


## Uses a consumable immediately (from the inventory menu).
func use_item(id: String) -> void:
	if Game.count(id) <= 0 or dead: return
	var c: Dictionary = ItemData.CONSUMABLES.get(id, {})
	if c.is_empty() or c.has("revive"): return
	Game.add_item(id, -1)
	if c.has("heal"): heal(max_hp * float(c["heal"]))
	if c.has("mp"): mp = minf(max_mp, mp + float(c["mp"]))
	Sfx.play("heal", -6.0)
	if world: world.fx.burst(center(), Color(0.5, 1, 0.6), 1.5)


func _start_drink() -> void:
	var order := [Game.state.get("quick_item", "potion"), "potion", "elixir", "ether"]
	for id in order:
		if Game.count(id) > 0:
			_set_state("drink")
			move = {"item": id}
			model.set_drawn(false)
			model.replay("drink", 0.1)
			return
	if world: world.toast_small("No potions left!")


func _st_drink(delta: float, input: Vector3) -> void:
	velocity.x = input.x * 1.2; velocity.z = input.z * 1.2
	if state_t >= 1.0 and move.has("item"):
		var id: String = move["item"]
		move = {}
		var c: Dictionary = ItemData.CONSUMABLES[id]
		Game.add_item(id, -1)
		if c.has("heal"): hots.append({"hps": max_hp * float(c["heal"]) / 1.5, "time": 1.5})
		if c.has("mp"): mp = minf(max_mp, mp + float(c["mp"]))
		Sfx.play("heal", -6.0)
		if world: world.fx.burst(center(), Color(0.5, 1, 0.6), 1.5)
	if state_t >= 1.2: _set_state("move")


func _st_simple(delta: float, dur: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
	if state_t >= dur: _set_state("move")


func _st_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
	if state_t > 0.35 and state_t < 1.3: invuln = maxf(invuln, 0.05)
	if state_t > 0.9 and buffered == "dodge":
		buffered = ""; invuln = 0.3; _start_roll(_move_input()); return
	if state_t >= 1.5: _set_state("move")


func _st_dead(delta: float) -> void:
	velocity.x = 0; velocity.z = 0
	if state_t > 3.0 and world:
		world.player_fainted()
		state_t = -999.0


# --------------------------------------------------------------------------- swimming
func _update_water(delta: float) -> void:
	if world == null: return
	var wl: float = world.water_level(global_position.x, global_position.z)
	var depth := wl - global_position.y
	if not swimming and depth > 1.15 and state not in ["dead", "cutscene"]:
		swimming = true
		_set_state("swim")
		model.set_drawn(false)
		Sfx.play("splash", -4.0)
		if world: world.fx.burst(Vector3(global_position.x, wl, global_position.z), Color(0.8, 0.9, 1.0), 1.4)
	elif swimming and (depth < 0.9 and not diving) and state == "swim":
		if is_on_floor() or depth < 0.6:
			swimming = false; diving = false; _set_state("move")
	if swimming:
		if global_position.y < wl - 1.6:
			breath -= delta / (30.0 * (1.0 + float(stats.get("swim", 0.0))))
			if breath <= 0.0:
				breath = 0.0; hp -= max_hp * 0.08 * delta
				if hp <= 0.0 and not dead: dead = true; _on_death()
		else:
			breath = minf(1.0, breath + delta * 0.5)
	else:
		breath = minf(1.0, breath + delta)


func _st_swim(delta: float, input: Vector3) -> void:
	var wl: float = world.water_level(global_position.x, global_position.z)
	var fast := Input.is_action_pressed("dodge") and stam > 1.0 and input.length() > 0.1
	if fast:
		stam = maxf(0.0, stam - 10.0 * delta); stam_delay = 0.5
	var spd := SWIM * (1.8 if fast else 1.0)
	var v := input * spd
	velocity.x = move_toward(velocity.x, v.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, v.z, 10.0 * delta)
	var surface_y := wl - 1.25
	if Input.is_action_pressed("guard") and controls_enabled:
		diving = true
		velocity.y = move_toward(velocity.y, -2.8, 8.0 * delta)
	elif Input.is_action_pressed("jump") and controls_enabled:
		velocity.y = move_toward(velocity.y, 3.0, 8.0 * delta)
	elif diving:
		velocity.y = move_toward(velocity.y, 0.0, 4.0 * delta)
		if global_position.y >= surface_y - 0.05: diving = false
	else:
		velocity.y = (surface_y - global_position.y) * 4.0
	if global_position.y > surface_y and velocity.y > 0:
		velocity.y = 0.0; global_position.y = surface_y; diving = false
	if input.length() > 0.05: _face_dir(input, delta, 6.0)
	var hs := Vector2(velocity.x, velocity.z).length()
	if diving: model.play("dive", 0.25, 1.0 + hs * 0.2)
	elif hs > 0.4: model.play("swim", 0.25, 0.7 + hs * 0.15)
	else: model.play("swim_idle", 0.3)
	if randf() < delta * hs * 0.4 and not diving:
		Sfx.play("splash", -20.0, 1.4)


# --------------------------------------------------------------------------- combat
func _entry_for(input: String) -> String:
	match input:
		"light": return "L1"
		"heavy": return "H" if Vector2(velocity.x, velocity.z).length() < 4.0 or not jd["moves"].has("H2") else "H2"
		"special": return "S"
	return "L1"


func _resolve_move(id: String) -> String:
	var mv: Dictionary = jd["moves"].get(id, {})
	if mv.is_empty(): return ""
	if float(mv.get("cost", 0)) > gauge and mv.has("alt"):
		return _resolve_move(mv["alt"]) if mv["alt"] != id else ""
	if float(mv.get("cost", 0)) > gauge: return ""
	if float(mv.get("mp", 0)) > mp:
		if world: world.toast_small("Not enough MP.")
		return ""
	if float(mv.get("stam", 0)) > 0.0 and stam < float(mv["stam"]) * 0.5:
		return ""
	return id


func _start_move(id: String) -> void:
	id = _resolve_move(id)
	if id == "": return
	move_id = id
	move = jd["moves"][id]
	_set_state("attack")
	move_hit.clear()
	hit_window = -1
	charging = move.has("charge") and Input.is_action_pressed("heavy")
	charge_t = 0.0
	combat_t = 0.0
	model.set_drawn(true)
	if move.get("stam", 0.0) > 0.0: use_stam(float(move["stam"]))
	mp = clampf(mp - float(move.get("mp", 0)), 0.0, max_mp)
	gauge = clampf(gauge - float(move.get("cost", 0)), 0.0, 100.0)
	if move.get("armor", false): armor_t = float(move["dur"]) * 0.85
	if move.has("iframe"): invuln = float(move["iframe"][1])
	if lock_target and is_instance_valid(lock_target) and not lock_target.dead:
		var to := lock_target.global_position - global_position
		rotation.y = atan2(-to.x, -to.z)
	else:
		var inp := _move_input()
		if inp.length() > 0.1: rotation.y = atan2(-inp.x, -inp.z)
		else: _soft_target()
	var spd := (1.0 + buff("haste") + float(stats.get("haste", 0.0))) / float(move["dur"])
	model.replay(move["anim"], 0.06, spd)
	if move.has("heal"): _do_heal(float(move["heal"]), move.get("party_heal", false))
	if move.has("shield"): shield += max_hp * float(move["shield"])
	if move.has("buff_amount"): add_buff(move["buff"], float(move["buff_amount"]), float(move["buff_time"]))
	Sfx.play("cast" if move.has("proj") or move["anim"].begins_with("cast") else "swing", -6.0, randf_range(0.9, 1.1))
	hud_event.emit("move", move["name"])


func _soft_target() -> void:
	var best: Actor = null
	var best_d := 7.0
	for a in world.actors:
		if a.team == team or a.dead: continue
		var to = a.global_position - global_position
		var dd = to.length()
		if dd < best_d and facing().dot(to.normalized()) > 0.0:
			best_d = dd; best = a
	if best:
		var to := best.global_position - global_position
		rotation.y = atan2(-to.x, -to.z)


func _haste() -> float:
	return 1.0 + buff("haste") + float(stats.get("haste", 0.0))


func _st_attack(delta: float, input: Vector3) -> void:
	var dur: float = float(move["dur"]) / _haste()
	# charge: hold the heavy button at the wind-up pose
	if charging:
		if Input.is_action_pressed("heavy") and charge_t < float(move["charge"]):
			charge_t += delta
			state_t = minf(state_t, dur * 0.3)
			model.anim.speed_scale = 0.05
			_face_dir(input if input.length() > 0.1 else facing(), delta, 4.0)
			if world and int(charge_t * 10) % 3 == 0: world.fx.burst(model.weapon_tip(), Color(1, 0.9, 0.5), 0.3, 0.1)
			velocity.x = 0; velocity.z = 0
			return
		charging = false
		model.anim.speed_scale = _haste() / float(move["dur"])
	var k := state_t / dur
	# lunge
	var lunge: float = float(move.get("lunge", 0.6))
	var lspd := 0.0
	if k < 0.45 and lunge > 0.0:
		lspd = lunge / (dur * 0.45)
		if _enemy_close(1.1): lspd = 0.0
	var f := facing()
	velocity.x = f.x * lspd
	velocity.z = f.z * lspd
	if k < 0.25 and input.length() > 0.1 and not (lock_target and is_instance_valid(lock_target)): _face_dir(input, delta, 6.0)
	# hits
	var hits: Array = move.get("hits", [])
	for i in hits.size():
		var h: Array = hits[i]
		if state_t >= float(h[0]) / _haste() and state_t <= float(h[1]) / _haste() + 0.02:
			if hit_window != i:
				hit_window = i
				move_hit.clear()
				_swing_fx(h)
			_apply_hits(h)
	if move.has("proj") and state_t >= dur * 0.35 and hit_window != 99:
		hit_window = 99
		_fire_projectile()
	if move.has("rain") and hit_window != 98 and state_t >= dur * 0.4:
		hit_window = 98
		_rain()
	if move.get("hits", []).is_empty() and move.has("aoe") and not move.has("proj") and hit_window != 97 and state_t >= (float(move["hits_delay"]) / _haste() if move.has("hits_delay") else dur * 0.5):
		hit_window = 97
		_nova_hit()
	# chaining
	var cancel: float = float(move["cancel"]) / _haste()
	if state_t >= cancel:
		if buffered == "dodge":
			buffered = ""; _start_roll(input); return
		if buffered in ["light", "heavy", "special"]:
			var b := buffered
			buffered = ""
			var nxt: Dictionary = move.get("next", {})
			var id := ""
			if b == "light": id = nxt.get("light", "L1")
			elif b == "heavy": id = nxt.get("heavy", "H")
			else: id = "S"
			_start_move(id)
			return
		if Input.is_action_pressed("guard"):
			_start_guard(); return
	if state_t >= dur:
		_set_state("move")


func _enemy_close(dist: float) -> bool:
	for a in world.actors:
		if a.team != team and not a.dead and a.global_position.distance_to(global_position) < dist + a.radius:
			if facing().dot((a.global_position - global_position).normalized()) > 0.3: return true
	return false


func _swing_fx(h: Array) -> void:
	if world == null: return
	var col := Color("#e8f0ff")
	match move.get("elem", ""):
		"fire": col = Color("#ff8040")
		"dark": col = Color("#b050ff")
		"light": col = Color("#fff4b0")
		"lightning": col = Color("#c0a0ff")
	if float(h[2]) >= 2.0: col = col.lerp(Color("#ffd070"), 0.5)
	var tilt := {"slash_down": 90.0, "heavy_down": 90.0, "slash_up": -80.0, "heavy_up": -80.0, "slash_l": 180.0}.get(move["anim"], 0.0)
	var arc: float = float(h[4])
	if arc >= 360.0:
		world.fx.nova(global_position, float(h[3]), col, 0.3)
	else:
		world.fx.slash(center() + facing() * 0.3, facing(), col, float(h[3]), minf(arc + 40.0, 200.0), tilt)


func _apply_hits(h: Array) -> void:
	var pot: float = float(h[2]) * (1.0 + charge_t * 0.8)
	if move.get("iai", false):
		pot *= [1.0, 1.6, 2.6, 4.2][clampi(sen, 0, 3)]
		if hit_window == 0 and move_hit.is_empty():
			if sen >= 3 and world: world.toast_small("Midare Setsugekka!")
			sen = 0
	var rng: float = float(h[3]) + 0.3
	var arc: float = float(h[4])
	var any := false
	for a in world.actors:
		if a.team == team or a.dead or move_hit.has(a): continue
		var to: Vector3 = a.global_position - global_position
		to.y = 0
		var dist = to.length() - a.radius
		if dist > rng: continue
		if arc < 360.0 and dist > 0.6 and rad_to_deg(facing().angle_to(to.normalized())) > arc * 0.5: continue
		move_hit[a] = true
		_deal(a, pot)
		any = true
	if any:
		gauge = clampf(gauge + float(move.get("gain", 0)), 0.0, 100.0)
		sen = mini(3, sen + int(move.get("sen", 0)))
		var heavy := pot >= 2.0
		if world:
			world.fx.do_hitstop(0.075 if heavy else 0.035)
			if move.has("shake") or heavy: world.fx.shake(float(move.get("shake", 0.25)))
		Sfx.play("heavy" if heavy else "hit", -2.0, randf_range(0.9, 1.1))


func _deal(a: Actor, pot: float) -> void:
	var r := roll_damage(pot)
	var info := {"amount": r["amount"], "crit": r["crit"], "source": self, "elem": move.get("elem", ""),
		"stagger": float(move.get("stagger", 1.0)) * pot, "dot": float(move.get("dot", 0.0)), "base": r["amount"]}
	var res := a.take_hit(info)
	if move.get("kardia", false): _kardia(float(res.get("dealt", 0)))
	if world: world.fx.burst(a.center(), Color(1, 0.95, 0.8), 0.5 + pot * 0.15, 0.15)


func _kardia(dealt: float) -> void:
	var t: Actor = self
	var lowest := 1.0
	for p in world.party_members():
		if p.dead: continue
		var f: float = p.hp / p.max_hp
		if f < lowest: lowest = f; t = p
	t.heal(maxf(dealt * 0.35, max_hp * 0.015))


func _fire_projectile() -> void:
	var p: Dictionary = move["proj"].duplicate()
	var from := model.hand_pos(not move["anim"].ends_with("_l")) + facing() * 0.3
	if move["anim"].begins_with("shoot"): from = center() + Vector3(0, 0.35, 0) + facing() * 0.5
	var tgt := _aim_target()
	var dir := facing()
	if tgt: dir = (tgt.center() - from).normalized()
	var spread := int(p.get("spread", 1))
	var pot: float = float(move.get("potency", 1.0)) * (1.0 + charge_t * 0.8)
	var r := roll_damage(pot)
	var info := {"amount": r["amount"], "crit": r["crit"], "elem": move.get("elem", ""), "dot": float(p.get("dot", 0.0)), "base": r["amount"]}
	if p.has("slow"): info["slow"] = true
	for i in spread:
		var d := dir.rotated(Vector3.UP, deg_to_rad((i - (spread - 1) * 0.5) * 8.0))
		var pr := Projectile.spawn(world, self, from, d, p, info, tgt)
		if move.get("kardia", false): pr.info["kardia"] = true
	gauge = clampf(gauge + float(move.get("gain", 0)), 0.0, 100.0)


func _aim_target() -> Actor:
	if lock_target and is_instance_valid(lock_target) and not lock_target.dead: return lock_target
	var best: Actor = null
	var best_s := -1.0
	for a in world.actors:
		if a.team == team or a.dead: continue
		var to = a.global_position - global_position
		var dd = to.length()
		if dd > 35.0: continue
		var s = facing().dot(to.normalized()) * 2.0 - dd / 35.0
		if s > best_s and facing().dot(to.normalized()) > 0.55: best_s = s; best = a
	return best


func _nova_hit() -> void:
	var rad: float = float(move.get("aoe", 4.0))
	var col := Color(move.get("nova", "#ffffff"))
	world.fx.nova(global_position, rad, col, 0.5)
	world.fx.shake(float(move.get("shake", 0.2)))
	var pot := float(move.get("potency", 1.5))
	for a in world.actors:
		if a.team == team or a.dead: continue
		if a.global_position.distance_to(global_position) <= rad + a.radius:
			_deal(a, pot)
	if move.has("stagger"):
		for a in world.actors:
			if a.team != team and a.global_position.distance_to(global_position) <= rad: a.stun = 1.5


func _rain() -> void:
	var tgt := _aim_target()
	var c := tgt.global_position if tgt else global_position + facing() * 10.0
	var rad: float = float(move["rain"])
	world.fx.telegraph("circle", c, facing(), {"radius": rad}, 0.5, Color(0.6, 1.0, 0.7), false)
	var pot := float(move.get("potency", 1.4))
	get_tree().create_timer(0.5).timeout.connect(func():
		if not is_instance_valid(self): return
		world.fx.nova(c, rad, Color(0.7, 1.0, 0.7))
		for a in world.actors:
			if a.team != team and not a.dead and a.global_position.distance_to(c) <= rad + a.radius: _deal(a, pot))


func _do_heal(frac: float, party: bool) -> void:
	var targets: Array = world.party_members() if party else [self]
	for t in targets:
		if t.dead or t.global_position.distance_to(global_position) > 20.0: continue
		t.heal(t.max_hp * frac)
		world.fx.burst(t.center(), Color(0.6, 1.0, 0.7), 1.2, 0.4)
	Sfx.play("heal", -4.0)


# --------------------------------------------------------------------------- job actions
func use_action(i: int) -> void:
	if state in ["dead", "down", "swim", "cutscene"] or not controls_enabled: return
	var acts: Array = jd["actions"]
	if i >= acts.size() or act_cd[i] > 0.0: return
	var a: Dictionary = acts[i]
	if float(a.get("cost", 0)) > gauge:
		world.toast_small("%s needs more %s." % [a["name"], jd["gauge_name"]]); return
	if float(a.get("mp", 0)) > mp:
		world.toast_small("Not enough MP."); return
	gauge -= float(a.get("cost", 0))
	mp -= float(a.get("mp", 0))
	act_cd[i] = float(a["cd"])
	combat_t = 0.0
	model.set_drawn(true)
	hud_event.emit("move", a["name"])
	var col := Color(a.get("color", "#a0d8ff"))
	match a["kind"]:
		"buff":
			add_buff(a["buff"], float(a["amount"]), float(a["time"]))
			if a.get("armor", false): armor_t = float(a["time"])
			if a.get("party", false):
				for p in world.party_members(): p.add_buff(a["buff"], float(a["amount"]), float(a["time"]))
			if a.has("gil"): Game.add_gil(int(a["gil"]))
			world.fx.nova(global_position, 3.0, Color(1, 0.85, 0.4))
			model.replay("buff_pose", 0.08, 1.6)
		"heal":
			_do_heal(float(a["amount"]), a.get("party", false))
			model.replay("heal", 0.08, 1.4)
		"shield":
			shield += max_hp * float(a["amount"])
			world.fx.burst(center(), Color(0.7, 0.85, 1.0), 1.6, 0.5)
			model.replay("buff_pose", 0.08, 1.6)
		"regen":
			for p in world.party_members():
				p.hots.append({"hps": p.max_hp * float(a["amount"]), "time": float(a["time"])})
			world.fx.nova(global_position, 4.0, Color(0.6, 1.0, 0.7))
			model.replay("heal", 0.08, 1.4)
		"aoe":
			model.replay(a.get("anim", "spin"), 0.06, 1.6)
			var rad: float = float(a["radius"])
			world.fx.nova(global_position, rad, Color(a.get("color", "#ffd080")))
			for e in world.actors:
				if e.team != team and not e.dead and e.global_position.distance_to(global_position) <= rad + e.radius: _deal(e, float(a["pot"]))
			world.fx.shake(0.3)
		"dash", "backstep":
			var dir := facing() if a["kind"] == "dash" else -facing()
			var tgt := _aim_target()
			if a["kind"] == "dash" and tgt: dir = (tgt.global_position - global_position).normalized() * Vector3(1, 0, 1)
			var dist: float = float(a["dist"])
			if a["kind"] == "dash" and tgt: dist = minf(dist, global_position.distance_to(tgt.global_position) - tgt.radius - 0.8)
			var from := global_position
			var to := global_position + dir.normalized() * maxf(dist, 0.0)
			to.y = maxf(world.ground_height(to.x, to.z), global_position.y)
			invuln = 0.35
			var tw := create_tween()
			tw.tween_property(self, "global_position", to, 0.18)
			world.fx.beam(from + Vector3(0, 1, 0), to + Vector3(0, 1, 0), Color(0.8, 0.9, 1.0), 0.2, 0.25)
			model.replay("dash" if a["kind"] == "dash" else "backstep", 0.05)
			if float(a.get("pot", 0.0)) > 0.0 and tgt:
				tw.tween_callback(func(): if is_instance_valid(tgt): _deal(tgt, float(a["pot"])))
		"proj":
			var tgt := _aim_target()
			var from := center() + facing() * 0.6
			var dir := (tgt.center() - from).normalized() if tgt else facing()
			var r := roll_damage(float(a["pot"]))
			Projectile.spawn(world, self, from, dir, {"speed": 40.0, "radius": 0.35, "color": a.get("color", "#ffffff"), "aoe": a.get("aoe", 0.0), "homing": 4.0},
				{"amount": r["amount"], "crit": r["crit"], "dot": float(a.get("dot", 0.0)), "base": r["amount"]}, tgt)
			if a.has("mp_gain"): mp = minf(max_mp, mp + float(a["mp_gain"]))
			if a.has("gauge"): gauge = minf(100.0, gauge + float(a["gauge"]))
			model.replay("cast", 0.06, 2.0)
		"beam":
			var length: float = float(a["length"])
			var to := center() + facing() * length
			world.fx.beam(center() + facing() * 0.5, to, col, 0.5, 0.4)
			for e in world.actors:
				if e.team != team and not e.dead and FX.inside("line", global_position, facing(), {"width": 2.5, "length": length}, e.global_position, e.radius):
					_deal(e, float(a["pot"]))
			if a.has("heal"): _do_heal(float(a["heal"]), true)
			model.replay("cast", 0.06, 1.6)
			world.fx.shake(0.25)
		"zone", "zone_heal", "zone_buff":
			world.spawn_zone(self, a)
			model.replay("cast_up", 0.06, 1.6)
		"gauge":
			gauge = minf(100.0, gauge + float(a.get("amount", 0)))
			sen = maxi(sen, int(a.get("sen", 0)))
			world.fx.burst(center(), Color(1, 0.8, 0.3), 1.2)
		"mp":
			mp = minf(max_mp, mp + float(a["amount"]))
			world.fx.burst(center(), Color(0.8, 0.5, 1.0), 1.4)
		"parry":
			perfect_guard = float(a["time"])
			guarding = true
			_set_state("guard")
			model.play("guard", 0.05)
		"special_alt":
			_start_move(a["move"])
	Sfx.play("cast", -8.0, 1.2)


# --------------------------------------------------------------------------- damage reactions
func take_hit(info: Dictionary) -> Dictionary:
	if state == "cutscene": return {"miss": true}
	var r := super.take_hit(info)
	if r.get("dodged", false) and world:
		world.on_perfect_dodge()
	if r.get("perfect", false) and world:
		world.fx.burst(center() + facing() * 0.5, Color(1, 1, 0.7), 1.2)
		world.toast_small("Perfect Guard!")
		gauge = minf(100.0, gauge + 15.0)
		Sfx.play("block", 0.0, 1.3)
	elif r.get("guarded", false):
		use_stam(14.0)
		Sfx.play("block", -2.0)
		knock_vel = -facing() * 3.0
	combat_t = 0.0
	return r


func knockback(dir: Vector3, force: float, heavy: bool) -> void:
	if dead or state == "cutscene": return
	dir.y = 0
	knock_vel = dir.normalized() * force
	if armor_t > 0.0: return
	if swimming: return
	var res_st: float = float(stats.get("stagger_res", 0.0))
	if heavy and randf() > res_st:
		_set_state("down")
		guarding = false
		rotation.y = atan2(dir.x, dir.z)
		model.replay("knockdown", 0.05)
		if world: world.fx.shake(0.5)
	elif state in ["move", "attack", "drink"] and randf() > res_st:
		_set_state("hit")
		model.replay("hit", 0.05)


func _on_hurt(_info: Dictionary) -> void:
	pass


func _on_death() -> void:
	_set_state("dead")
	guarding = false
	model.play("death", 0.1)
	if world: world.toast_small("You have been knocked out!")


func revive(frac := 0.5) -> void:
	dead = false
	hp = max_hp * frac
	_set_state("move")
	invuln = 2.0
	model.play("idle", 0.3)


# --------------------------------------------------------------------------- lock-on & camera
func _toggle_lock() -> void:
	if lock_target:
		var next := _next_lock(lock_target)
		lock_target = next if next != lock_target else null
		return
	lock_target = _next_lock(null)


func _next_lock(current: Actor) -> Actor:
	var cands := []
	var cam_f := -camera.global_transform.basis.z
	for a in world.actors:
		if a.team == team or a.dead: continue
		var to = a.global_position - global_position
		if to.length() > 32.0: continue
		cands.append([a, -cam_f.dot(to.normalized()) + to.length() * 0.01])
	if cands.is_empty(): return null
	cands.sort_custom(func(x, y): return x[1] < y[1])
	if current == null: return cands[0][0]
	for i in cands.size():
		if cands[i][0] == current: return cands[(i + 1) % cands.size()][0]
	return cands[0][0]


func _update_camera(delta: float) -> void:
	if state == "cutscene" or camera == null: return
	if not camera.current: return
	var pad := Vector2(Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left"),
		Input.get_action_strength("cam_down") - Input.get_action_strength("cam_up"))
	if controls_enabled:
		_cam_rot.x -= pad.x * 2.6 * delta * float(Settings.v["sens"])
		_cam_rot.y -= pad.y * 1.8 * delta * float(Settings.v["sens"]) * (-1.0 if Settings.v["invert_y"] else 1.0)
	if lock_target and is_instance_valid(lock_target) and not lock_target.dead:
		var to := lock_target.global_position - global_position
		if to.length() > 40.0: lock_target = null
		else:
			var want := atan2(-to.x, -to.z)
			_cam_rot.x = lerp_angle(_cam_rot.x, want, clampf(5.0 * delta, 0.0, 1.0))
			_cam_rot.y = lerpf(_cam_rot.y, -0.22 - clampf(lock_target.scale.y * 0.03, 0.0, 0.2), 3.0 * delta)
	elif lock_target: lock_target = null
	_cam_rot.y = clampf(_cam_rot.y, -1.2, 0.75)
	var focus := global_position + Vector3(0, 1.55 * scale.y * model.scale.y, 0)
	if swimming: focus.y = maxf(focus.y, world.water_level(global_position.x, global_position.z) + 0.3) if not diving else focus.y
	cam_yaw.global_position = cam_yaw.global_position.lerp(focus, clampf(18.0 * delta, 0.0, 1.0))
	cam_yaw.rotation = Vector3(0, _cam_rot.x, 0)
	cam_pitch.rotation = Vector3(_cam_rot.y, 0, 0)
	var big = lock_target != null and is_instance_valid(lock_target) and lock_target.get("large") == true
	arm.spring_length = lerpf(arm.spring_length, 6.2 if big else 4.3, 2.0 * delta)
	camera.fov = lerpf(camera.fov, float(Settings.v["fov"]) + (6.0 if sprinting else 0.0), 4.0 * delta)
	var sh: float = world.fx.cam_shake if world else 0.0
	if sh > 0.0:
		camera.h_offset = randf_range(-1, 1) * sh * 0.15
		camera.v_offset = randf_range(-1, 1) * sh * 0.15
		world.fx.cam_shake = maxf(0.0, sh - delta * 2.5)
	else:
		camera.h_offset = 0.0; camera.v_offset = 0.0


func is_behind_cover(_from: Vector3) -> bool:
	return false
