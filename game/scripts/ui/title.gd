extends Node
## Title screen with a live 3D backdrop, multiple save slots (new / continue / load / delete) and settings.

var ui: Control
var menu_box: VBoxContainer
var cam: Camera3D
var t := 0.0
var _confirm_delete := -1


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_backdrop()
	var layer := CanvasLayer.new(); add_child(layer)
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.theme = UI.theme()
	layer.add_child(ui)
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); shade.offset_right = 640
	shade.color = Color(0.02, 0.03, 0.06, 0.55); ui.add_child(shade)
	var title := UI.label("EORZEA HUNTER", 76, UI.GOLD)
	title.position = Vector2(70, 90); ui.add_child(title)
	var sub := UI.label("Echoes of an Adventurer", 30, UI.TEXT)
	sub.position = Vector2(76, 180); ui.add_child(sub)
	var note := UI.label("An unofficial fan game set in the world of FINAL FANTASY XIV, after Endwalker.\nFINAL FANTASY is a registered trademark of Square Enix. Not affiliated with or endorsed by Square Enix.", 14, UI.DIM)
	UI.fit(ui, note, Vector2(0.0, 1.0), Vector4(24, 16, 16, 12))
	menu_box = UI.vbox(10)
	menu_box.custom_minimum_size = Vector2(480, 0)
	UI.fit(ui, menu_box, Vector2(0.0, 0.0), Vector4(80, 270, 16, 80))
	_main_menu()
	Sfx.music("title")


func _backdrop() -> void:
	var root := Node3D.new(); add_child(root)
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#1e2c5a"); sm.sky_horizon_color = Color("#f0a070"); sm.ground_horizon_color = Color("#c08060"); sm.ground_bottom_color = Color("#101420")
	sky.sky_material = sm; env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.glow_enabled = true; env.glow_intensity = 0.7
	env.fog_enabled = true; env.fog_light_color = Color("#e0a080"); env.fog_density = 0.004
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-12, 150, 0); sun.light_color = Color("#ffc890"); sun.light_energy = 1.6
	sun.shadow_enabled = true; root.add_child(sun)
	var water := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(600, 600); pm.subdivide_depth = 40; pm.subdivide_width = 40
	water.mesh = pm; water.material_override = ZoneBuilder.water_material({}); water.position.y = -0.4; root.add_child(water)
	var bt := Batcher.new()
	bt.cyl(Vector3(0, -0.5, 0), 6.0, 1.6, "rock", Props.pbr("#5a5652", 0.9), false, 4.5, 14)
	bt.commit(root)
	ZoneBuilder._aetheryte(root, Batcher.new(), Vector3(-2.5, 0.3, -2.0))
	var cm := CharModel.new()
	var ap := RaceData.default_appearance("miqote", "seeker", "f")
	ap["hair_style"] = 2; ap["hair_color"] = "#e8d5a6"; ap["eye_color"] = "#2d5b8a"
	cm.build(ap, {"armor": {"body": 4, "legs": 4, "feet": 4}, "dyes": {"body": "#3c5a8a"}, "weapon": "katana", "tier": 4})
	root.add_child(cm)
	cm.position = Vector3(1.2, 0.3, 0); cm.rotation.y = 2.4
	cm.play("idle", 0.0)
	for i in 30:
		var tr := Transform3D(Basis(Vector3.UP, i).scaled(Vector3.ONE * randf_range(1.0, 2.0)), Vector3(cos(i * 0.7) * randf_range(60, 120), -0.4, sin(i * 0.7) * randf_range(60, 120)))
		var mi := MeshInstance3D.new(); mi.mesh = Props.mesh("crystal" if i % 3 == 0 else "boulder"); mi.transform = tr; root.add_child(mi)
	cam = Camera3D.new(); root.add_child(cam); cam.fov = 45; cam.current = true


func _process(delta: float) -> void:
	t += delta
	var a := 2.2 + sin(t * 0.08) * 0.35
	cam.position = Vector3(cos(a) * 6.0, 1.6, sin(a) * 6.0)
	cam.look_at(Vector3(0.4, 1.2, 0))


func _clear() -> void:
	UI.clear(menu_box)


func _main_menu() -> void:
	_clear()
	var latest := SaveSystem.latest_slot()
	if latest >= 0:
		menu_box.add_child(UI.button("Continue  (Slot %d)" % (latest + 1), func(): Game.load_game(latest), 460))
	menu_box.add_child(UI.button("New Game", _new_game_slots, 460))
	var lb := UI.button("Load Game", _load_slots, 460)
	lb.disabled = latest < 0
	menu_box.add_child(lb)
	menu_box.add_child(UI.button("Settings", _settings, 460))
	menu_box.add_child(UI.button("Quit", func(): get_tree().quit(), 460))
	UI.focus_first(menu_box)


func _new_game_slots() -> void:
	_clear()
	menu_box.add_child(UI.label("Choose a slot for your new adventurer", 22, UI.GOLD))
	for i in SaveSystem.SLOTS:
		var idx := i
		var used := SaveSystem.exists(idx)
		menu_box.add_child(UI.button(SaveSystem.summary(idx) if used else "Slot %d  -  Empty" % (idx + 1), func():
			if used and _confirm_delete != idx:
				_confirm_delete = idx
				_new_game_slots()
				menu_box.add_child(UI.label("Slot %d holds a save. Select it again to overwrite." % (idx + 1), 18, Color(1, 0.6, 0.5)))
				return
			_confirm_delete = -1
			Game.new_slot = idx
			get_tree().change_scene_to_file("res://scenes/creator.tscn"), 900))
	menu_box.add_child(UI.button("Back", _main_menu, 460))
	UI.focus_first(menu_box)


func _load_slots() -> void:
	_clear()
	menu_box.add_child(UI.label("Load an adventurer", 22, UI.GOLD))
	for i in SaveSystem.SLOTS:
		var idx := i
		if not SaveSystem.exists(idx): continue
		var row := UI.hbox(6)
		row.add_child(UI.button(SaveSystem.summary(idx), func(): Game.load_game(idx), 820))
		row.add_child(UI.button("Delete", func():
			if _confirm_delete == idx:
				SaveSystem.delete_slot(idx); _confirm_delete = -1; _load_slots()
			else:
				_confirm_delete = idx
				menu_box.add_child(UI.label("Press Delete again to erase slot %d." % (idx + 1), 18, Color(1, 0.6, 0.5))), 110))
		menu_box.add_child(row)
	menu_box.add_child(UI.button("Back", _main_menu, 460))
	UI.focus_first(menu_box)


func _settings() -> void:
	_clear()
	var p := UI.panel(Vector2(760, 0))
	var outer := UI.vbox(6)
	p.add_child(outer)
	var v := UI.vbox(6)
	outer.add_child(UI.scroll(v, Vector2(720, 470)))
	GameMenu.SettingsUI.build(v)
	outer.add_child(UI.button("Back", _main_menu, 300))
	menu_box.add_child(p)
	UI.focus_first(menu_box)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"): _main_menu()
