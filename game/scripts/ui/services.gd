class_name Services
extends CanvasLayer
## Town service windows: guild & story, guildleves, party, meals, smithy & materia, market,
## job training, ferries and aetheryte travel. Fully navigable with a gamepad.

var world: Node
var panel: PanelContainer
var title: Label
var body: Label
var list: VBoxContainer
var _open := false


func setup(w: Node) -> void:
	world = w
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = UI.panel(Vector2(760, 560))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -380; panel.offset_right = 380; panel.offset_top = -300; panel.offset_bottom = 300
	add_child(panel)
	var v := UI.vbox(10)
	panel.add_child(v)
	title = UI.label("", 28, UI.GOLD)
	v.add_child(title)
	body = UI.label("", 19, UI.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 720
	v.add_child(body)
	list = UI.vbox(6)
	v.add_child(UI.scroll(list, Vector2(720, 360)))
	panel.visible = false


func is_open() -> bool:
	return _open


func _show(t: String, b: String) -> void:
	_open = true
	panel.visible = true
	title.text = t
	body.text = b
	UI.clear(list)
	world.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _add(text: String, cb: Callable, enabled := true) -> Button:
	var b := UI.button(text, cb)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(b)
	return b


func _finish_list() -> void:
	_add("Close", close)
	UI.focus_first(list)


func close() -> void:
	_open = false
	panel.visible = false
	world.player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for it in world.interactables:
		if it.get("node") is NPC: it["node"].refresh_marker()


func _input(e: InputEvent) -> void:
	if _open and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ------------------------------------------------------------------ dispatch
func talk(npc: NPC) -> void:
	match npc.role:
		"guildmaster": _guild(npc)
		"leves": _leves()
		"recruiter": _recruiter()
		"inn": _meals()
		"smith": _smith()
		"market": _market()
		"trainer": _trainer()
		"side": _side(npc)
		"ferry": _ferry()
		_: _chat(npc)


func _chat(npc: NPC) -> void:
	world.player.controls_enabled = false
	npc.model.talking = true
	await world.dialogue.say(npc.npc_name, npc.line())
	npc.model.talking = false
	world.dialogue.close()
	world.player.controls_enabled = true


func _intro_in_town(cs: String) -> bool:
	if cs == "" or not Data.cutscenes.has(cs): return false
	for c in Data.cutscenes[cs]:
		if c["cmd"] == "spawn" and c["id"] == "gm": return true
	return false


func _guild(npc: NPC) -> void:
	var q := Game.current_msq()
	var gm: String = StoryData.GUILDS[Game.city()]["gm"]
	var home = world.zone_id == Game.city()
	if not q.is_empty() and q["kind"] == "talk" and q.get("talk", "") == npc.cast_id:
		var outro: String = q.get("outro", "")
		var rew := Game.complete_msq()
		if outro != "":
			await world.cutscene.play(outro)
		world.hud.banner("QUEST COMPLETE", q["name"] + "\n" + rew)
		return
	if not q.is_empty() and q["kind"] != "talk" and home:
		_show(q["name"], "%s\n\nRecommended level %d.  Remember to eat before you depart!" % [q["desc"], int(q.get("lvl", 1))])
		_add("Depart for %s" % Data.zones[q["zone"]]["name"], func():
			close()
			if _intro_in_town(q.get("intro", "")):
				await world.cutscene.play(q["intro"])
				var qq := q.duplicate(); qq["intro"] = ""
				Game.depart(qq)
			else:
				Game.depart(q))
		_add("Order a meal first", _meals)
		_finish_list()
		return
	if q.is_empty() or Game.flag("story_complete"):
		_show(StoryData.CAST[gm]["name"], "Back again? The board's full and the roads are long. Take a leve, or see the recruiter if you want company out there.")
	else:
		_show(StoryData.CAST[gm]["name"], "Your next task: %s\n\n%s" % [q["name"], q["desc"]])
	_finish_list()


func _leves() -> void:
	if not Game.flag("leves"):
		_show("Levemete", Game.fmt("Speak with <gmname> before taking guildleves, adventurer."))
		_finish_list(); return
	_show("Guildleves", "Choose a contract. Leves carry no story, only coin, experience and materials.\nMeal: " + _meal_text())
	for lq in Game.make_leves():
		var l: Dictionary = lq
		_add("%s  (%s, Lv.%d)  -  %d gil" % [l["name"], Data.zones[l["zone"]]["name"], int(l["lvl"]), int(l["reward"]["gil"])], func():
			_show(l["name"], "%s\n\nReward: %d gil, %d EXP" % [l["desc"], int(l["reward"]["gil"]), int(l["reward"]["xp"])])
			_add("Depart", func(): close(); Game.depart(l))
			_add("Back", _leves)
			UI.focus_first(list))
	_finish_list()


func _meal_text() -> String:
	var m: Dictionary = Game.state.get("meal", {})
	if m.is_empty(): return "none (eat at the kitchen!)"
	var parts := []
	for s in ["main", "side", "drink"]:
		if m.has(s): parts.append(Data.meal(s, m[s])["name"])
	return ", ".join(parts)


func _recruiter() -> void:
	if Game.msq_index() < 3:
		_show("Party Recruiter", "Adventurers here only team up with those the guild trusts. Prove yourself on the road first.")
		_finish_list(); return
	var party: Array = Game.state["party"]
	_show("Party Recruiter", "Hire adventurers once, then choose up to three to bring along.\nParty: %d/3" % party.size())
	for r in ItemData.RECRUITS:
		var rec: Dictionary = r
		var have: bool = rec["id"] in Game.state["recruited"]
		var inp: bool = rec["id"] in party
		var label := "%s  -  %s Lv.%d" % [rec["name"], Data.jobs[rec["job"]]["name"], int(rec["level"])]
		if not have:
			var ok: bool = Game.level() >= int(rec["level"]) - 2 and int(Game.state["gil"]) >= int(rec["cost"])
			_add(label + "   Hire: %d gil" % int(rec["cost"]), func():
				Game.add_gil(-int(rec["cost"])); Game.state["recruited"].append(rec["id"])
				if party.size() < 3: party.append(rec["id"])
				Sfx.play("coin"); _recruiter(), ok)
		elif inp:
			_add(label + "   [In party] Dismiss", func(): party.erase(rec["id"]); _recruiter())
		else:
			_add(label + "   Invite", func(): party.append(rec["id"]); _recruiter(), party.size() < 3)
	_finish_list()


func _meals() -> void:
	_show("Kitchen", "A hunter fights on a full stomach. Pick one main dish, one side and one drink.\nEffects last for your next quest or leve.\nCurrent: " + _meal_text())
	for slot in ["main", "side", "drink"]:
		list.add_child(UI.label(ItemData.MEAL_SLOTS[slot], 20, UI.GOLD))
		for m in ItemData.MEALS[slot]:
			var md: Dictionary = m
			var cur: bool = Game.state.get("meal", {}).get(slot, "") == md["id"]
			_add("%s%s  (%d gil)  -  %s" % ["✓ " if cur else "", md["name"], int(md["price"]), md["desc"]], func():
				if int(Game.state["gil"]) < int(md["price"]): world.toast_small("Not enough gil."); return
				Game.add_gil(-int(md["price"]))
				Game.state["meal"][slot] = md["id"]
				Game.state_changed.emit()
				Sfx.play("coin", -4.0)
				world.toast_small("You enjoy the %s." % md["name"])
				_meals(), not cur)
	_finish_list()


func _smith() -> void:
	var j := Game.job()
	var w: Dictionary = Game.state["weapons"][j]
	var tier := int(w["tier"])
	_show("Smithy & Materia Melder", "Weapon: %s (+%d attack, %d materia slots)\nGil: %d" % [Data.weapon_name(j, tier), int(ItemData.WEAPON_TIERS[tier]["atk"]), Game.materia_slots_weapon(), int(Game.state["gil"])])
	if tier + 1 < ItemData.WEAPON_TIERS.size():
		var nt: Dictionary = ItemData.WEAPON_TIERS[tier + 1]
		var ok: bool = int(Game.state["gil"]) >= int(nt["cost"]) and Game.has_mats(nt["mats"])
		_add("Upgrade to %s  -  %d gil, %s" % [Data.weapon_name(j, tier + 1), int(nt["cost"]), _mats_text(nt["mats"])], func():
			Game.add_gil(-int(nt["cost"])); Game.spend_mats(nt["mats"]); w["tier"] = tier + 1
			world.player.rebuild(); Sfx.play("levelup", -4.0); _smith(), ok)
	for slot in ["head", "body", "legs", "feet"]:
		var at := int(Game.state["armor"][slot])
		if at + 1 < ItemData.ARMOR_SETS.size():
			var ns: Dictionary = ItemData.ARMOR_SETS[at + 1]
			var ok2: bool = int(Game.state["gil"]) >= int(ns["cost"]) and Game.has_mats(ns["mats"])
			var s = slot
			_add("%s: %s -> %s %s  -  %d gil %s" % [ItemData.ARMOR_SLOTS[s], ItemData.ARMOR_SETS[at]["name"] if at >= 0 else "None", ns["name"], ItemData.ARMOR_SLOTS[s],
				int(ns["cost"]), _mats_text(ns["mats"])], func():
				Game.add_gil(-int(ns["cost"])); Game.spend_mats(ns["mats"]); Game.state["armor"][s] = at + 1
				world.player.rebuild(); Sfx.play("coin"); _smith(), ok2)
	_add("Dye armour", _dyes)
	_add("Materia: meld & craft", _materia)
	_finish_list()


func _mats_text(m: Dictionary) -> String:
	var p := []
	for k in m: p.append("%s %d/%d" % [Data.item_name(k), Game.count(k), int(m[k])])
	return ", ".join(p)


func _dyes() -> void:
	_show("Dyes", "Choose a slot, then a dye colour (50 gil).")
	var colors := ["", "#f2f0ea", "#1d1a1a", "#7a1f1f", "#c0482d", "#c9a227", "#2f6b4f", "#3c5a8a", "#6a3d8f", "#d86ca0", "#8a5a3a", "#9aa3ad"]
	for slot in ["head", "body", "legs", "feet"]:
		if int(Game.state["armor"][slot]) < 0: continue
		list.add_child(UI.label(ItemData.ARMOR_SLOTS[slot], 18, UI.GOLD))
		var s = slot
		list.add_child(UI.swatches(colors.slice(1), Game.state["dyes"].get(s, ""), func(c):
			if int(Game.state["gil"]) < 50: return
			Game.add_gil(-50); Game.state["dyes"][s] = c; world.player.rebuild(); _dyes(), 11))
		_add("Remove dye (%s)" % ItemData.ARMOR_SLOTS[s], func(): Game.state["dyes"][s] = ""; world.player.rebuild(); _dyes())
	_add("Back", _smith)
	UI.focus_first(list)


func _materia() -> void:
	var owned: Array = Game.state["materia"]
	var j := Game.job()
	var wm: Array = Game.state["weapons"][j]["materia"]
	var lines := "Weapon materia (%d/%d): %s" % [wm.size(), Game.materia_slots_weapon(), ", ".join(wm.map(func(m): return _mname(m))) if not wm.is_empty() else "none"]
	_show("Materia", lines + "\nFaded fragments: %d (3 craft one materia)" % Game.count("materia_shard"))
	_add("Craft materia from 3 fragments", func():
		Game.add_item("materia_shard", -3)
		var types := ItemData.MATERIA.keys()
		var g := clampi(int(Game.level() / 12) + (1 if randf() < 0.3 else 0), 0, 4)
		var m := {"type": types[randi() % types.size()], "grade": g}
		owned.append(m)
		world.toast_small("Crafted " + _mname(m))
		_materia(), Game.count("materia_shard") >= 3)
	for i in owned.size():
		var m: Dictionary = owned[i]
		var idx := i
		_add("Meld %s into weapon" % _mname(m), func():
			wm.append(owned[idx]); owned.remove_at(idx); Game.state_changed.emit(); Sfx.play("cast", -4.0); _materia(), wm.size() < Game.materia_slots_weapon())
		for slot in ["head", "body", "legs", "feet"]:
			var am: Array = Game.state["armor_materia"][slot]
			var s = slot
			if int(Game.state["armor"][slot]) >= 0 and am.is_empty():
				_add("   ...or into %s armour" % ItemData.ARMOR_SLOTS[s], func():
					am.append(owned[idx]); owned.remove_at(idx); Game.state_changed.emit(); _materia())
	if not wm.is_empty():
		_add("Retrieve all weapon materia", func(): owned.append_array(wm); wm.clear(); Game.state_changed.emit(); _materia())
	_add("Back", _smith)
	UI.focus_first(list)


func _mname(m: Dictionary) -> String:
	return "%s %s" % [ItemData.MATERIA[m["type"]]["name"], ItemData.MATERIA_GRADES[int(m["grade"])]]


func _market() -> void:
	_show("Market", "Gil: %d" % int(Game.state["gil"]))
	list.add_child(UI.label("Buy", 20, UI.GOLD))
	for id in ItemData.CONSUMABLES:
		var c: Dictionary = ItemData.CONSUMABLES[id]
		var i: String = id
		_add("%s  -  %d gil   (owned %d)" % [c["name"], int(c["price"]), Game.count(i)], func():
			Game.add_gil(-int(c["price"])); Game.add_item(i, 1); Sfx.play("coin", -6.0); _market(), int(Game.state["gil"]) >= int(c["price"]))
	list.add_child(UI.label("Sell materials", 20, UI.GOLD))
	for id in Game.state["inventory"]:
		if not ItemData.MATERIALS.has(id): continue
		var i: String = id
		_add("%s x%d  -  sell one for %d gil" % [Data.item_name(i), Game.count(i), int(ItemData.MATERIALS[i]["price"])], func():
			Game.add_item(i, -1); Game.add_gil(int(ItemData.MATERIALS[i]["price"])); Sfx.play("coin", -8.0); _market())
	_finish_list()


func _trainer() -> void:
	var cost := Game.unlock_job_cost()
	_show("Job Training", "Every discipline welcomes you, but learning a new one takes coin and some experience (level 5+).\nNew job cost: %d gil" % cost)
	for j in Data.jobs:
		var jj: String = j
		var jd: Dictionary = Data.jobs[j]
		var have: bool = Game.state["jobs"].has(jj)
		if have:
			_add("%s  Lv.%d  (%s)%s" % [jd["name"], Game.level(jj), UI_ROLE(jd["role"]), "  [current]" if jj == Game.job() else "  -  Switch"], func():
				Game.switch_job(jj); world.player.rebuild(); world.hud._refresh_hotbar(); _trainer(), jj != Game.job())
		else:
			_add("%s  (%s, %s weapon)  -  Learn" % [jd["name"], UI_ROLE(jd["role"]), ItemData.WEAPON_NAMES[jd["weapon"]]], func():
				if Game.unlock_job(jj): _trainer(), Game.level() >= 5 and int(Game.state["gil"]) >= cost)
	_finish_list()


static func UI_ROLE(r: String) -> String:
	return JobData.ROLE_NAMES[r]


func _side(npc: NPC) -> void:
	var q: Dictionary = {}
	for s in StoryData.SIDE:
		if s["id"] == npc.quest_id: q = s
	if q.is_empty() or q["id"] in Game.state["quests_done"]:
		_chat(npc); return
	_show(q["name"], "%s:\n\"%s\"\n\nReward: %d gil, %d EXP" % [npc.npc_name, q["desc"], int(q["reward"]["gil"]), int(q["reward"]["xp"])])
	_add("Accept and depart for %s" % Data.zones[q["zone"]]["name"], func(): close(); Game.depart(q))
	_finish_list()


func _ferry() -> void:
	var f: Dictionary = world.zd.get("ferry", {})
	if f.is_empty(): close(); return
	_show("Ferry", "%s  -  120 gil" % f["name"])
	_add("Board (%s)" % Data.zones[f["to"]]["name"], func():
		Game.add_gil(-120); close(); world.ferry(f["to"]), int(Game.state["gil"]) >= 120)
	_finish_list()


func open_teleport() -> void:
	_show("Aetheryte", "Rest to recover fully (foes in the area return, and your journey is saved), or travel to an attuned aetheryte (80 gil).")
	_add("Rest at the aetheryte", func():
		close()
		world.rest_at_aetheryte())
	for z in Game.state["attuned"]:
		var zz: String = z
		if zz == world.zone_id: continue
		_add("%s  (%s)" % [Data.zones[zz]["aetheryte"], Data.zones[zz]["name"]], func():
			Game.add_gil(-80); close(); world.teleport(zz), int(Game.state["gil"]) >= 80)
	_finish_list()
