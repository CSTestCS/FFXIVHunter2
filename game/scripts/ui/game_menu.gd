class_name GameMenu
extends CanvasLayer
## Pause menu: character, items, gear, journal, party, settings, save/load (multiple slots), quit.
## Tabs switch with Z/X or LB/RB.

var world: Node
var tabs: TabContainer
var root: Control


func setup(w: Node) -> void:
	world = w
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(1120, 680)
	UI.fit(root, tabs, Vector2(0.5, 0.5))
	visible = false


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu") or (e.is_action_pressed("journal") and not visible):
		if world.cutscene.active or world.services.is_open() or world.dialogue.active: return
		get_viewport().set_input_as_handled()
		if visible: close()
		else: open(2 if e.is_action_pressed("journal") else 0)
	elif visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled(); close()
	elif visible and e.is_action_pressed("tab_next"):
		tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count(); _focus_tab()
	elif visible and e.is_action_pressed("tab_prev"):
		tabs.current_tab = (tabs.current_tab - 1 + tabs.get_tab_count()) % tabs.get_tab_count(); _focus_tab()


func open(tab := 0) -> void:
	visible = true
	await _rebuild()
	tabs.current_tab = clampi(tab, 0, tabs.get_tab_count() - 1)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_tab()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _focus_tab() -> void:
	UI.focus_first(tabs.get_current_tab_control())


func _page(name: String) -> VBoxContainer:
	var v := UI.vbox(8)
	v.name = name
	var sc := UI.scroll(v, Vector2(1080, 600))
	sc.name = name
	tabs.add_child(sc)
	return v


