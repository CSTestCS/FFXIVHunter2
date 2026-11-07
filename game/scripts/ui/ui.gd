class_name UI
## Shared theme and widget helpers. Every menu is built in code from these so focus/gamepad
## navigation behaves the same everywhere.

const BG := Color(0.06, 0.08, 0.13, 0.92)
const BG2 := Color(0.1, 0.13, 0.2, 0.95)
const GOLD := Color(0.86, 0.74, 0.46)
const TEXT := Color(0.93, 0.92, 0.88)
const DIM := Color(0.62, 0.64, 0.7)
const BLUE := Color(0.42, 0.72, 1.0)
const HP := Color(0.36, 0.82, 0.4)
const MP := Color(0.85, 0.42, 0.85)
const STAM := Color(0.95, 0.78, 0.3)

static var _theme: Theme


static func theme() -> Theme:
	if _theme: return _theme
	var t := Theme.new()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG; panel.border_color = GOLD.darkened(0.35)
	panel.set_border_width_all(2); panel.set_corner_radius_all(6); panel.set_content_margin_all(14)
	panel.shadow_color = Color(0, 0, 0, 0.5); panel.shadow_size = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = BG2; btn.border_color = Color(0.3, 0.36, 0.5); btn.set_border_width_all(1); btn.set_corner_radius_all(4)
	btn.content_margin_left = 14; btn.content_margin_right = 14; btn.content_margin_top = 7; btn.content_margin_bottom = 7
	var hov := btn.duplicate(); hov.bg_color = Color(0.17, 0.24, 0.38); hov.border_color = BLUE
	var foc := btn.duplicate(); foc.bg_color = Color(0.2, 0.28, 0.44); foc.border_color = GOLD; foc.set_border_width_all(2)
	var prs := btn.duplicate(); prs.bg_color = Color(0.28, 0.36, 0.55)
	var dis := btn.duplicate(); dis.bg_color = Color(0.08, 0.09, 0.12); dis.border_color = Color(0.2, 0.2, 0.25)
	for k in ["Button", "OptionButton", "CheckBox"]:
		t.set_stylebox("normal", k, btn); t.set_stylebox("hover", k, hov); t.set_stylebox("focus", k, foc)
		t.set_stylebox("pressed", k, prs); t.set_stylebox("disabled", k, dis)
		t.set_color("font_color", k, TEXT); t.set_color("font_focus_color", k, Color.WHITE)
		t.set_color("font_hover_color", k, Color.WHITE); t.set_color("font_disabled_color", k, DIM.darkened(0.3))
	t.set_color("font_color", "Label", TEXT)
	var le := btn.duplicate(); le.bg_color = Color(0.03, 0.04, 0.07)
	t.set_stylebox("normal", "LineEdit", le); t.set_stylebox("focus", "LineEdit", foc)
	var bar_bg := StyleBoxFlat.new(); bar_bg.bg_color = Color(0, 0, 0, 0.6); bar_bg.set_corner_radius_all(3)
	var bar_fg := StyleBoxFlat.new(); bar_fg.bg_color = HP; bar_fg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", bar_bg); t.set_stylebox("fill", "ProgressBar", bar_fg)
	var grab := StyleBoxFlat.new(); grab.bg_color = GOLD; grab.set_corner_radius_all(4)
	var sl := StyleBoxFlat.new(); sl.bg_color = Color(0.2, 0.24, 0.32); sl.content_margin_top = 4; sl.content_margin_bottom = 4; sl.set_corner_radius_all(3)
	t.set_stylebox("slider", "HSlider", sl); t.set_stylebox("grabber_area", "HSlider", grab); t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var tab := btn.duplicate()
	t.set_stylebox("tab_selected", "TabContainer", foc); t.set_stylebox("tab_unselected", "TabContainer", tab)
	t.set_stylebox("tab_hovered", "TabContainer", hov); t.set_stylebox("panel", "TabContainer", panel)
	_theme = t
	return t


static func label(text: String, size := 20, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4 if size >= 18 else 3)
	l.horizontal_alignment = align
	return l


static func button(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_w
	if min_w <= 0.0 and text.length() > 28:
		# Long labels shrink with "..." instead of widening the whole panel off-screen.
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = text
	b.pressed.connect(func(): Sfx.play("ui_ok", -6.0); cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -14.0))
	return b


