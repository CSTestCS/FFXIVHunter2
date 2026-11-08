extends Node
## Character creation, laid out like the realm's own: Race & Gender, Clan, Appearance (a feature
## list with a live editor for each), Job and city-state, Nameday & Guardian, and Name, over the
## aetherial sea or one of four other environments. A second pass customises the Warrior of Light.

const FIRST_NAMES := ["Aelis", "Cid", "Edda", "Wyn", "Rhoswen", "Torvald", "Leveva", "Kaien", "Mira", "Halric", "Y'lhana", "Sorrel", "Brynn", "Odhan", "Liesl"]
const LAST_NAMES := ["Starfall", "Ashford", "Vaellis", "Thornbury", "Dawnmere", "Kestrel", "Brightwater", "Ironbough", "Silverleaf", "Morrow"]
const ROLE_GROUPS := [["Tank", ["tank"]], ["Healer", ["healer"]], ["DPS", ["melee", "ranged", "caster"]]]
const JOB_LORE := {
	"PLD": "Sworn shields of Ul'dah's royal line, paladins guard their charges with blade and buckler, and turn aside blows meant for others.",
	"WAR": "Warriors give themselves over to the beast within, wielding great axes in a fury that shrugs off wounds that would fell another.",
	"DRK": "Dark knights walk the shadows of Ishgard, drawing on their own darkness to defend those the knights of the Holy See would not.",
	"GNB": "Gunbreakers carry a sword fused with a firing mechanism, loading aether-charged cartridges to drive home crushing combinations.",
	"WHM": "White mages call on the elements of the Twelveswood to mend wounds and cleanse ailments, as the Padjal of Gridania taught them.",
	"SCH": "Scholars of Nym command a faerie companion and the tactics of the battlefield, protecting allies before harm can reach them.",
	"AST": "Astrologians of Sharlayan and Ishgard read the stars through their cards, drawing fate itself to the aid of their companions.",
	"SGE": "Sages of Sharlayan direct floating nouliths to shield and heal, healing allies by the very blows they strike against foes.",
	"MNK": "Monks of the Fist of Rhalgr fight with their bare hands, flowing between stances and channelling chakra into devastating strikes.",
	"DRG": "Dragoons of Ishgard leap high into the air with their lances, falling upon their quarry like the wrath of the heavens.",
	"NIN": "Ninja of the Far East strike from the shadows with twin blades and mudra, weaving signs into elemental ninjutsu.",
	"SAM": "Samurai wander from Hingashi with katana in hand, gathering Sen before unleashing a single perfect cut.",
	"RPR": "Reapers bind a voidsent avatar to their scythe, harvesting the souls of their foes to fuel ever deadlier sweeps.",
	"BRD": "Bards of the forest fire their arrows in time with ancient war songs, steadying their allies' hands as they play.",
	"MCH": "Machinists of Ishgard's Skysteel workshops wield firearms and clockwork turrets, overheating their tools for a flurry of shots.",
	"DNC": "Dancers of the far shores fight with bladed chakrams, turning steps and flourishes into a deadly performance.",
	"BLM": "Black mages command the lost magicks of Mhach, swinging between astral fire and umbral ice to release overwhelming spells.",
	"SMN": "Summoners call upon the power of the primals, channelling the might of fire, wind and earth through their grimoires.",
	"RDM": "Red mages blend black and white magicks with the rapier, balancing both to unleash an elegant melee finish.",
}

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
var stage: CreatorStage
var step := "race"
var done := {"race": false, "clan": false, "appearance": false}
var wol_done := {"race": false, "clan": false, "appearance": false}
var feature_i := 0
var attire := 2
var _snapshot := {}
var _opened_value: Variant = null
var _job_group := 0
var _rebuild_t := -1.0
var _drag := ""
var _left: VBoxContainer
var _right: VBoxContainer
var _city: VBoxContainer
var _bar: HBoxContainer
var _wol_tag: Label
var _hints: Label
var _dialog: Control
var _ui: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ap = RaceData.default_appearance("hyur", "midlander", "m")
	wol = RaceData.default_appearance("hyur", "midlander", "m")
	wol["hair_color"] = "#1d1a1a"
	first = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	last = LAST_NAMES[randi() % LAST_NAMES.size()]
	stage = CreatorStage.new()
	add_child(stage)
	var layer := CanvasLayer.new(); add_child(layer)
	_ui = Control.new(); _ui.set_anchors_preset(Control.PRESET_FULL_RECT); _ui.theme = CCUI.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	# Top centre: control hints and the screen title.
	var top := VBoxContainer.new(); top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 2)
	var hp := PanelContainer.new()
	var hs := StyleBoxFlat.new(); hs.bg_color = Color(0, 0, 0, 0.55); hs.set_corner_radius_all(10)
	hs.content_margin_left = 12; hs.content_margin_right = 12; hs.content_margin_top = 1; hs.content_margin_bottom = 1
	hp.add_theme_stylebox_override("panel", hs)
	_hints = CCUI.text("", 15, HI_TXT())
	hp.add_child(_hints)
	top.add_child(hp)
	var t := CCUI.text("CHARACTER CREATION", 30, Color("#9ee0ff"), CCUI.cond(true))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 8)
	top.add_child(t)
	_wol_tag = CCUI.text("THE WARRIOR OF LIGHT", 18, CCUI.GOLD, CCUI.serif())
	_wol_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_wol_tag)
	UI.fit(_ui, top, Vector2(0.5, 0.0), Vector4(0, 18, 0, 0))
	_left = VBoxContainer.new(); _left.add_theme_constant_override("separation", 6)
	UI.fit(_ui, _left, Vector2(0.0, 0.0), Vector4(0, 22, 0, 130))
	_right = VBoxContainer.new(); _right.add_theme_constant_override("separation", 4)
	UI.fit(_ui, _right, Vector2(1.0, 0.0), Vector4(0, 34, 0, 120))
	_city = VBoxContainer.new()
	UI.fit(_ui, _city, Vector2(0.0, 1.0), Vector4(0, 0, 0, 70))
	var close := CCUI.circle("close", _ask_quit, "CANCEL", 17)
	UI.fit(_ui, close, Vector2(0.0, 1.0), Vector4(24, 0, 0, 26))
	_bar = HBoxContainer.new(); _bar.add_theme_constant_override("separation", 34)
	UI.fit(_ui, _bar, Vector2(1.0, 1.0), Vector4(0, 0, 40, 22))
	_build_bar()
	_snapshot = cur().duplicate(true)
	_go("race")
	_rebuild_preview()
	Sfx.music("title")