func _rebuild() -> void:
	for c in tabs.get_children():
		tabs.remove_child(c); c.queue_free()
	await get_tree().process_frame
	var s := Game.state
	var st := Game.stats()
	# Character
	var ch := _page("Character")
	var job := Game.job()
	ch.add_child(UI.label("%s   -   %s %s, %s" % [s["name"], RaceData.CLANS[s["appearance"]["clan"]]["name"], RaceData.RACES[s["appearance"]["race"]]["name"],
		"Female" if s["appearance"]["sex"] == "f" else "Male"], 26, UI.GOLD))
	ch.add_child(UI.label("Nameday: %d Sun of the %s     Guardian: %s     City-state: %s" % [int(s["nameday"][0]), RaceData.MOONS[int(s["nameday"][1])],
		RaceData.DEITIES[int(s["deity"])], Data.zones[Game.city()]["name"]], 18, UI.DIM))
	var e: Dictionary = s["jobs"][job]
	ch.add_child(UI.label("%s  Lv.%d     EXP %d / %d" % [Data.jobs[job]["name"], int(e["level"]), int(e["xp"]), Data.xp_to_next(int(e["level"]))], 22))
	ch.add_child(UI.label("HP %d   MP %d   Attack %d   Defence %d   Critical %d%%   Stamina %d" % [int(st["hp"]), int(st["mp"]), int(st["atk"]), int(st["def"]), int(st["crit"] * 100.0), int(st["stam"])], 19))
	ch.add_child(UI.label("Weapon: " + Data.weapon_name(job, int(s["weapons"][job]["tier"])), 19))
	for slot in ["head", "body", "legs", "feet"]:
		var t := int(s["armor"][slot])
		ch.add_child(UI.label("%s: %s" % [ItemData.ARMOR_SLOTS[slot], ItemData.ARMOR_SETS[t]["name"] + " " + ItemData.ARMOR_SLOTS[slot] if t >= 0 else "-"], 18, UI.DIM))
	var meal := []
	for k in s.get("meal", {}): meal.append(Data.meal(k, s["meal"][k])["name"])
	ch.add_child(UI.label("Meal: " + (", ".join(meal) if not meal.is_empty() else "none"), 18, UI.DIM))
	ch.add_child(UI.label("Jobs learned:", 20, UI.GOLD))
	for j in s["jobs"]:
		ch.add_child(UI.label("   %s  Lv.%d%s" % [Data.jobs[j]["name"], int(s["jobs"][j]["level"]), "   (current)" if j == job else ""], 18))
	ch.add_child(UI.label("Controls: %s light, %s heavy (hold to charge), %s weapon skill, %s guard, %s dodge (hold: sprint), %s jump, %s potion, %s lock-on, 1-4 / D-pad job actions. Swimming: %s dive, %s surface." % [
		Inputs.glyph("light"), Inputs.glyph("heavy"), Inputs.glyph("special"), Inputs.glyph("guard"), Inputs.glyph("dodge"), Inputs.glyph("jump"), Inputs.glyph("item"), Inputs.glyph("lock_on"), Inputs.glyph("guard"), Inputs.glyph("jump")], 16, UI.DIM))
	ch.get_child(ch.get_child_count() - 1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ch.add_child(UI.button("Return to game", close))
	# Items
	var it := _page("Items")
	_build_items(it)
	# Journal
	var jr := _page("Journal")
	var q := Game.current_msq()
	jr.add_child(UI.label("Main Scenario", 22, UI.GOLD))
	if q.is_empty(): jr.add_child(UI.label("The main story is complete. The realm is yours to explore.", 19))
	else:
		jr.add_child(UI.label(q["name"], 21))
		var dl := UI.label(q["desc"], 18, UI.DIM); dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; dl.custom_minimum_size.x = 1000
		jr.add_child(dl)
	jr.add_child(UI.label("Completed: %d quests" % s["quests_done"].size(), 18, UI.DIM))
	if not Game.mission.is_empty():
		jr.add_child(UI.label("Current quest: " + Game.mission["name"], 21, UI.GOLD))
		if world.mission_runner: jr.add_child(UI.label(world.mission_runner.objective_text(), 18))
		jr.add_child(UI.button("Abandon quest and return to town", func():
			close(); Game.finish_mission(false); world.return_to_city()))
	jr.add_child(UI.button("Return to game", close))
	# Party
	var pt := _page("Party")
	if s["party"].is_empty(): pt.add_child(UI.label("You travel alone. Visit the Party Recruiter at your guild.", 19))
	for rid in s["party"]:
		for r in ItemData.RECRUITS:
			if r["id"] == rid: pt.add_child(UI.label("%s  -  %s" % [r["name"], Data.jobs[r["job"]]["name"]], 19))
	pt.add_child(UI.button("Return to game", close))
	# Journal tab index 2 -> reorder so Journal is reachable via the journal key
	tabs.move_child(jr.get_parent(), 2)
	# Settings
	var sp := _page("Settings")
	SettingsUI.build(sp)
	# Save / Load
	var sv := _page("Save & Load")
	sv.add_child(UI.label("Save to a slot (current: %d)" % (Game.slot + 1), 20, UI.GOLD))
	for i in SaveSystem.SLOTS:
		var idx: int = i
		var row := UI.hbox(6)
		row.add_child(UI.button("Save", func():
			Game.state["pos"] = [world.player.global_position.x, world.player.global_position.y, world.player.global_position.z]
			Game.state["hp_frac"] = world.player.hp / world.player.max_hp
			Game.save_game(idx); Sfx.play("ui_ok"); _rebuild(); await get_tree().process_frame; tabs.current_tab = tabs.get_tab_count() - 2; _focus_tab(), 90))
		row.add_child(UI.button("Load", func():
			close(); Game.mission = {}; Game.load_game(idx), 90))
		row.get_child(1).disabled = not SaveSystem.exists(idx)
		var summ := UI.label(SaveSystem.summary(idx), 16, UI.TEXT)
		summ.clip_text = true
		summ.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		summ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summ.custom_minimum_size.x = 200
		row.add_child(summ)
		sv.add_child(row)
	sv.add_child(UI.button("Return to game", close))
	var qt := _page("Quit")
	qt.add_child(UI.label("Unsaved progress since your last save will be lost.", 19))
	qt.add_child(UI.button("Quit to title", func(): get_tree().paused = false; Game.to_title()))
	qt.add_child(UI.button("Quit game", func(): get_tree().quit()))
	qt.add_child(UI.button("Return to game", close))
	_focus_tab()


# ------------------------------------------------------------------ inventory
func _item_row(text: String, desc: String, buttons: Array) -> HBoxContainer:
	var row := UI.hbox(8)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UI.label(text, 19, UI.TEXT)
	var d := UI.label(desc, 15, UI.DIM)
	d.clip_text = true
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l); v.add_child(d)
	row.add_child(v)
	for b in buttons:
		var btn := UI.button(b[0], b[1], 150)
		btn.disabled = not b[2]
		row.add_child(btn)
	return row