static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.theme = theme()
	return p


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h


static func bar(color: Color, w := 260.0, h := 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var fg := StyleBoxFlat.new(); fg.bg_color = color; fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", fg)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.65); bg.set_corner_radius_all(3); bg.border_color = Color(0, 0, 0, 0.9); bg.set_border_width_all(1)
	b.add_theme_stylebox_override("background", bg)
	return b


static func slider(minv: float, maxv: float, val: float, cb: Callable, step := 0.01) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv; s.max_value = maxv; s.step = step; s.value = val
	s.custom_minimum_size = Vector2(240, 26)
	s.value_changed.connect(cb)
	return s


static func scroll(child: Control, min_size := Vector2(0, 300)) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


## Row of colour swatches; calls cb(hex) when one is chosen.
static func swatches(colors: Array, current: String, cb: Callable, per_row := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = per_row
	g.add_theme_constant_override("h_separation", 4); g.add_theme_constant_override("v_separation", 4)
	for c in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 30)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(c); sb.set_corner_radius_all(4)
		sb.border_color = Color.WHITE if c == current else Color(0, 0, 0, 0.6); sb.set_border_width_all(3 if c == current else 1)
		b.add_theme_stylebox_override("normal", sb)
		var f := sb.duplicate(); f.border_color = GOLD; f.set_border_width_all(3)
		b.add_theme_stylebox_override("focus", f); b.add_theme_stylebox_override("hover", f); b.add_theme_stylebox_override("pressed", f)
		b.pressed.connect(func(): Sfx.play("ui_ok", -8.0); cb.call(c))
		g.add_child(b)
	return g


## Left/right selector: "< value >". Works with D-pad via the two arrow buttons.
static func stepper(title: String, options: Array, idx: int, cb: Callable) -> HBoxContainer:
	var h := hbox(6)
	var t := label(title, 18, DIM)
	t.custom_minimum_size.x = 150
	h.add_child(t)
	var val := label(str(options[idx]), 19, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size.x = 230
	var state := {"i": idx}
	var l := button("<", func():
		state["i"] = (state["i"] - 1 + options.size()) % options.size(); val.text = str(options[state["i"]]); cb.call(state["i"]))
	var r := button(">", func():
		state["i"] = (state["i"] + 1) % options.size(); val.text = str(options[state["i"]]); cb.call(state["i"]))
	h.add_child(l); h.add_child(val); h.add_child(r)
	return h


static func clear(n: Node) -> void:
	for c in n.get_children(): c.queue_free()


## Focus the first focusable control under n (deferred so freshly built menus work).
static func focus_first(n: Node) -> void:
	var f := func():
		var c := _find_focusable(n)
		if c: c.grab_focus()
	f.call_deferred()


static func _find_focusable(n: Node) -> Control:
	if n == null or not is_instance_valid(n): return null
	for c in n.get_children():
		if c is Control and c.visible:
			if c.focus_mode == Control.FOCUS_ALL and not (c is Button and c.disabled): return c
			var r := _find_focusable(c)
			if r: return r
	return null


## Keeps a panel inside the visible screen: the child is laid out at its natural size, placed by
## `align` (0..1 on each axis) inside the margins, and scaled down uniformly if it would not fit.
class FitBox extends Container:
	var align := Vector2(0.5, 0.5)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2.ZERO

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN or what == NOTIFICATION_RESIZED:
			for c in get_children():
				if not (c is Control) or not c.visible: continue
				var need: Vector2 = c.get_combined_minimum_size()
				need = need.max(Vector2.ONE)
				var s := minf(1.0, minf(size.x / need.x, size.y / need.y))
				c.size = need
				c.scale = Vector2(s, s)
				c.position = ((size - need * s) * align).floor()


## Wraps `child` in a FitBox filling `parent` minus margins (left, top, right, bottom).
static func fit(parent: Control, child: Control, align: Vector2, margins := Vector4(16, 16, 16, 16)) -> Container:
	var f := FitBox.new()
	f.align = align
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.offset_left = margins.x; f.offset_top = margins.y
	f.offset_right = -margins.z; f.offset_bottom = -margins.w
	parent.add_child(f)
	f.add_child(child)
	return f


## A full-screen Control that ignores the mouse, for building screen-fitted layers.
static func screen_root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.theme = theme()
	return r