static func HI_TXT() -> Color:
	return Color("#f4fbff")


func cur() -> Dictionary:
	return wol if editing_wol else ap


func _done() -> Dictionary:
	return wol_done if editing_wol else done


# ----------------------------------------------------------------------------- persistent bar
func _build_bar() -> void:
	_clear(_bar)
	var pose := VBoxContainer.new(); pose.add_theme_constant_override("separation", 0)
	pose.add_child(CCUI.text("POSE", 14, HI_TXT(), CCUI.cond(true)))
	pose.add_child(CCUI.radio("Standing", not stage.unique_pose, func(): stage.set_pose(false); _build_bar()))
	pose.add_child(CCUI.radio("Unique", stage.unique_pose, func(): stage.set_pose(true); _build_bar()))
	_bar.add_child(pose)
	var att := VBoxContainer.new(); att.add_theme_constant_override("separation", 0)
	att.add_child(CCUI.text("ATTIRE", 14, HI_TXT(), CCUI.cond(true)))
	for i in 3:
		var ii := i
		att.add_child(CCUI.radio(["Race", "Job", "Smallclothes"][i], attire == i, func(): attire = ii; _build_bar(); _changed()))
	_bar.add_child(att)
	var envv := VBoxContainer.new(); envv.add_theme_constant_override("separation", 2)
	var et := CCUI.text("ENVIRONMENT", 14, HI_TXT(), CCUI.cond(true)); et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	envv.add_child(et)
	var orbs := HBoxContainer.new(); orbs.add_theme_constant_override("separation", 4)
	for i in CreatorStage.ENVS.size():
		var ii := i
		var cols: Array = CreatorStage.ENV_COLORS[i]
		orbs.add_child(CCUI.orb(cols[0], cols[1], stage.env_index == i, func(): stage.set_environment(ii); _build_bar(), CreatorStage.ENVS[i]))
	var tb := CCUI.circle("time", func(): stage.cycle_time(); _build_bar(), CreatorStage.TIMES[stage.time_index], 12)
	tb.tooltip_text = "Time of day"
	orbs.add_child(tb)
	envv.add_child(orbs)
	_bar.add_child(envv)
	_update_hints()


func _update_hints() -> void:
	if Inputs.using_pad:
		_hints.text = "Right Stick: Rotate / Tilt Camera     LT / RT: Zoom     LB / RB: Environment     B: Back"
	else:
		_hints.text = "Left Drag: Rotate Camera     Right Drag: Rotate Background     Wheel: Zoom     Middle Drag: Tilt Camera"


# ----------------------------------------------------------------------------- steps
func _go(s: String) -> void:
	if s != step:
		if s in ["race", "clan", "appearance"]: _snapshot = cur().duplicate(true)
		stage.zoom = 0.0
	step = s
	stage.clear_portrait_queue()
	stage.face_focus = false
	_clear(_left); _clear(_right); _clear(_city)
	_wol_tag.visible = editing_wol
	match s:
		"race": _step_race()
		"clan": _step_clan()
		"appearance": _step_appearance()
		"summary": _step_summary()
		"job": _step_job()
		"nameday": _step_nameday()
		"name": _step_name()
		"final": _step_final()
	UI.focus_first(_right if s != "appearance" else _left)


func _confirm_row(ok: Callable, back: Callable, ok_cap := "CONFIRM", back_cap := "BACK") -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14)
	h.add_child(CCUI.circle("ok", ok, ok_cap))
	h.add_child(CCUI.circle("back", back, back_cap))
	return h