func _items_changed() -> void:
	Sfx.play("ui_ok", -6.0)
	await _rebuild()
	tabs.current_tab = 1
	_focus_tab()


func _build_items(it: VBoxContainer) -> void:
	var s := Game.state
	var p: Player = world.player
	it.add_child(UI.label("Gil: %d" % int(s["gil"]), 22, UI.GOLD))
	it.add_child(UI.label("Consumables  (quick item used with [%s]: %s)" % [Inputs.glyph("item"), Data.item_name(s.get("quick_item", "potion"))], 20, UI.GOLD))
	var any := false
	for id in ItemData.CONSUMABLES:
		var n := Game.count(id)
		if n <= 0: continue
		any = true
		var c: Dictionary = ItemData.CONSUMABLES[id]
		var desc := "Revives you automatically when you fall." if c.has("revive") else "Restores %s%s." % [
			("%d%% HP" % int(float(c.get("heal", 0.0)) * 100.0)) if c.has("heal") else "", (" %s%d MP" % ["and " if c.has("heal") else "", int(c["mp"])]) if c.has("mp") else ""]
		var iid: String = id
		it.add_child(_item_row("%s  x%d" % [c["name"], n], desc, [
			["Use", func(): p.use_item(iid); _items_changed(), not c.has("revive") and not p.dead],
			["Set Quick", func(): Game.state["quick_item"] = iid; _items_changed(), not c.has("revive") and s.get("quick_item", "potion") != iid],
		]))
	if not any: it.add_child(UI.label("No consumables. Buy potions at the market.", 17, UI.DIM))
	it.add_child(UI.label("Materials", 20, UI.GOLD))
	any = false
	for id in s["inventory"]:
		if not ItemData.MATERIALS.has(id): continue
		any = true
		var mid: String = id
		it.add_child(_item_row("%s  x%d" % [Data.item_name(mid), Game.count(mid)], "Used for upgrades at the smithy. Sells for %d gil at the market." % int(ItemData.MATERIALS[mid]["price"]), [
			["Discard 1", func(): Game.add_item(mid, -1); _items_changed(), true],
		]))
	if not any: it.add_child(UI.label("No materials yet. Defeat and carve monsters, or gather on quests.", 17, UI.DIM))
	var job := Game.job()
	var wm: Array = s["weapons"][job]["materia"]
	it.add_child(UI.label("Materia  (weapon slots %d/%d)" % [wm.size(), Game.materia_slots_weapon()], 20, UI.GOLD))
	for i in s["materia"].size():
		var m: Dictionary = s["materia"][i]
		var idx: int = i
		it.add_child(_item_row("%s %s" % [ItemData.MATERIA[m["type"]]["name"], ItemData.MATERIA_GRADES[int(m["grade"])]], "Boosts %s while melded." % ItemData.MATERIA[m["type"]]["stat"], [
			["Meld", func(): wm.append(s["materia"][idx]); s["materia"].remove_at(idx); Game.state_changed.emit(); _items_changed(), wm.size() < Game.materia_slots_weapon()],
		]))
	for i in wm.size():
		var m: Dictionary = wm[i]
		var idx: int = i
		it.add_child(_item_row("[Melded] %s %s" % [ItemData.MATERIA[m["type"]]["name"], ItemData.MATERIA_GRADES[int(m["grade"])]], "In your %s." % Data.weapon_name(job, int(s["weapons"][job]["tier"])), [
			["Remove", func(): s["materia"].append(wm[idx]); wm.remove_at(idx); Game.state_changed.emit(); _items_changed(), true],
		]))
	it.add_child(UI.label("Equipment appearance", 20, UI.GOLD))
	var hidden: Dictionary = s.get("armor_hidden", {})
	for slot in ["head", "body", "legs", "feet"]:
		var t := int(s["armor"][slot])
		if t < 0: continue
		var sl: String = slot
		var hid: bool = hidden.get(sl, false)
		it.add_child(_item_row("%s %s" % [ItemData.ARMOR_SETS[t]["name"], ItemData.ARMOR_SLOTS[sl]], "Defence %d. %s" % [int(ItemData.ARMOR_SETS[t]["def"]), "Hidden (still protects you)." if hid else "Visible."], [
			["Show" if hid else "Hide", func():
				var h: Dictionary = Game.state.get("armor_hidden", {})
				h[sl] = not hid
				Game.state["armor_hidden"] = h
				p.rebuild(); _items_changed(), true],
		]))
	it.add_child(UI.button("Return to game", close))


