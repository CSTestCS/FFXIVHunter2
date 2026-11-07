class_name HUD
extends CanvasLayer
## In-game overlay. Built once; per-frame work is just updating a few bar values and labels.

var world: Node
var root: Control
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var st_bar: ProgressBar
var gauge_bar: ProgressBar
var gauge_lbl: Label
var hp_lbl: Label
var breath_bar: ProgressBar
var name_lbl: Label
var hot: Array = []
var party_box: VBoxContainer
var party_rows := {}
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_name: Label
var boss: Monster
var compass: Control
var obj_lbl: Label
var prompt_lbl: Label
var toast_box: VBoxContainer
var banner_lbl: Label
var banner_sub: Label
var move_lbl: Label
var zone_lbl: Label
var zone_sub: Label
var fade: ColorRect
var vignette: ColorRect
var bars_top: ColorRect
var bars_bot: ColorRect
var reticle: Label
var gil_lbl: Label
var sen_lbl: Label
var _toast_t: Array = []
var _move_t := 0.0
var _banner_t := 0.0
var _zone_t := 0.0


func setup(w: Node) -> void:
	world = w
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	vignette = ColorRect.new(); vignette.set_anchors_preset(Control.PRESET_FULL_RECT); vignette.color = Color(0.8, 0.05, 0.02, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(vignette)
	# --- player bars (bottom centre)
	var pb := UI.vbox(4)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.custom_minimum_size.x = 600
	UI.fit(root, pb, Vector2(0.5, 1.0), Vector4(16, 16, 16, 20))
	move_lbl = UI.label("", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pb.add_child(move_lbl)
	var bars := UI.hbox(10)
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	pb.add_child(bars)
	var left := UI.vbox(3)
	bars.add_child(left)
	hp_lbl = UI.label("HP", 16, UI.TEXT)
	left.add_child(hp_lbl)
	hp_bar = UI.bar(UI.HP, 300, 16); left.add_child(hp_bar)
	mp_bar = UI.bar(UI.MP, 300, 10); left.add_child(mp_bar)
	st_bar = UI.bar(UI.STAM, 300, 8); left.add_child(st_bar)
	var right := UI.vbox(3)
	bars.add_child(right)
	gauge_lbl = UI.label("", 15, UI.DIM)
	right.add_child(gauge_lbl)
	gauge_bar = UI.bar(Color(0.95, 0.55, 0.25), 180, 12); right.add_child(gauge_bar)
	sen_lbl = UI.label("", 15, UI.GOLD); right.add_child(sen_lbl)
	breath_bar = UI.bar(Color(0.5, 0.8, 1.0), 180, 8); right.add_child(breath_bar)
	var hb := UI.hbox(8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	pb.add_child(hb)
	for i in 4:
		var slot := UI.panel(Vector2(132, 52))
		var v := UI.vbox(0)
		slot.add_child(v)
		var k := UI.label("", 13, UI.DIM)
		var n := UI.label("", 15, UI.TEXT)
		n.clip_text = true
		v.add_child(k); v.add_child(n)
		hb.add_child(slot)
		hot.append({"panel": slot, "key": k, "name": n})
	# --- party list (left)
	party_box = UI.vbox(6)
	UI.fit(root, party_box, Vector2(0.0, 0.45), Vector4(24, 16, 16, 16))
	# --- zone name + objective tracker (top-left)
	var tl := UI.vbox(2)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_lbl = UI.label("", 40, UI.TEXT)
	zone_sub = UI.label("", 22, UI.GOLD)
	obj_lbl = UI.label("", 19, UI.TEXT)
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_lbl.custom_minimum_size.x = 560
	tl.add_child(zone_lbl); tl.add_child(zone_sub); tl.add_child(obj_lbl)
	UI.fit(root, tl, Vector2(0.0, 0.0), Vector4(24, 110, 16, 16))
	gil_lbl = UI.label("", 17, UI.GOLD)
	gil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.fit(root, gil_lbl, Vector2(1.0, 1.0), Vector4(16, 16, 24, 14))
	# --- compass (top centre)
	compass = Control.new()
	compass.custom_minimum_size = Vector2(640, 32)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.draw.connect(_draw_compass)
	UI.fit(root, compass, Vector2(0.5, 0.0), Vector4(16, 14, 16, 16))
	# --- boss bar
	boss_box = UI.vbox(2)
	boss_name = UI.label("", 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	boss_bar = UI.bar(Color(0.85, 0.2, 0.18), 720, 14)
	boss_box.add_child(boss_name); boss_box.add_child(boss_bar)
	boss_box.visible = false
	UI.fit(root, boss_box, Vector2(0.5, 0.0), Vector4(16, 56, 16, 16))
	# --- prompt, toasts, banner
	prompt_lbl = UI.label("", 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UI.fit(root, prompt_lbl, Vector2(0.5, 0.62))
	toast_box = UI.vbox(4)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(root, toast_box, Vector2(1.0, 0.0), Vector4(16, 90, 24, 200))
	var bn := UI.vbox(4)
	bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bn.custom_minimum_size.x = 1100
	banner_lbl = UI.label("", 64, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub = UI.label("", 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bn.add_child(banner_lbl); bn.add_child(banner_sub)
	UI.fit(root, bn, Vector2(0.5, 0.33))
	reticle = UI.label("◆", 28, Color(1, 0.4, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	reticle.visible = false
	root.add_child(reticle)
	# --- cinematic bars & fade
	bars_top = ColorRect.new(); bars_top.color = Color.BLACK; bars_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); bars_top.offset_bottom = 0
	bars_bot = ColorRect.new(); bars_bot.color = Color.BLACK; bars_bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bars_bot.offset_top = 0
	root.add_child(bars_top); root.add_child(bars_bot)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 1); fade.set_anchors_preset(Control.PRESET_FULL_RECT); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	fade_in(0.8)
	_refresh_hotbar()


func _refresh_hotbar() -> void:
	var p: Player = world.player
	var acts: Array = p.jd["actions"]
	for i in 4:
		hot[i]["key"].text = Inputs.glyph("act%d" % (i + 1))
		hot[i]["name"].text = acts[i]["name"] if i < acts.size() else ""
	gauge_lbl.text = p.jd["gauge_name"]


func on_player_event(kind: String, data) -> void:
	if kind == "move":
		move_lbl.text = str(data)
		move_lbl.modulate.a = 1.0
		_move_t = 1.2


func _process(delta: float) -> void:
	var p: Player = world.player
	if p == null: return
	var cine: bool = world.cutscene.active
	for c in [hp_bar.get_parent().get_parent().get_parent(), party_box, obj_lbl, compass, gil_lbl]:
		c.visible = not cine
	hp_bar.max_value = p.max_hp; hp_bar.value = p.hp
	hp_lbl.text = "%s   Lv.%d %s     HP %d / %d" % [p.display_name, p.level, p.jd["name"], int(p.hp), int(p.max_hp)]
	mp_bar.max_value = p.max_mp; mp_bar.value = p.mp
	st_bar.max_value = p.max_stam; st_bar.value = p.stam
	gauge_bar.value = p.gauge
	sen_lbl.text = ("Sen: " + "●".repeat(p.sen) + "○".repeat(3 - p.sen)) if p.job == "SAM" else ""
	breath_bar.visible = p.swimming and p.breath < 0.999
	breath_bar.value = p.breath * 100.0
	for i in 4:
		var cd: float = p.act_cd[i]
		var acts: Array = p.jd["actions"]
		var nm: String = acts[i]["name"] if i < acts.size() else ""
		hot[i]["name"].text = nm if cd <= 0.0 else "%s  %ds" % [nm, int(ceil(cd))]
		hot[i]["panel"].modulate = Color(1, 1, 1, 1) if cd <= 0.0 else Color(0.55, 0.55, 0.6, 1)
	gil_lbl.text = "%s gil     [%s] Menu   [%s] Journal" % [_fmt(int(Game.state.get("gil", 0))), Inputs.glyph("menu"), Inputs.glyph("journal")]
	_move_t -= delta
	if _move_t < 0.5: move_lbl.modulate.a = maxf(0.0, _move_t * 2.0)
	_banner_t -= delta
	if _banner_t < 1.0:
		banner_lbl.modulate.a = maxf(0.0, _banner_t); banner_sub.modulate.a = maxf(0.0, _banner_t)
	_zone_t -= delta
	if _zone_t < 1.0:
		zone_lbl.modulate.a = maxf(0.0, _zone_t); zone_sub.modulate.a = maxf(0.0, _zone_t)
	vignette.color.a = maxf(0.0, vignette.color.a - delta * 1.2)
	for i in range(_toast_t.size() - 1, -1, -1):
		_toast_t[i][1] -= delta
		var lbl: Label = _toast_t[i][0]
		if _toast_t[i][1] < 0.6: lbl.modulate.a = maxf(0.0, _toast_t[i][1] / 0.6)
		if _toast_t[i][1] <= 0.0:
			lbl.queue_free(); _toast_t.remove_at(i)
	_party()
	if boss and is_instance_valid(boss):
		boss_bar.max_value = boss.max_hp; boss_bar.value = boss.hp
		boss_name.text = "%s   Lv.%d%s" % [boss.display_name, boss.level, "   [ENRAGED]" if boss.enraged else ""]
		boss_box.visible = not cine
	else:
		boss_box.visible = false
	var lt: Actor = p.lock_target
	if lt and is_instance_valid(lt) and not lt.dead and not cine:
		var cam := get_viewport().get_camera_3d()
		var wp := lt.center() + Vector3(0, 0.3 * lt.scale.y, 0)
		if cam and not cam.is_position_behind(wp):
			reticle.visible = true
			reticle.position = cam.unproject_position(wp) - Vector2(14, 18)
		else: reticle.visible = false
	else:
		reticle.visible = false
	compass.queue_redraw()


func _party() -> void:
	var members: Array = world.party_members()
	if members.size() <= 1:
		party_box.visible = false; return
	party_box.visible = not world.cutscene.active
	for m in members:
		var id: int = m.get_instance_id()
		if not party_rows.has(id):
			var row := UI.vbox(1)
			var l := UI.label(m.display_name + "  (" + Data.jobs[m.job]["name"] + ")", 15, UI.TEXT)
			var b := UI.bar(UI.HP, 200, 9)
			row.add_child(l); row.add_child(b)
			party_box.add_child(row)
			party_rows[id] = b
		var bar: ProgressBar = party_rows[id]
		bar.max_value = m.max_hp; bar.value = m.hp
		bar.modulate = Color(0.5, 0.5, 0.5) if m.dead else Color.WHITE


func _draw_compass() -> void:
	var w := compass.size.x
	var p: Player = world.player
	compass.draw_rect(Rect2(0, 6, w, 24), Color(0, 0, 0, 0.45))
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var f := -cam.global_transform.basis.z
	var yaw := atan2(f.x, -f.z)
	var font := ThemeDB.fallback_font
	var marks := [["N", 0.0, UI.GOLD], ["E", PI * 0.5, UI.TEXT], ["S", PI, UI.TEXT], ["W", -PI * 0.5, UI.TEXT]]
	for e in world.info["exits"]:
		var d: Vector3 = e["pos"] - p.global_position
		marks.append(["⇨ " + Data.zones[e["to"]]["name"], atan2(d.x, -d.z), Color("#9fd8ff")])
	var a: Vector3 = world.info["aetheryte"] - p.global_position
	marks.append(["✦", atan2(a.x, -a.z), Color("#8fe0ff")])
	if world.mission_runner:
		var op: Vector3 = world.mission_runner.objective_point()
		if op != Vector3.INF:
			var od := op - p.global_position
			marks.append(["◆ %dm" % int(od.length()), atan2(od.x, -od.z), Color("#ffb040")])
	for m in marks:
		var rel := wrapf(float(m[1]) - yaw, -PI, PI)
		if absf(rel) > 1.2: continue
		var x := w * 0.5 + rel / 1.2 * w * 0.5
		var size := 16 if str(m[0]).length() > 2 else 20
		compass.draw_string(font, Vector2(x - str(m[0]).length() * size * 0.25, 24), str(m[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, size, m[2])


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0: out += ","
		out += s[i]
	return out


func set_prompt(t: String) -> void:
	prompt_lbl.text = t


func set_objective(t: String) -> void:
	obj_lbl.text = t


func toast(t: String) -> void:
	var l := UI.label(t, 19, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	toast_box.add_child(l)
	_toast_t.append([l, 4.5])
	if _toast_t.size() > 6:
		_toast_t[0][0].queue_free(); _toast_t.remove_at(0)


func loot(t: String) -> void:
	toast(t)


func banner(title: String, sub: String) -> void:
	banner_lbl.text = title
	banner_sub.text = sub
	banner_lbl.modulate.a = 1.0; banner_sub.modulate.a = 1.0
	_banner_t = 6.0


func zone_banner(name: String, region: String) -> void:
	zone_lbl.text = name
	zone_sub.text = region
	zone_lbl.modulate.a = 1.0; zone_sub.modulate.a = 1.0
	_zone_t = 4.0


func show_boss(m: Monster) -> void:
	boss = m


func flash_damage(a: float) -> void:
	vignette.color.a = maxf(vignette.color.a, a * 0.5)


var _fade_tw: Tween


func set_black() -> void:
	if _fade_tw: _fade_tw.kill()
	fade.color.a = 1.0


func fade_out(t := 0.5) -> void:
	if _fade_tw: _fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(fade, "color:a", 1.0, t)


func fade_in(t := 0.5) -> void:
	if _fade_tw: _fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(fade, "color:a", 0.0, t)


func letterbox(on: bool) -> void:
	var h := 90.0 if on else 0.0
	var tw := create_tween()
	tw.tween_property(bars_top, "offset_bottom", h, 0.5)
	tw.parallel().tween_property(bars_bot, "offset_top", -h, 0.5)