func _lore(title: String, body: String, width := 470.0) -> void:
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_left", 46); pad.add_theme_constant_override("margin_top", 70)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	v.add_child(CCUI.title(title, 38))
	v.add_child(CCUI.text(body, 16, Color("#bfe8ff"), null, width))
	pad.add_child(v)
	_left.add_child(pad)


func _right_pad() -> VBoxContainer:
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_right", 46)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	pad.add_child(v)
	_right.add_child(pad)
	return v


func _step_race() -> void:
	var a := cur()
	_lore(RaceData.RACES[a["race"]]["name"], RaceData.RACE_LORE[a["race"]])
	var v := _right_pad()
	v.add_child(CCUI.header("Race & Gender", 280))
	var sub := CCUI.text("Select your character's race and gender.", 14, CCUI.TXT); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sub)
	for r in RaceData.RACES:
		var rr: String = r
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; row.add_theme_constant_override("separation", 4)
		var sel: bool = a["race"] == rr
		row.add_child(CCUI.item(RaceData.RACES[rr]["name"], func(): _set_race(rr, a["sex"]), sel, 30))
		for sx in ["m", "f"]:
			var s: String = sx
			row.add_child(CCUI.gender("male" if s == "m" else "female", func(): _set_race(rr, s), sel and a["sex"] == s))
		v.add_child(row)
	var cr := _confirm_row(func():
		_done()["race"] = true
		_go("clan" if not _done()["clan"] else ("appearance" if not _done()["appearance"] else "summary")),
		_back_from_edit)
	cr.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_spacer(14)); v.add_child(cr)


func _set_race(r: String, s: String) -> void:
	var a := cur()
	if a["race"] != r or a["sex"] != s:
		a["race"] = r; a["sex"] = s
		if not RaceData.RACES[r]["clans"].has(a["clan"]):
			a["clan"] = RaceData.RACES[r]["clans"][0]
			a["skin"] = RaceData.CLANS[a["clan"]]["skin"][0]
		_done()["clan"] = false; _done()["appearance"] = false
	_changed()
	_go("race")
	_focus_text(_right, RaceData.RACES[r]["name"])


func _step_clan() -> void:
	var a := cur()
	_lore(RaceData.CLANS[a["clan"]]["name"], RaceData.CLAN_LORE[a["clan"]])
	var v := _right_pad()
	v.add_child(CCUI.header("Clan", 260))
	var sub := CCUI.text("Select your character's clan.", 14); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sub)
	for c in RaceData.RACES[a["race"]]["clans"]:
		var cc: String = c
		v.add_child(CCUI.item(RaceData.CLANS[cc]["name"], func():
			a["clan"] = cc; a["skin"] = RaceData.CLANS[cc]["skin"][0]; _changed(); _go("clan"); _focus_text(_right, RaceData.CLANS[cc]["name"]),
			a["clan"] == cc, 30))
	var cr := _confirm_row(func():
		_done()["clan"] = true
		_go("appearance" if not _done()["appearance"] else "summary"), _back_from_edit)
	cr.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_spacer(14)); v.add_child(cr)


func _features() -> Array:
	var a := cur()
	var out := []
	for f in RaceData.FEATURES:
		if f.has("races") and not f["races"].has(a["race"]): continue
		if f.has("sex") and f["sex"] != a["sex"]: continue
		out.append(f)
	return out


func _step_appearance() -> void:
	var feats := _features()
	feature_i = clampi(feature_i, 0, feats.size() - 1)
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_left", 56); pad.add_theme_constant_override("margin_top", 4)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0)
	pad.add_child(v)
	_left.add_child(pad)
	v.add_child(CCUI.pill("Randomize Appearance", _randomize, 250))
	v.add_child(_spacer(4))
	v.add_child(CCUI.header("Appearance", 250, false))
	v.add_child(CCUI.text("     Customize your character's appearance.", 14))
	v.add_child(_spacer(8))
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", -6)
	for i in feats.size():
		var ii := i
		list.add_child(CCUI.bullet(feats[i]["name"], func(): _open_feature(ii, true), i == feature_i))
	v.add_child(list)
	v.add_child(_spacer(14))
	var cr := _confirm_row(func():
		_done()["appearance"] = true
		_go("summary"), _back_from_edit, "CONFIRM", "CANCEL")
	v.add_child(cr)
	_build_editor(feats[feature_i])


func _open_feature(i: int, focus_editor: bool) -> void:
	feature_i = i
	var feats := _features()
	stage.clear_portrait_queue()
	_clear(_left); _clear(_right)
	_step_appearance()
	if focus_editor:
		UI.focus_first(_right)
	stage.face_focus = feats[i].get("face", false)


func _back_to_list() -> void:
	var feats := _features()
	_focus_text(_left, "     " + feats[feature_i]["name"])


