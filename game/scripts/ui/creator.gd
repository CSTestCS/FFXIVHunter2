extends Node
## Character creation: race, clan, gender, body, colours, hair, features, profile and job,
## plus a second appearance for the legendary Warrior of Light NPC.

const FIRST_NAMES := ["Aelis", "Cid", "Edda", "Wyn", "Rhoswen", "Torvald", "Leveva", "Kaien", "Mira", "Halric", "Y'lhana", "Sorrel", "Brynn", "Odhan", "Liesl"]
const LAST_NAMES := ["Starfall", "Ashford", "Vaellis", "Thornbury", "Dawnmere", "Kestrel", "Brightwater", "Ironbough", "Silverleaf", "Morrow"]

var ap: Dictionary
var wol: Dictionary
var editing_wol := false
var job := "PLD"
var wol_job := "PLD"
var first := ""
var last := ""
var wol_name := "the Warrior of Light"
var nameday := [1, 0]
var deity := 0
var preview: CharModel
var preview_root: Node3D
var cam: Camera3D
var yaw := PI
var face_cam := false
var tabs: TabContainer
var head: Label
var _rebuild_t := -1.0
var _last_tab := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ap = RaceData.default_appearance("hyur", "midlander", "f")
	wol = RaceData.default_appearance("hyur", "midlander", "m")
	wol["hair_color"] = "#1d1a1a"
	first = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	last = LAST_NAMES[randi() % LAST_NAMES.size()]
	_scene()
	var layer := CanvasLayer.new(); add_child(layer)
	var ui := Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.theme = UI.theme(); layer.add_child(ui)
	var left := UI.vbox(8)
	left.position = Vector2(24, 20)
	ui.add_child(left)
	head = UI.label("", 28, UI.GOLD)
	left.add_child(head)
	var toggle := UI.hbox(8)
	toggle.add_child(UI.button("Edit: Your Adventurer", func(): editing_wol = false; _refresh_all(), 300))
	toggle.add_child(UI.button("Edit: The Warrior of Light", func(): editing_wol = true; _refresh_all(), 300))
	left.add_child(toggle)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(700, 690)
	left.add_child(tabs)
	var bottom := UI.hbox(10)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.offset_left = -760; bottom.offset_top = -80; bottom.offset_right = -30; bottom.offset_bottom = -24
	bottom.add_child(UI.button("Rotate", func(): yaw += PI * 0.25, 120))
	bottom.add_child(UI.button("Face / Body", func(): face_cam = not face_cam, 160))
	bottom.add_child(UI.button("Back to Title", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), 180))
	bottom.add_child(UI.button("Begin Adventure", _begin, 220))
	ui.add_child(bottom)
	var hint := UI.label("Right stick / mouse wheel: rotate preview.   LB/RB or Z/X: switch tabs.", 15, UI.DIM)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); hint.offset_left = -760; hint.offset_top = -110; hint.offset_right = -30
	ui.add_child(hint)
	_refresh_all()
	Sfx.music("title")


func _scene() -> void:
	preview_root = Node3D.new(); add_child(preview_root)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2a3a6a"); sm.sky_horizon_color = Color("#9ab0c8"); sm.ground_horizon_color = Color("#6a7890"); sm.ground_bottom_color = Color("#1a1e28")
	sky.sky_material = sm; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.ssao_enabled = Settings.gfx["ssao"]
	env.glow_enabled = true
	we.environment = env; preview_root.add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, 35, 0); key.light_energy = 1.4; key.shadow_enabled = true; preview_root.add_child(key)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-15, 200, 0); rim.light_energy = 0.7; rim.light_color = Color("#a8c8ff"); preview_root.add_child(rim)
	var bt := Batcher.new()
	bt.cyl(Vector3(0, -0.05, 0), 2.2, 0.1, "plinth", Props.pbr("#3a3e4a", 0.4, 0.3), false, 2.4, 32)
	bt.commit(preview_root)
	cam = Camera3D.new(); preview_root.add_child(cam); cam.current = true