class SettingsUI:
	static func build(v: VBoxContainer) -> void:
		v.add_child(UI.label("Graphics", 22, UI.GOLD))
		var presets := Settings.PRESETS.keys()
		v.add_child(UI.stepper("Quality", presets, maxi(0, presets.find(Settings.v["preset"])), func(i): Settings.set_opt("preset", presets[i])))
		var fs := CheckBox.new(); fs.text = "Fullscreen"; fs.button_pressed = Settings.v["fullscreen"]
		fs.toggled.connect(func(b): Settings.set_opt("fullscreen", b)); v.add_child(fs)
		var vs := CheckBox.new(); vs.text = "V-Sync"; vs.button_pressed = Settings.v["vsync"]
		vs.toggled.connect(func(b): Settings.set_opt("vsync", b)); v.add_child(vs)
		var caps := [0, 30, 60, 120, 144]
		v.add_child(UI.stepper("FPS cap", caps.map(func(c): return "Unlimited" if c == 0 else str(c)), maxi(0, caps.find(int(Settings.v["fps_cap"]))), func(i): Settings.set_opt("fps_cap", caps[i])))
		v.add_child(_slider_row("Field of view", 55.0, 95.0, Settings.v["fov"], func(x): Settings.set_opt("fov", x), 1.0))
		v.add_child(UI.label("Controls", 22, UI.GOLD))
		v.add_child(_slider_row("Camera sensitivity", 0.3, 2.5, Settings.v["sens"], func(x): Settings.set_opt("sens", x)))
		var inv := CheckBox.new(); inv.text = "Invert camera Y"; inv.button_pressed = Settings.v["invert_y"]
		inv.toggled.connect(func(b): Settings.set_opt("invert_y", b)); v.add_child(inv)
		var aoe := CheckBox.new(); aoe.text = "Show enemy attack markers (off = Elden Ring style, read the body language)"; aoe.button_pressed = Settings.v["aoe_markers"]
		aoe.toggled.connect(func(b): Settings.set_opt("aoe_markers", b)); v.add_child(aoe)
		var hs := CheckBox.new(); hs.text = "Hide weapons while sheathed"; hs.button_pressed = Settings.v.get("hide_sheathed", false)
		hs.toggled.connect(func(b): Settings.set_opt("hide_sheathed", b)); v.add_child(hs)
		v.add_child(_slider_row("Camera shake", 0.0, 1.5, Settings.v["cam_shake"], func(x): Settings.set_opt("cam_shake", x)))
		v.add_child(_slider_row("Text speed", 0.5, 3.0, Settings.v["text_speed"], func(x): Settings.set_opt("text_speed", x)))
		v.add_child(UI.label("Audio", 22, UI.GOLD))
		v.add_child(_slider_row("Master volume", 0.0, 1.0, Settings.v["master"], func(x): Settings.set_opt("master", x)))
		v.add_child(_slider_row("Effects volume", 0.0, 1.0, Settings.v["sfx"], func(x): Settings.set_opt("sfx", x)))
		v.add_child(_slider_row("Music volume", 0.0, 1.0, Settings.v["music"], func(x): Settings.set_opt("music", x); Sfx._music.volume_db = linear_to_db(maxf(0.001, x)) - 8.0))

	static func _slider_row(t: String, a: float, b: float, val: float, cb: Callable, step := 0.05) -> HBoxContainer:
		var h := UI.hbox(10)
		var l := UI.label(t, 18, UI.DIM); l.custom_minimum_size.x = 230
		h.add_child(l)
		h.add_child(UI.slider(a, b, val, cb, step))
		return h