func _build_editor(f: Dictionary, keep_prev := false) -> void:
	var a := cur()
	var key: String = f["key"]
	if not keep_prev: _opened_value = a.get(key)
	stage.face_focus = f.get("face", false)
	var v := _right_pad()
	v.add_child(CCUI.header(f["name"], 250, true, false))
	v.add_child(_spacer(6))
	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_END
	var holder := HBoxContainer.new(); holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(box)
	v.add_child(holder)
	match f["kind"]:
		"slider": _slider_editor(box, key)
		"palette": _palette_editor(box, key)
		"types", "hair": _types_editor(box, key, f["kind"] == "hair")
	v.add_child(_spacer(8))
	var ok := CCUI.circle("ok", _back_to_list, "CONFIRM")
	var okr := HBoxContainer.new(); okr.alignment = BoxContainer.ALIGNMENT_END; okr.add_child(ok)
	v.add_child(okr)


func _slider_editor(box: VBoxContainer, key: String) -> void:
	var a := cur()
	var val := CCUI.text(str(int(round(float(a[key]) * 100))), 20, CCUI.HI, CCUI.cond(true))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var approx := CCUI.text("", 14)
	approx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if key == "height":
		approx.text = "Approximately %d cm" % stage.height_cm()
		box.add_child(approx)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; row.add_theme_constant_override("separation", 10)
	var prev := CCUI.text("PREVIOUS  %d" % int(round(float(_opened_value) * 100)), 13, CCUI.HI, CCUI.cond(true))
	var labels := VBoxContainer.new()
	var names: Array = {"height": ["Tall", "Short"], "ear_size": ["Long", "Short"], "tail_length": ["Long", "Short"]}.get(key, ["", ""])
	labels.add_child(CCUI.text(names[0], 13))
	var mid := Control.new(); mid.size_flags_vertical = Control.SIZE_EXPAND_FILL; labels.add_child(mid)
	labels.add_child(CCUI.text(names[1], 13))
	var s := VSlider.new()
	s.min_value = 0; s.max_value = 100; s.step = 1; s.value = round(float(a[key]) * 100)
	s.custom_minimum_size = Vector2(22, 190)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(x: float):
		a[key] = x / 100.0; val.text = str(int(x)); _changed()
		if key == "height": get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(approx): approx.text = "Approximately %d cm" % stage.height_cm()))
	row.add_child(prev); row.add_child(s); row.add_child(labels)
	box.add_child(val)
	box.add_child(row)


func _palette_editor(box: VBoxContainer, key: String) -> void:
	var a := cur()
	var pal_row := HBoxContainer.new(); pal_row.alignment = BoxContainer.ALIGNMENT_END; pal_row.add_theme_constant_override("separation", 10)
	var cell := Vector2(15, 11) if key in ["hair_color", "feature_color", "tattoo_color", "paint_color"] else Vector2(15, 18)
	var second := {"hair_color": ["highlights", "highlight_color", "Highlights"], "eye_color": ["heterochromia", "eye_color2", "Heterochromia"]}
	if second.has(key) and a.get(second[key][0], false):
		var k2: String = second[key][1]
		pal_row.add_child(CCUI.palette(RaceData.palette(k2, a["clan"]), a[k2], a[k2], func(h): a[k2] = h; _changed(); _reopen_editor(), cell))
	pal_row.add_child(CCUI.palette(RaceData.palette(key, a["clan"]), a[key], str(_opened_value), func(h): a[key] = h; _changed(); _reopen_editor(), cell))
	box.add_child(pal_row)
	if second.has(key):
		var flag: String = second[key][0]
		var cb := CheckBox.new(); cb.text = second[key][2]; cb.button_pressed = a.get(flag, false)
		cb.add_theme_font_size_override("font_size", 15)
		cb.toggled.connect(func(on: bool): a[flag] = on; _changed(); _reopen_editor())
		var r := HBoxContainer.new(); r.alignment = BoxContainer.ALIGNMENT_END; r.add_child(cb)
		box.add_child(r)


## Rebuilds the open editor (after a change) and puts focus back on the same control.
func _reopen_editor() -> void:
	var fo := get_viewport().gui_get_focus_owner()
	var path := _index_path(_right, fo) if fo and _right.is_ancestor_of(fo) else []
	stage.clear_portrait_queue()
	_clear(_right)
	_build_editor(_features()[feature_i], true)
	if not path.is_empty():
		var n := _right
		for i in path:
			if n == null or i >= n.get_child_count(): n = null; break
			n = n.get_child(i)
		if n is Control: (n as Control).grab_focus.call_deferred()