func cur() -> Dictionary:
	return wol if editing_wol else ap


func _process(delta: float) -> void:
	yaw += (Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left")) * delta * 2.5
	if preview:
		preview.rotation.y = yaw
		var h: float = preview.scale.y
		var target := Vector3(0, (1.5 if face_cam else 0.9) * h, 0)
		var dist: float = (0.8 if face_cam else 3.0) * maxf(h, 0.6)
		var want := Vector3(-0.9 * dist * 0.4 - 0.4, target.y + 0.05, dist)
		cam.position = cam.position.lerp(want + Vector3(0.6 if not face_cam else 0.15, 0, 0), clampf(6.0 * delta, 0, 1))
		cam.look_at(target + Vector3(-0.35 * dist * 0.3, 0, 0))
	if _rebuild_t > 0.0:
		_rebuild_t -= delta
		if _rebuild_t <= 0.0: _rebuild_preview()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: yaw += 0.2
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: yaw -= 0.2
	if e.is_action_pressed("tab_next"): tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count(); UI.focus_first(tabs.get_current_tab_control())
	if e.is_action_pressed("tab_prev"): tabs.current_tab = (tabs.current_tab - 1 + tabs.get_tab_count()) % tabs.get_tab_count(); UI.focus_first(tabs.get_current_tab_control())


func _changed(rebuild_tabs := false) -> void:
	_rebuild_t = 0.12
	if rebuild_tabs: _refresh_tabs()


func _rebuild_preview() -> void:
	if preview: preview.queue_free()
	preview = CharModel.new()
	preview_root.add_child(preview)
	var j := wol_job if editing_wol else job
	var armor := {"body": 6, "legs": 6, "feet": 6} if editing_wol else {}
	var dyes := {"body": "#e8e4f0", "legs": "#3a3a4a", "feet": "#2a2a30"} if editing_wol else {}
	preview.build(cur(), {"armor": armor, "dyes": dyes, "weapon": Data.jobs[j]["weapon"], "tier": 6 if editing_wol else 0})
	preview.set_drawn(false)
	preview.play("idle", 0.0)
	preview.rotation.y = yaw


func _refresh_all() -> void:
	_refresh_tabs()
	_rebuild_preview()


func _refresh_tabs() -> void:
	head.text = "Creating: " + ("the Warrior of Light (NPC)" if editing_wol else "Your Adventurer")
	_last_tab = tabs.current_tab
	for c in tabs.get_children(): c.queue_free()
	var a := cur()
	# ---- Race
	var rv := _page("Race")
	var races := RaceData.RACES.keys()
	rv.add_child(UI.stepper("Race", races.map(func(r): return RaceData.RACES[r]["name"]), races.find(a["race"]), func(i):
		var r: String = races[i]
		a["race"] = r; a["clan"] = RaceData.RACES[r]["clans"][0]; a["skin"] = RaceData.CLANS[a["clan"]]["skin"][0]
		_changed(true)))
	var clans: Array = RaceData.RACES[a["race"]]["clans"]
	rv.add_child(UI.stepper("Clan", clans.map(func(c): return RaceData.CLANS[c]["name"]), maxi(0, clans.find(a["clan"])), func(i):
		a["clan"] = clans[i]; a["skin"] = RaceData.CLANS[a["clan"]]["skin"][0]; _changed(true)))
	rv.add_child(UI.stepper("Gender", ["Female", "Male"], 0 if a["sex"] == "f" else 1, func(i): a["sex"] = "f" if i == 0 else "m"; _changed(true)))
	rv.add_child(UI.label(_race_blurb(a["race"]), 17, UI.DIM))
	rv.get_child(rv.get_child_count() - 1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.get_child(rv.get_child_count() - 1).custom_minimum_size.x = 640
	# ---- Body
	var bv := _page("Body")
	bv.add_child(_slider("Height", a, "height"))
	bv.add_child(_slider("Muscle tone", a, "muscle"))
	if a["sex"] == "f": bv.add_child(_slider("Bust size", a, "bust"))
	bv.add_child(UI.label("Skin tone", 18, UI.DIM))
	bv.add_child(UI.swatches(RaceData.CLANS[a["clan"]]["skin"] + ["#ffe8dc", "#c89878", "#6a4a3a"], a["skin"], func(c): a["skin"] = c; _changed(true)))
	if a["race"] in ["miqote", "hrothgar", "aura", "viera", "elezen", "lalafell"]:
		bv.add_child(_slider("Ear / horn size", a, "ear_size"))
	if RaceData.RACES[a["race"]]["tail"] != "": bv.add_child(_slider("Tail length", a, "tail_length"))
	if a["race"] == "aura" or a["race"] == "hrothgar":
		bv.add_child(UI.label("Horn / feature colour", 18, UI.DIM))
		bv.add_child(UI.swatches(RaceData.FEATURE_COLORS, a["feature_color"], func(c): a["feature_color"] = c; _changed(true)))
	# ---- Face & hair
	var fv := _page("Face & Hair")
	fv.add_child(UI.stepper("Hairstyle", RaceData.HAIRSTYLES.map(func(h): return h["name"]), int(a["hair_style"]), func(i): a["hair_style"] = i; _changed()))
	fv.add_child(UI.label("Hair colour", 18, UI.DIM))
	fv.add_child(UI.swatches(RaceData.HAIR_COLORS, a["hair_color"], func(c): a["hair_color"] = c; _changed(true)))
	var hl := CheckBox.new(); hl.text = "Highlights"; hl.button_pressed = a["highlights"]
	hl.toggled.connect(func(b): a["highlights"] = b; _changed(true))
	fv.add_child(hl)
	if a["highlights"]:
		fv.add_child(UI.swatches(RaceData.HAIR_COLORS, a["highlight_color"], func(c): a["highlight_color"] = c; _changed(true)))
	fv.add_child(UI.label("Eye colour", 18, UI.DIM))
	fv.add_child(UI.swatches(RaceData.EYE_COLORS, a["eye_color"], func(c): a["eye_color"] = c; _changed(true)))
	fv.add_child(UI.label("Lip colour", 18, UI.DIM))
	fv.add_child(UI.swatches(RaceData.LIP_COLORS, a["lip_color"], func(c): a["lip_color"] = c; _changed(true)))
	fv.add_child(UI.stepper("Voice", RaceData.VOICES, int(a["voice"]), func(i): a["voice"] = i))
	# ---- Profile
	var pv := _page("Profile")
	if editing_wol:
		pv.add_child(UI.label("How the realm names its hero:", 18, UI.DIM))
		var le := LineEdit.new(); le.text = wol_name; le.custom_minimum_size.x = 420
		le.text_changed.connect(func(t): wol_name = t)
		pv.add_child(le)
		pv.add_child(UI.label("The Warrior of Light appears in cutscenes wearing legendary gear.", 16, UI.DIM))
	else:
		pv.add_child(UI.label("Forename", 18, UI.DIM))
		var f1 := LineEdit.new(); f1.text = first; f1.max_length = 15; f1.custom_minimum_size.x = 420
		f1.text_changed.connect(func(t): first = t); pv.add_child(f1)
		pv.add_child(UI.label("Surname", 18, UI.DIM))
		var f2 := LineEdit.new(); f2.text = last; f2.max_length = 15; f2.custom_minimum_size.x = 420
		f2.text_changed.connect(func(t): last = t); pv.add_child(f2)
		pv.add_child(UI.button("Random name", func():
			first = FIRST_NAMES[randi() % FIRST_NAMES.size()]; last = LAST_NAMES[randi() % LAST_NAMES.size()]; _changed(true), 220))
		var days := []
		for d in 32: days.append("%d Sun" % (d + 1))
		pv.add_child(UI.stepper("Nameday", days, int(nameday[0]) - 1, func(i): nameday[0] = i + 1))
		pv.add_child(UI.stepper("Moon", RaceData.MOONS, int(nameday[1]), func(i): nameday[1] = i))
		pv.add_child(UI.stepper("Guardian", RaceData.DEITIES, deity, func(i): deity = i))
	# ---- Job
	var jv := _page("Job")
	var sel := wol_job if editing_wol else job
	jv.add_child(UI.label(("The Warrior of Light's job" if editing_wol else "Starting job (every job is open; your story begins near its city)"), 18, UI.DIM))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
	for j in Data.jobs:
		var jj: String = j
		var b := UI.button(("✓ " if jj == sel else "") + Data.jobs[jj]["name"], func():
			if editing_wol: wol_job = jj
			else: job = jj
			_changed(true), 205)
		var role_col = {"tank": Color("#6a9aff"), "healer": Color("#7ad07a"), "melee": Color("#ff8a6a"), "ranged": Color("#ff8a6a"), "caster": Color("#ff8a6a")}[Data.jobs[jj]["role"]]
		b.add_theme_color_override("font_color", role_col)
		grid.add_child(b)
	jv.add_child(grid)
	var jd: Dictionary = Data.jobs[sel]
	var info := UI.label("%s  -  %s\nWeapon: %s\nStory begins near: %s\nJob gauge: %s\nWeapon skills: %s" % [jd["name"], JobData.ROLE_NAMES[jd["role"]], ItemData.WEAPON_NAMES[jd["weapon"]],
		Data.zones[jd["city"]]["name"], jd["gauge_name"], ", ".join(jd["moves"].values().map(func(m): return m["name"]))], 17, UI.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.custom_minimum_size.x = 640
	jv.add_child(info)
	tabs.current_tab = clampi(_last_tab, 0, tabs.get_tab_count() - 1)
	UI.focus_first(tabs.get_current_tab_control())


func _page(n: String) -> VBoxContainer:
	var v := UI.vbox(8)
	var sc := UI.scroll(v, Vector2(680, 620))
	sc.name = n
	tabs.add_child(sc)
	return v


func _slider(t: String, a: Dictionary, key: String) -> HBoxContainer:
	var h := UI.hbox(10)
	var l := UI.label(t, 18, UI.DIM); l.custom_minimum_size.x = 180
	h.add_child(l)
	h.add_child(UI.slider(0.0, 1.0, float(a[key]), func(v): a[key] = v; _changed(), 0.02))
	return h


func _race_blurb(r: String) -> String:
	return {
		"hyur": "The most populous people of Eorzea, Hyur hail from many lands. Midlanders are the majority; Highlanders are taller and stronger, hailing from Gyr Abania.",
		"elezen": "A tall and long-lived people with keen senses. Wildwood dwell in forests; Duskwight keep to caves and shadow.",
		"lalafell": "Small in stature but great in cleverness. Plainsfolk farm the fertile lands; Dunesfolk thrive in the deserts and trade.",
		"miqote": "Feline hunters of keen sense. Seekers of the Sun revere Azeyma; Keepers of the Moon follow Menphina.",
		"roegadyn": "Towering seafarers and warriors. Sea Wolves sail La Noscea; Hellsguard guard the volcanic Ishgard frontier.",
		"aura": "Horned and scaled descendants of dragons. Raen from Doma's hidden valley; Xaela roam the Azim Steppe.",
		"hrothgar": "Leonine warriors of great strength. Helions honour their queens; The Lost wander far from home.",
		"viera": "Long-eared, long-lived forest wardens. Rava from the jungles of the south; Veena from the Golmore and Skatay.",
	}[r] + "\n(Races without a provided base model are shaped from the Hyur and Miqo'te bases.)"


func _begin() -> void:
	if first.strip_edges() == "" or last.strip_edges() == "":
		head.text = "Please enter a forename and surname (Profile tab)."
		return
	var c := {"name": first.strip_edges() + " " + last.strip_edges(), "appearance": ap, "job": job, "nameday": nameday, "deity": deity,
		"wol": {"appearance": wol, "job": wol_job, "name": wol_name}}
	Game.new_game(Game.new_slot, c)
