class_name Cutscene
extends Node
## Plays scripted scenes from StoryData: camera shots, actors, dialogue and effects.
## Positions are relative to an anchor (the player's position and facing when the scene starts).
## Press Menu/Cancel to skip; story-state commands still apply when skipped.

var world: Node
var active := false
var cam: Camera3D
var actors := {}
var anchor := Transform3D()
var skipping := false
var _hidden: Array = []   # standing NPCs hidden while their scripted double is on stage
var _flash: ColorRect
var _title: Label
var _title_sub: Label
var _layer: CanvasLayer
var _skip_hint: Label


func setup(w: Node) -> void:
	world = w
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.far = 900.0
	w.add_child(cam)
	_layer = CanvasLayer.new(); _layer.layer = 7; add_child(_layer)
	_flash = ColorRect.new(); _flash.set_anchors_preset(Control.PRESET_FULL_RECT); _flash.color = Color(1, 1, 1, 0); _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)
	var r := UI.screen_root()
	_layer.add_child(r)
	var tv := UI.vbox(10)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = UI.label("", 72, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.modulate.a = 0.0
	_title_sub = UI.label("", 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title_sub.modulate.a = 0.0
	tv.add_child(_title); tv.add_child(_title_sub)
	UI.fit(r, tv, Vector2(0.5, 0.45), Vector4(24, 100, 24, 100))
	_skip_hint = UI.label("", 15, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	UI.fit(r, _skip_hint, Vector2(1.0, 0.0), Vector4(16, 100, 20, 16))


func play(id: String) -> void:
	await play_cmds(Data.cutscenes[id])


func play_cmds(cmds: Array) -> void:
	if active: return
	active = true
	skipping = false
	var p: Player = world.player
	p.controls_enabled = false
	p._set_state("cutscene")
	p.velocity = Vector3.ZERO
	p.model.set_drawn(false)
	p.lock_target = null
	anchor = Transform3D(Basis(Vector3.UP, p.rotation.y), p.global_position)
	cam.global_transform = p.camera.global_transform
	cam.fov = p.camera.fov
	cam.current = true
	_skip_hint.text = "[%s] Skip" % Inputs.glyph("menu")
	for i in cmds.size():
		var c: Dictionary = cmds[i]
		if c["cmd"] == "goto_city":
			Game.goto_zone(Game.city(), Vector3(0, 0, -14), {"cutscene_cmds": cmds.slice(i + 1)})
			return
		await _run(c)
	_finish()


## The character a shot is aimed at (by id, or the one nearest the aim point), or null.
func _face_model(look: Vector3, spec) -> CharModel:
	if spec is String:
		var m = _model(spec)
		return m if m is CharModel else null
	if look.y - anchor.origin.y > 2.6: return null   # deliberate sky/monster shots
	var best: CharModel = null
	var best_d := 1.8
	var cands: Array = [world.player.model]
	for k in actors:
		if actors[k] is CharModel and is_instance_valid(actors[k]): cands.append(actors[k])
	for m in cands:
		var d := Vector2(m.global_position.x - look.x, m.global_position.z - look.z).length()
		if d < best_d: best_d = d; best = m
	return best


func _finish() -> void:
	world.player.model.set_expression("neutral")
	for n in _hidden:
		if is_instance_valid(n): n.visible = true
	_hidden.clear()
	for k in actors:
		if is_instance_valid(actors[k]): actors[k].queue_free()
	actors.clear()
	world.dialogue.close()
	world.hud.letterbox(false)
	world.hud.fade_in(0.4)
	Engine.time_scale = 1.0
	_skip_hint.text = ""
	_title.modulate.a = 0.0; _title_sub.modulate.a = 0.0
	var p: Player = world.player
	p.camera.current = true
	p.controls_enabled = true
	p._set_state("move")
	p.model.talking = false
	active = false
	for it in world.interactables:
		if it.get("node") is NPC: it["node"].refresh_marker()


func _input(e: InputEvent) -> void:
	if active and (e.is_action_pressed("menu") or e.is_action_pressed("ui_cancel")) and not skipping:
		skipping = true
		Engine.time_scale = 1.0
		world.dialogue.advanced.emit()
		get_viewport().set_input_as_handled()


func _wait(t: float) -> void:
	if skipping or t <= 0.0: return
	await get_tree().create_timer(t, true, false, false).timeout


func _rel(v) -> Vector3:
	if v is Array: return anchor * Vector3(v[0], v[1], v[2])
	return anchor.origin


func _actor_pos(id: String) -> Vector3:
	if id == "player": return world.player.global_position
	if actors.has(id) and is_instance_valid(actors[id]): return actors[id].global_position
	return anchor.origin


func _model(id: String) -> Node3D:
	if id == "player" or id == "<player>": return world.player.model
	return actors.get(id)


func _speaker(who: String) -> Array:
	match who:
		"<player>": return [Game.state["name"], world.player.model]
		"villager": return [ZoneData.STARTS[Game.city()]["villager"].split(",")[0], actors.get("villager")]
		"gm":
			var gm: String = StoryData.GUILDS[Game.city()]["gm"]
			return [StoryData.CAST[gm]["name"], actors.get("gm")]
		"wol":
			return [Game.state["wol"].get("name", "Warrior of Light"), actors.get("wol")]
	if StoryData.CAST.has(who): return [StoryData.CAST[who]["name"], actors.get(who)]
	if actors.has(who): return [who.capitalize(), actors[who]]
	return [Game.fmt(who), null]


func _spawn(c: Dictionary) -> void:
	var look: String = c["look"]
	var n: Node3D
	if look.begins_with("monster:"):
		var sp := look.substr(8)
		if sp == "<small_big>": sp = Data.zone_large(world.zone_id)
		var rig := MonsterBuilder.build(Data.monsters[sp])
		n = Node3D.new()
		n.add_child(rig["root"])
		rig["root"].rotation.y = PI
		n.set_meta("rig", rig)
		if c.has("tint"):
			for mi in _meshes(rig["root"]):
				var m := StandardMaterial3D.new(); m.albedo_color = Color(c["tint"]); m.roughness = 0.5
				m.emission_enabled = true; m.emission = Color("#6020c0"); m.emission_energy_multiplier = 0.2
				mi.material_override = m
	else:
		var cm := CharModel.new()
		var ap: Dictionary
		var gear := {"armor": {"body": 0, "legs": 0, "feet": 0}}
		var job := ""
		match look:
			"villager":
				var vl: Array = ZoneData.STARTS[Game.city()]["villager_look"]
				ap = RaceData.default_appearance(vl[0], vl[1], vl[2]); ap["hair_style"] = 1; ap["hair_color"] = "#6b4a32"
			"<gm>":
				for it in world.interactables:
					var nn = it.get("node")
					if nn is NPC and nn.role == "guildmaster":
						nn.visible = false; _hidden.append(nn)
				var gm: String = StoryData.GUILDS[Game.city()]["gm"]
				ap = Data.cast_appearance(gm); job = StoryData.CAST[gm]["look"][6]
				gear["dyes"] = {"body": ap["dye_top"], "legs": ap["dye_bottom"]}; gear["armor"] = {"body": 2, "legs": 1, "feet": 1}
			"wol":
				ap = Game.state["wol"]["appearance"]; job = Game.state["wol"].get("job", "PLD")
				gear = {"armor": {"body": 6, "legs": 6, "feet": 6}, "dyes": {"body": "#e8e4f0", "legs": "#3a3a4a", "feet": "#2a2a30"}, "tier": 6}
			"bandit", "guard":
				ap = NPC.random_look(randi())
				gear = {"armor": {"body": 1 if look == "bandit" else 3, "legs": 1, "feet": 1}, "dyes": {"body": "#5a3a2a" if look == "bandit" else ""}}
				job = "WAR" if look == "bandit" else "PLD"
			_:
				ap = Data.cast_appearance(look); job = StoryData.CAST[look]["look"][6]
				gear = {"armor": {"body": 4, "legs": 4, "feet": 4}, "dyes": {"body": ap["dye_top"], "legs": ap["dye_bottom"], "feet": "#202020"}}
		if job != "" and c.get("weapon", false):
			gear["weapon"] = Data.jobs[job]["weapon"]; gear["tier"] = gear.get("tier", 5)
		cm.build(ap, gear)
		if c.get("weapon", false): cm.set_drawn(true)
		n = cm
	world.add_child(n)
	var pos := _rel(c["pos"])
	if c["pos"][1] == 0: pos.y = world.ground_height(pos.x, pos.z)
	n.global_position = pos
	if c.has("scale"): n.scale *= float(c["scale"])
	actors[c["id"]] = n
	_face(n, c.get("face", "player"))
	if n is CharModel: n.play("idle_combat" if c.get("weapon", false) else "idle", 0.0)


func _meshes(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch is MeshInstance3D: out.append(ch)
		out.append_array(_meshes(ch))
	return out


func _face(n: Node3D, f) -> void:
	var target: Vector3
	if f is String:
		target = _actor_pos(f)
	else:
		n.rotation.y = anchor.basis.get_euler().y + float(f); return
	var d := target - n.global_position
	d.y = 0
	if d.length() > 0.01: n.rotation.y = atan2(-d.x, -d.z)


func _run(c: Dictionary) -> void:
	var hud: HUD = world.hud
	match c["cmd"]:
		"black":
			hud.set_black()
		"letterbox":
			hud.letterbox(c["on"])
		"fade_in":
			hud.fade_in(0.05 if skipping else float(c.get("t", 1.0)))
			await _wait(float(c.get("t", 1.0)))
		"fade_out":
			hud.fade_out(0.05 if skipping else float(c.get("t", 1.0)))
			await _wait(float(c.get("t", 1.0)))
		"title":
			if skipping: return
			_title.text = Game.fmt(c["text"]); _title_sub.text = Game.fmt(c.get("sub", ""))
			var tw := create_tween()
			tw.tween_property(_title, "modulate:a", 1.0, 0.8); tw.parallel().tween_property(_title_sub, "modulate:a", 1.0, 1.2)
			await _wait(3.0)
			var tw2 := create_tween()
			tw2.tween_property(_title, "modulate:a", 0.0, 0.8); tw2.parallel().tween_property(_title_sub, "modulate:a", 0.0, 0.8)
			await _wait(0.8)
		"player_anim":
			world.player.model.play(c["anim"], 0.3)
		"spawn":
			_spawn(c)
		"despawn":
			if actors.has(c["id"]) and is_instance_valid(actors[c["id"]]): actors[c["id"]].queue_free()
			actors.erase(c["id"])
		"move":
			var n: Node3D = actors.get(c["id"])
			if n == null: return
			var to := _rel(c["to"])
			if c["to"][1] == 0: to.y = world.ground_height(to.x, to.z)
			var d := to - n.global_position
			if Vector2(d.x, d.z).length() > 0.05: n.rotation.y = atan2(-d.x, -d.z)
			if n is CharModel: n.play(c.get("anim", "walk"), 0.15)
			if skipping:
				n.global_position = to
			else:
				var tw := create_tween()
				tw.tween_property(n, "global_position", to, float(c["t"]))
				await tw.finished
			if n is CharModel: n.play("idle", 0.25)
		"expr":
			var em = _model(c["id"])
			if em is CharModel: em.set_expression(c["expr"])
		"anim":
			var n = _model(c["id"])
			if n is CharModel: n.play(c["anim"], 0.2)
			elif n and n.has_meta("rig"): _rig_roar(n)
		"cam":
			var pos := _rel(c["pos"])
			var look := _rel(c["look"]) if c["look"] is Array else _actor_pos(c["look"])
			# Frame the real face: if the shot aims near a character, retarget to their head and
			# keep the camera's angle, so height, race size and uneven ground never cut them out.
			var fm := _face_model(look, c["look"])
			if fm:
				var face := fm.head_pos()
				pos.y += face.y - look.y
				# Small speakers (e.g. Lalafell) get a proportionally closer shot.
				var k := clampf(fm.scale.y, 0.6, 1.2)
				pos = face + (pos - face) * k
				look = face
				pos = world.clear_shot(face, pos)
			pos.y = maxf(pos.y, world.ground_height(pos.x, pos.z) + 0.35)
			var xf := Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
			var t := float(c.get("t", 0.0))
			if t <= 0.0 or skipping:
				cam.global_transform = xf
				cam.fov = float(c.get("fov", cam.fov))
			else:
				var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(cam, "global_transform", xf, t)
				tw.parallel().tween_property(cam, "fov", float(c.get("fov", cam.fov)), t)
				await tw.finished
		"say":
			if skipping: return
			var sp := _speaker(c["who"])
			var m = sp[1]
			if m is CharModel and c.has("expr"): m.set_expression(c["expr"])
			await world.dialogue.say(sp[0], Game.fmt(c["text"]), m if m is CharModel else null)
			if not is_instance_valid(self): return
		"wait":
			await _wait(float(c["t"]))
		"fx":
			if skipping: return
			var col := Color(c.get("color", "#ffffff"))
			match c["kind"]:
				"flash":
					_flash.color = Color(col, 0.9)
					create_tween().tween_property(_flash, "color:a", 0.0, 0.6)
				"shake":
					world.fx.cam_shake = float(c.get("amount", 0.5))
					_shake_cam(float(c.get("amount", 0.5)))
				"burst":
					world.fx.burst(_actor_pos(c["at"]) + Vector3(0, 1.0, 0), col, 3.0, 0.5)
					Sfx.play("boom", -2.0)
				"nova":
					world.fx.nova(_actor_pos(c["at"]), 7.0, col, 0.8)
					Sfx.play("cast", 0.0, 0.7)
				"teleport":
					var at := _actor_pos(c["at"])
					world.fx.beam(at, at + Vector3(0, 12, 0), col, 0.8, 0.7)
					world.fx.burst(at + Vector3(0, 1, 0), col, 2.5, 0.5)
					Sfx.play("cast", -2.0, 1.4)
		"slowmo":
			Engine.time_scale = 1.0 if skipping else float(c["scale"])
			await _wait(float(c.get("t", 0.0)))
		"attack":
			if skipping: return
			var n: CharModel = actors.get(c["id"])
			var tgt := _actor_pos(c["target"])
			if n == null: return
			var d := tgt - n.global_position
			d.y = 0
			n.rotation.y = atan2(-d.x, -d.z)
			var close := tgt - d.normalized() * 1.8
			close.y = n.global_position.y
			var tw := create_tween()
			tw.tween_property(n, "global_position", close, 0.15)
			n.replay(c["anim"], 0.04, 2.2)
			await tw.finished
			await _wait(0.12)
			var col := Color(c.get("color", "#ffffff"))
			world.fx.slash(n.global_position + Vector3(0, 1.1, 0), -n.global_transform.basis.z, col, 3.0, 160.0, randf_range(-40, 40))
			world.fx.burst(tgt + Vector3(0, 1.0, 0), col, 1.8, 0.25)
			world.fx.do_hitstop(0.05)
			Sfx.play("heavy", 0.0)
			_shake_cam(0.25)
			var victim = actors.get(c["target"])
			if victim is CharModel: victim.replay("hit", 0.05)
			await _wait(0.3)
		"cast":
			if skipping: return
			var n: CharModel = actors.get(c["id"])
			if n == null: return
			n.replay("cast_up" if c.get("big", false) else "cast", 0.06, 1.5)
			await _wait(0.35)
			var from := n.global_position + Vector3(0, 1.4, 0)
			var to := _actor_pos(c["target"]) + Vector3(0, 1.0, 0)
			world.fx.beam(from, to, Color(c["color"]), 0.5 if c.get("big", false) else 0.25, 0.5)
			world.fx.burst(to, Color(c["color"]), 3.0, 0.4)
			Sfx.play("boom", 0.0, 1.2)
			await _wait(0.3)
		"kill":
			var n: Node3D = actors.get(c["id"])
			if n == null: return
			if n is CharModel: n.play("death", 0.1)
			else:
				var tw := create_tween()
				tw.tween_property(n, "rotation:z", 1.5, 0.6)
				tw.parallel().tween_property(n, "position:y", n.position.y - 0.4, 0.6)
				world.fx.nova(n.global_position, 8.0, Color("#ffffff"), 0.8)
			await _wait(0.8)
		"flee":
			for id in c["ids"]:
				var n: CharModel = actors.get(id)
				if n == null: continue
				var away := (n.global_position - anchor.origin)
				away.y = 0
				var to := n.global_position + away.normalized() * 18.0
				n.rotation.y = atan2(-away.x, -away.z)
				n.play("sprint", 0.1)
				var tw := create_tween(); tw.tween_property(n, "global_position", to, 1.4)
			await _wait(0.8)
		"limit_break":
			if skipping: return
			var n: CharModel = actors.get(c["id"])
			if n == null: return
			var start := n.global_position
			var tgt := _actor_pos(c["target"])
			world.fx.nova(start, 6.0, Color("#9fe0ff"), 1.0)
			n.play("leap", 0.05, 0.6)
			var tw := create_tween()
			tw.tween_property(n, "global_position", start + Vector3(0, 6, 0), 0.6).set_ease(Tween.EASE_OUT)
			await tw.finished
			_flash.color = Color(0.8, 0.95, 1.0, 0.8)
			create_tween().tween_property(_flash, "color:a", 0.0, 0.8)
			world.fx.beam(n.global_position, tgt + Vector3(0, 1, 0), Color("#e0f6ff"), 1.6, 0.9)
			world.fx.nova(tgt, 14.0, Color("#bfefff"), 1.2)
			world.fx.burst(tgt + Vector3(0, 2, 0), Color("#ffffff"), 9.0, 0.9)
			Sfx.play("boom", 4.0, 0.6)
			_shake_cam(1.2)
			var tw2 := create_tween()
			tw2.tween_property(n, "global_position", tgt - (tgt - start).normalized() * 3.0, 0.25)
			n.replay("heavy_down", 0.04, 1.6)
			await _wait(1.2)
		"sky":
			world.set_storm(c["mood"] == "storm")
		"equip_starter":
			Game.state["armor"]["body"] = 0
			Game.state["armor"]["legs"] = 0
			world.player.rebuild()
			world.player._set_state("cutscene")
		"heal_player":
			Game.state["hp_frac"] = 1.0
			world.player.hp = world.player.max_hp
		"unlock":
			Game.set_flag(c["what"])
		"end":
			pass


func _shake_cam(amount: float) -> void:
	if skipping: return
	var base := cam.global_transform
	var tw := create_tween()
	for i in 6:
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * amount * 0.12 * (1.0 - i / 6.0)
		tw.tween_property(cam, "global_transform", base.translated_local(off), 0.035)
	tw.tween_property(cam, "global_transform", base, 0.05)


func _rig_roar(n: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(n, "scale", n.scale * 1.08, 0.25)
	tw.tween_property(n, "scale", n.scale, 0.4)
	Sfx.play("roar", 0.0, 0.7)