static func _index_path(root: Node, n: Node) -> Array:
	var out := []
	while n and n != root:
		out.push_front(n.get_index())
		n = n.get_parent()
	return out


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _types_editor(box: VBoxContainer, key: String, hair: bool) -> void:
	var a := cur()
	var opts: Array = RaceData.HAIRSTYLES.map(func(h): return h["name"]) if hair else RaceData.options(key)
	var name_lbl := CCUI.text(opts[clampi(int(a[key]), 0, opts.size() - 1)], 17, CCUI.HI, CCUI.cond(true))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if key == "voice":
		for i in opts.size():
			var ii := i
			box.add_child(CCUI.item(opts[i], func(): a[key] = ii; _reopen_editor(), int(a[key]) == i, 20))
		return
	var g := GridContainer.new(); g.columns = 4
	g.add_theme_constant_override("h_separation", 4); g.add_theme_constant_override("v_separation", 4)
	for i in opts.size():
		var ii := i
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 66)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = opts[i]
		var sel := int(a[key]) == i
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.03, 0.12, 0.28, 0.85)
		sb.border_color = Color(0.4, 1.0, 0.7) if sel else Color(0.5, 0.8, 1.0, 0.5); sb.set_border_width_all(2 if sel else 1)
		sb.set_content_margin_all(2)
		b.add_theme_stylebox_override("normal", sb)
		var f := sb.duplicate(); f.border_color = CCUI.HI; f.set_border_width_all(2)
		for s in ["hover", "focus", "pressed", "hover_pressed"]: b.add_theme_stylebox_override(s, f)
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT); tr.offset_left = 2; tr.offset_top = 2; tr.offset_right = -2; tr.offset_bottom = -2
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
		var num := CCUI.text(str(i + 1), 12, CCUI.HI, CCUI.cond(true)); num.position = Vector2(5, 2)
		b.add_child(num)
		b.focus_entered.connect(func(): name_lbl.text = opts[ii]; Sfx.play("ui_move", -14.0))
		b.mouse_entered.connect(func(): name_lbl.text = opts[ii])
		b.pressed.connect(func(): Sfx.play("ui_ok", -8.0); a[key] = ii; _changed(); _reopen_editor())
		g.add_child(b)
		var variant := a.duplicate(true)
		variant[key] = ii
		stage.portrait(variant, func(tex: Texture2D): if is_instance_valid(tr): tr.texture = tex, hair)
	box.add_child(g)
	box.add_child(name_lbl)


func _step_summary() -> void:
	var a := cur()
	var d := _done()
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_left", 46); pad.add_theme_constant_override("margin_top", 70)
	pad.add_child(CCUI.text("Select the features you wish to change from the list on the right. Those marked with ??? have yet to be confirmed.", 15, CCUI.TXT, null, 320))
	_left.add_child(pad)
	var v := _right_pad()
	var rows := [["Race & Gender", "%s, %s" % [RaceData.RACES[a["race"]]["name"], "Male" if a["sex"] == "m" else "Female"], "race"],
		["Clan", RaceData.CLANS[a["clan"]]["name"], "clan"], ["Appearance", "Customized", "appearance"]]
	for r in rows:
		var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; h.add_theme_constant_override("separation", 5)
		h.add_child(CCUI.text(str(r[0]).to_upper(), 14, CCUI.HI, CCUI.cond(true)))
		h.add_child(CCUI.glyph("square", 10))
		v.add_child(h)
		var st: String = r[2]
		v.add_child(CCUI.item(r[1] if d[st] else "? ? ?", func(): _snapshot = cur().duplicate(true); _go(st), false, 28))
	v.add_child(_spacer(12))
	var all_done: bool = d["race"] and d["clan"] and d["appearance"]
	var cr := HBoxContainer.new(); cr.alignment = BoxContainer.ALIGNMENT_END; cr.add_theme_constant_override("separation", 14)
	if all_done: cr.add_child(CCUI.circle("ok", func(): _go("job"), "PROCEED"))
	cr.add_child(CCUI.circle("back", _summary_back, "BACK"))
	v.add_child(cr)


func _summary_back() -> void:
	if editing_wol:
		editing_wol = false
		_changed()
		_go("final")
	else:
		_ask_quit()


## Cancel out of race/clan/appearance: restore what the character looked like on entering.
func _back_from_edit() -> void:
	var a := cur()
	if not _snapshot.is_empty():
		a.clear(); a.merge(_snapshot.duplicate(true))
	_changed()
	_go("summary")


func _step_job() -> void:
	var sel := wol_job if editing_wol else job
	var jd: Dictionary = Data.jobs[sel]
	var body := "%s\n\nRole: %s     Weapon: %s     Gauge: %s" % [JOB_LORE.get(sel, ""), JobData.ROLE_NAMES[jd["role"]], ItemData.WEAPON_NAMES[jd["weapon"]], jd["gauge_name"]]
	_lore(jd["name"], body, 480)
	if not editing_wol:
		var band := PanelContainer.new()
		var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.05, 0.08, 0.14, 0.65); bs.content_margin_left = 46; bs.content_margin_right = 30
		bs.content_margin_top = 8; bs.content_margin_bottom = 8
		band.add_theme_stylebox_override("panel", bs)
		var cv := VBoxContainer.new()
		cv.add_child(CCUI.text("Your story begins near", 14))
		cv.add_child(CCUI.title(Data.zones[jd["city"]]["name"], 30))
		cv.add_child(CCUI.text(RaceData.CITY_LORE.get(jd["city"], ""), 15, Color("#bfe8ff"), null, 520))
		band.add_child(cv)
		_city.add_child(band)
	var v := _right_pad()
	v.add_child(CCUI.header("Job", 260))
	var sub := CCUI.text("Select the Warrior of Light's job." if editing_wol else "Select your starting job and city-state.", 14); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sub)
	for gi in ROLE_GROUPS.size():
		var g: Array = ROLE_GROUPS[gi]
		var ggi := gi
		var bar := CCUI.pill(str(g[0]) + "        ", func(): _job_group = ggi; _go("job"), 230, 16)
		bar.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var arrow := CCUI.glyph("down" if gi == _job_group else "left", 14)
		arrow.position = Vector2(204, 8)
		bar.add_child(arrow)
		var br := HBoxContainer.new(); br.alignment = BoxContainer.ALIGNMENT_END; br.add_child(bar)
		v.add_child(br)
		if gi != _job_group: continue
		for j in Data.jobs:
			var jj: String = j
			if not g[1].has(Data.jobs[jj]["role"]): continue
			v.add_child(CCUI.item(Data.jobs[jj]["name"], func():
				if editing_wol: wol_job = jj
				else: job = jj
				_changed(); _go("job"); _focus_text(_right, Data.jobs[jj]["name"]), jj == sel, 20))
	var cr := _confirm_row(func(): _go("name" if editing_wol else "nameday"), func(): _go("summary"))
	cr.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_spacer(10)); v.add_child(cr)


static func _ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]: return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]


func _step_nameday() -> void:
	_lore(RaceData.DEITIES[deity], "%s\n\nNameday: the %s Sun of the %s" % [RaceData.DEITY_LORE[deity], _ordinal(int(nameday[0])), RaceData.MOONS[int(nameday[1])]], 440)
	var v := _right_pad()
	v.add_child(CCUI.header("Nameday", 300))
	var mr := HBoxContainer.new(); mr.alignment = BoxContainer.ALIGNMENT_END; mr.add_theme_constant_override("separation", 6)
	mr.add_child(CCUI.circle("prev", func(): nameday[1] = (int(nameday[1]) + 11) % 12; _go("nameday"), "", 13))
	var ml := CCUI.text(RaceData.MOONS[int(nameday[1])], 22, CCUI.HI, CCUI.cond(true)); ml.custom_minimum_size.x = 170; ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mr.add_child(ml)
	mr.add_child(CCUI.circle("next", func(): nameday[1] = (int(nameday[1]) + 1) % 12; _go("nameday"), "", 13))
	v.add_child(mr)
	var g := GridContainer.new(); g.columns = 8
	g.add_theme_constant_override("h_separation", 2); g.add_theme_constant_override("v_separation", 2)
	for d in 32:
		var dd := d + 1
		var b := CCUI.item(str(dd), func(): nameday[0] = dd; _go("nameday"); _focus_text(_right, str(dd)), int(nameday[0]) == dd, 17)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(34, 26)
		g.add_child(b)
	var gr := HBoxContainer.new(); gr.alignment = BoxContainer.ALIGNMENT_END; gr.add_child(g)
	v.add_child(gr)
	v.add_child(_spacer(8))
	v.add_child(CCUI.header("Guardian", 300))
	var dg := GridContainer.new(); dg.columns = 2
	dg.add_theme_constant_override("h_separation", 10); dg.add_theme_constant_override("v_separation", -6)
	for i in RaceData.DEITIES.size():
		var ii := i
		dg.add_child(CCUI.item(RaceData.DEITIES[i].split(",")[0], func(): deity = ii; _go("nameday"); _focus_text(_right, RaceData.DEITIES[ii].split(",")[0]), deity == i, 18))
	var dr := HBoxContainer.new(); dr.alignment = BoxContainer.ALIGNMENT_END; dr.add_child(dg)
	v.add_child(dr)
	var cr := _confirm_row(func(): _go("name"), func(): _go("job"))
	cr.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_spacer(8)); v.add_child(cr)


func _step_name() -> void:
	var v := _right_pad()
	v.add_child(CCUI.header("Name", 300))
	var err := CCUI.text("", 14, Color("#ffb0a0")); err.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if editing_wol:
		_lore("The Warrior of Light", "The hero of the realm, whose deeds are sung in every city. You will meet them on your journey. How does the realm know its hero?", 440)
		var sub := CCUI.text("Enter the Warrior of Light's name.", 14); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(sub)
		var le := LineEdit.new(); le.text = wol_name; le.max_length = 32; le.custom_minimum_size.x = 300
		le.text_changed.connect(func(t): wol_name = t)
		v.add_child(le)
		v.add_child(err)
		var cr := _confirm_row(func():
			if wol_name.strip_edges() == "": err.text = "Please enter a name."; return
			editing_wol = false; _changed(); _go("final"), func(): _go("job"))
		cr.alignment = BoxContainer.ALIGNMENT_END
		v.add_child(_spacer(10)); v.add_child(cr)
		return
	var jd: Dictionary = Data.jobs[job]
	_lore(first + " " + last, "Your adventure begins on the road outside %s, as a %s." % [Data.zones[jd["city"]]["name"], jd["name"]], 440)
	var sub2 := CCUI.text("Enter your character's name.", 14); sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sub2)
	for k in [["Forename", "first"], ["Surname", "last"]]:
		var l := CCUI.text(k[0], 15); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(l)
		var le := LineEdit.new(); le.text = first if k[1] == "first" else last; le.max_length = 15; le.custom_minimum_size.x = 300
		var which: String = k[1]
		le.text_changed.connect(_set_name.bind(which))
		v.add_child(le)
	var rr := HBoxContainer.new(); rr.alignment = BoxContainer.ALIGNMENT_END
	rr.add_child(CCUI.pill("Random Name", func():
		first = FIRST_NAMES[randi() % FIRST_NAMES.size()]; last = LAST_NAMES[randi() % LAST_NAMES.size()]; _go("name"), 180, 15))
	v.add_child(_spacer(6)); v.add_child(rr)
	v.add_child(err)
	var cr2 := _confirm_row(func():
		var e := _name_error()
		if e != "": err.text = e; return
		_go("final"), func(): _go("nameday"))
	cr2.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_spacer(6)); v.add_child(cr2)


func _set_name(t: String, which: String) -> void:
	if which == "first": first = t
	else: last = t


func _name_error() -> String:
	for n in [first.strip_edges(), last.strip_edges()]:
		if n.length() < 2: return "Forename and surname need at least 2 letters each."
	return ""


func _step_final() -> void:
	var jd: Dictionary = Data.jobs[job]
	_lore(first + " " + last, "%s %s of the %s.\n\n%s, born on the %s Sun of the %s under %s." % [
		RaceData.RACES[ap["race"]]["name"], "man" if ap["sex"] == "m" else "woman", RaceData.CLANS[ap["clan"]]["name"],
		jd["name"], _ordinal(int(nameday[0])), RaceData.MOONS[int(nameday[1])], RaceData.DEITIES[deity]], 440)
	var v := _right_pad()
	v.add_child(CCUI.header("Confirmation", 320))
	for r in [["Race", "%s, %s" % [RaceData.RACES[ap["race"]]["name"], RaceData.CLANS[ap["clan"]]["name"]]], ["Job", jd["name"]],
			["City-state", Data.zones[jd["city"]]["name"]], ["Guardian", RaceData.DEITIES[deity].split(",")[0]]]:
		v.add_child(_pair(r[0], r[1]))
	v.add_child(_spacer(12))
	v.add_child(CCUI.header("The Warrior of Light", 320))
	v.add_child(_pair("Name", wol_name))
	v.add_child(_pair("Race", "%s, %s" % [RaceData.RACES[wol["race"]]["name"], RaceData.CLANS[wol["clan"]]["name"]]))
	v.add_child(_pair("Job", Data.jobs[wol_job]["name"]))
	var cw := HBoxContainer.new(); cw.alignment = BoxContainer.ALIGNMENT_END
	cw.add_child(CCUI.pill("Customize the Warrior of Light", func():
		editing_wol = true; attire = 1; _build_bar(); _changed(); _go("race"), 290, 15))
	v.add_child(_spacer(4)); v.add_child(cw)
	var cr := _confirm_row(_begin, func(): _go("name"), "BEGIN", "BACK")
	cr.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_spacer(14)); v.add_child(cr)


func _pair(k: String, val: String) -> HBoxContainer:
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; h.add_theme_constant_override("separation", 12)
	h.add_child(CCUI.text(k, 15, CCUI.DIM))
	h.add_child(CCUI.text(val, 19, CCUI.HI, CCUI.cond(true)))
	return h


func _spacer(h: float) -> Control:
	var c := Control.new(); c.custom_minimum_size.y = h; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _focus_text(root: Node, t: String) -> void:
	var f := func():
		var b := _find_button(root, t)
		if b: b.grab_focus()
	f.call_deferred()


func _find_button(n: Node, t: String) -> Button:
	for c in n.get_children():
		if c is Button and c.text == t: return c
		var r := _find_button(c, t)
		if r: return r
	return null


# ----------------------------------------------------------------------------- appearance helpers
func _randomize() -> void:
	var a := cur()
	var clan: String = a["clan"]
	for k in ["height", "muscle", "bust", "tail_length", "ear_size"]: a[k] = snappedf(randf(), 0.01)
	for k in ["face", "eye_shape", "brows", "mouth", "iris"]: a[k] = randi() % RaceData.options(k).size()
	a["hair_style"] = randi() % RaceData.HAIRSTYLES.size()
	var pick := func(k: String) -> String:
		var p: Array = RaceData.palette(k, clan)
		return p[randi() % p.size()]
	var skins: Array = RaceData.palette("skin", clan)
	a["skin"] = skins[randi() % 48]
	a["hair_color"] = pick.call("hair_color")
	a["highlights"] = randf() < 0.25
	a["highlight_color"] = pick.call("highlight_color")
	a["eye_color"] = pick.call("eye_color")
	a["heterochromia"] = randf() < 0.1
	a["eye_color2"] = pick.call("eye_color2")
	a["lip_color"] = pick.call("lip_color")
	a["feature_color"] = pick.call("feature_color")
	a["facial_feature"] = 0 if randf() < 0.6 else randi() % RaceData.FACIAL_FEATURES.size()
	a["tattoo"] = 0 if randf() < 0.75 else randi() % RaceData.TATTOOS.size()
	a["face_paint"] = 0 if randf() < 0.75 else randi() % RaceData.FACE_PAINTS.size()
	a["tattoo_color"] = pick.call("tattoo_color")
	a["paint_color"] = pick.call("paint_color")
	a["fangs"] = randi() % RaceData.FANGS.size() if a["race"] in ["miqote", "hrothgar", "aura", "viera", "roegadyn"] else 0
	a["voice"] = randi() % RaceData.VOICES.size()
	_changed()
	_go("appearance")


func _gear() -> Dictionary:
	var j := wol_job if editing_wol else job
	match attire:
		0:
			return {"armor": {"body": 0, "legs": 0, "feet": 0}, "dyes": {"body": "#c8b89a", "legs": "#5a4a3a", "feet": "#3a2e24"}}
		1:
			if editing_wol:
				return {"armor": {"body": 6, "legs": 6, "feet": 6}, "dyes": {"body": "#e8e4f0", "legs": "#3a3a4a", "feet": "#2a2a30"}, "weapon": Data.jobs[j]["weapon"], "tier": 6}
			var role_dye: String = {"tank": "#4a6a9a", "healer": "#e8e4dc", "melee": "#8a3a2a", "ranged": "#4a6a3a", "caster": "#4a2a6a"}[Data.jobs[j]["role"]]
			return {"armor": {"body": 2, "legs": 2, "feet": 2}, "dyes": {"body": role_dye, "legs": "#3a3438", "feet": "#2a2420"}, "weapon": Data.jobs[j]["weapon"], "tier": 2}
	return {}


func _changed() -> void:
	_rebuild_t = 0.12


func _rebuild_preview() -> void:
	stage.show_character(cur(), _gear())


# ----------------------------------------------------------------------------- input
func _process(delta: float) -> void:
	if _rebuild_t > 0.0:
		_rebuild_t -= delta
		if _rebuild_t <= 0.0: _rebuild_preview()
	stage.yaw += (Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left")) * delta * 2.2
	stage.pitch = clampf(stage.pitch + (Input.get_action_strength("cam_down") - Input.get_action_strength("cam_up")) * delta * 40.0, -15.0, 40.0)
	var trig := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(trig) > 0.15: stage.zoom = clampf(stage.zoom + trig * delta * 1.2, 0.0, 1.0)


func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or e is InputEventKey or e is InputEventMouseButton:
		_update_hints()


func _unhandled_input(e: InputEvent) -> void:
	if _dialog and is_instance_valid(_dialog):
		if e.is_action_pressed("ui_cancel"): _dialog.queue_free(); _dialog = null; get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_LEFT: _drag = "cam"
				MOUSE_BUTTON_RIGHT: _drag = "bg"
				MOUSE_BUTTON_MIDDLE: _drag = "tilt"
				MOUSE_BUTTON_WHEEL_UP: stage.zoom = clampf(stage.zoom + 0.08, 0.0, 1.0)
				MOUSE_BUTTON_WHEEL_DOWN: stage.zoom = clampf(stage.zoom - 0.08, 0.0, 1.0)
		else:
			_drag = ""
	elif e is InputEventMouseMotion and _drag != "":
		var rel: Vector2 = (e as InputEventMouseMotion).relative
		match _drag:
			"cam":
				stage.yaw -= rel.x * 0.008
				stage.pitch = clampf(stage.pitch + rel.y * 0.12, -15.0, 40.0)
			"bg": stage.bg_rot += rel.x * 0.006
			"tilt": stage.pitch = clampf(stage.pitch + rel.y * 0.2, -15.0, 40.0)
	if e.is_action_pressed("tab_next"): stage.set_environment(stage.env_index + 1); _build_bar()
	elif e.is_action_pressed("tab_prev"): stage.set_environment(stage.env_index - 1); _build_bar()
	elif e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	Sfx.play("ui_back", -8.0)
	match step:
		"race", "clan": _back_from_edit()
		"appearance":
			var fo := get_viewport().gui_get_focus_owner()
			if fo and _right.is_ancestor_of(fo): _back_to_list()
			else: _back_from_edit()
		"summary": _summary_back()
		"job": _go("summary")
		"nameday": _go("job")
		"name": _go("job" if editing_wol else "nameday")
		"final": _go("name")


func _ask_quit() -> void:
	if _dialog and is_instance_valid(_dialog): return
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	_dialog = dim
	var p := PanelContainer.new()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12)
	v.add_child(CCUI.text("Return to the title screen?\nThis character will not be saved.", 18, CCUI.HI, null, 360))
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 16)
	h.add_child(CCUI.pill("Return to Title", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), 170, 16))
	h.add_child(CCUI.pill("Keep Creating", func(): dim.queue_free(); _dialog = null; UI.focus_first(_right), 170, 16))
	v.add_child(h)
	p.add_child(v)
	UI.fit(dim, p, Vector2(0.5, 0.5))
	UI.focus_first(h)


func _begin() -> void:
	if _name_error() != "":
		_go("name")
		return
	var c := {"name": first.strip_edges() + " " + last.strip_edges(), "appearance": ap, "job": job, "nameday": nameday, "deity": deity,
		"wol": {"appearance": wol, "job": wol_job, "name": wol_name}}
	Game.new_game(Game.new_slot, c)
