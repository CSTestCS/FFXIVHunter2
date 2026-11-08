class_name CCUI
## Widgets for the character creator, styled after the realm's own creation screens: thin glowing
## cyan text over the aetherial sea, condensed list items with a light streak on selection,
## round confirm/back buttons, colour grids and environment orbs.

const TXT := Color("#e2f4ff")
const DIM := Color("#a8d8f4")
const ACC := Color("#5cc8ff")
const HI := Color("#ffffff")
const GOLD := Color("#f2dc98")
const GLOW := Color(0.12, 0.45, 0.95, 0.55)

static var _cond: FontFile
static var _cond_med: FontFile
static var _serif: FontFile
static var _theme: Theme


static func cond(medium := false) -> Font:
	if _cond == null:
		_cond = load("res://assets/fonts/BarlowSemiCondensed-Regular.ttf")
		_cond_med = load("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")
	return _cond_med if medium else _cond


static func serif() -> Font:
	if _serif == null: _serif = load("res://assets/fonts/Cinzel.ttf")
	return _serif


static func theme() -> Theme:
	if _theme: return _theme
	var t := Theme.new()
	t.default_font = cond()
	t.default_font_size = 18
	var empty := StyleBoxEmpty.new()
	for k in ["Button", "CheckBox"]:
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			t.set_stylebox(s, k, empty)
		t.set_color("font_color", k, TXT); t.set_color("font_hover_color", k, HI); t.set_color("font_focus_color", k, HI)
		t.set_color("font_pressed_color", k, HI); t.set_color("font_hover_pressed_color", k, HI)
		t.set_color("font_outline_color", k, GLOW); t.set_constant("outline_size", k, 5)
	t.set_color("font_color", "Label", TXT)
	t.set_color("font_outline_color", "Label", GLOW); t.set_constant("outline_size", "Label", 5)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.02, 0.08, 0.2, 0.75); le.border_color = Color(0.35, 0.75, 1.0, 0.7); le.set_border_width_all(1)
	le.set_corner_radius_all(3); le.content_margin_left = 10; le.content_margin_right = 10; le.content_margin_top = 6; le.content_margin_bottom = 6
	var lef := le.duplicate(); lef.border_color = HI; lef.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", le); t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", HI); t.set_font_size("font_size", "LineEdit", 22)
	var track := StyleBoxFlat.new(); track.bg_color = Color(0.1, 0.3, 0.55, 0.8); track.content_margin_left = 2; track.content_margin_right = 2
	var fill := StyleBoxFlat.new(); fill.bg_color = Color(0.4, 0.8, 1.0, 0.9); fill.content_margin_left = 2; fill.content_margin_right = 2
	t.set_stylebox("slider", "VSlider", track); t.set_stylebox("grabber_area", "VSlider", fill); t.set_stylebox("grabber_area_highlight", "VSlider", fill)
	var grab := _grab_tex()
	t.set_icon("grabber", "VSlider", grab); t.set_icon("grabber_highlight", "VSlider", grab)
	var dlg := StyleBoxFlat.new(); dlg.bg_color = Color(0.02, 0.06, 0.16, 0.94); dlg.border_color = Color(0.4, 0.75, 1.0, 0.8)
	dlg.set_border_width_all(1); dlg.set_corner_radius_all(4); dlg.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", dlg)
	_theme = t
	return t


static func _grab_tex() -> Texture2D:
	var img := Image.create(22, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.96, 1.0))
	for x in 22:
		img.set_pixel(x, 0, ACC); img.set_pixel(x, 7, ACC)
	return ImageTexture.create_from_image(img)


static func text(t: String, size := 16, col := TXT, font: Font = null, width := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font: l.add_theme_font_override("font", font)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Large serif heading (lowercase letters render as small capitals in Cinzel).
static func title(t: String, size := 40) -> Label:
	var l := text(t, size, HI, serif())
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.4, 0.9, 0.45))
	return l


## Small symbols drawn as shapes, so they never depend on what fonts a PC has installed.
class Glyph extends Control:
	var kind := "square"
	var col := Color.WHITE
	var sz := 10.0

	func _init(k := "square", s := 10.0, c := Color.WHITE) -> void:
		kind = k; sz = s; col = c
		custom_minimum_size = Vector2(s, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_color(c: Color) -> void:
		col = c
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := sz * 0.5
		var w := maxf(1.5, sz * 0.11)
		match kind:
			"square":
				draw_rect(Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), col)
			"bullet":
				draw_circle(c, r * 0.45, col)
			"male":
				var o := c + Vector2(-r * 0.18, r * 0.18)
				draw_arc(o, r * 0.5, 0, TAU, 24, col, w, true)
				var tip := c + Vector2(r * 0.72, -r * 0.72)
				draw_line(o + Vector2(r * 0.35, -r * 0.35), tip, col, w, true)
				draw_line(tip, tip + Vector2(-r * 0.5, 0), col, w, true)
				draw_line(tip, tip + Vector2(0, r * 0.5), col, w, true)
			"female":
				var o := c + Vector2(0, -r * 0.28)
				draw_arc(o, r * 0.48, 0, TAU, 24, col, w, true)
				draw_line(o + Vector2(0, r * 0.48), c + Vector2(0, r * 0.95), col, w, true)
				draw_line(c + Vector2(-r * 0.35, r * 0.6), c + Vector2(r * 0.35, r * 0.6), col, w, true)
			"down":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.3), c + Vector2(r * 0.6, -r * 0.3), c + Vector2(0, r * 0.4)]), col)
			"left":
				draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.3, -r * 0.6), c + Vector2(r * 0.3, r * 0.6), c + Vector2(-r * 0.4, 0)]), col)


static func glyph(kind: String, size := 10.0, col := HI) -> Glyph:
	return Glyph.new(kind, size, col)


## Male / female selector button with a drawn symbol.
static func gender(kind: String, cb: Callable, selected: bool) -> Button:
	var b := item("", cb, selected, 24)
	b.custom_minimum_size = Vector2(30, 40)
	var off := Color(0.65, 0.85, 1.0, 0.7)
	var g := glyph(kind, 20, HI if selected else off)
	g.set_anchors_preset(Control.PRESET_CENTER)
	g.position = Vector2(5, 10)
	b.add_child(g)
	var hl := func(on: bool): g.set_color(HI if on or selected else off)
	b.mouse_entered.connect(hl.bind(true)); b.mouse_exited.connect(func(): hl.call(b.has_focus()))
	b.focus_entered.connect(hl.bind(true)); b.focus_exited.connect(hl.bind(false))
	return b


## Header marked with a small square and a thin glowing rule beneath it.
static func header(t: String, width := 300.0, right := true, caps := true) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph("square", 10))
	var l := text(t.to_upper() if caps else t, 14 if caps else 16, HI, cond(true))
	if caps: l.add_theme_constant_override("outline_size", 4)
	row.add_child(l)
	v.add_child(row)
	var rule := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(ACC, 0.0) if right else Color(ACC, 0.9)); g.set_color(1, Color(ACC, 0.9) if right else Color(ACC, 0.0))
	if right:
		g.add_point(0.15, Color(ACC, 0.9))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.width = 256; gt.height = 2
	rule.texture = gt
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.custom_minimum_size = Vector2(width, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	return v


static func _streak(right_align: bool) -> TextureRect:
	var s := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.85, 1.0])
	g.colors = PackedColorArray([Color(0.2, 0.6, 1.0, 0.0), Color(0.3, 0.75, 1.0, 0.35), Color(0.75, 0.95, 1.0, 0.75), Color(0.4, 0.8, 1.0, 0.0)])
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.width = 256; gt.height = 1
	if not right_align:
		gt.fill_from = Vector2(1, 0); gt.fill_to = Vector2(0, 0)
	s.texture = gt
	s.stretch_mode = TextureRect.STRETCH_SCALE
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.offset_top = 6; s.offset_bottom = -4
	s.offset_left = -60 if right_align else -6
	s.offset_right = 6 if right_align else 60
	s.show_behind_parent = true
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## A list entry. Selected (or focused/hovered) entries show a light streak behind the text.
static func item(t: String, cb: Callable, selected := false, size := 28, right_align := true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_align else HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", cond(true))
	if selected: b.add_theme_color_override("font_color", HI)
	var s := _streak(right_align)
	s.visible = selected
	s.modulate.a = 1.0
	b.add_child(s)
	var show := func(on: bool): s.visible = on or selected; s.modulate.a = 1.0 if selected else 0.55
	b.mouse_entered.connect(show.bind(true)); b.mouse_exited.connect(func(): show.call(b.has_focus()))
	b.focus_entered.connect(show.bind(true)); b.focus_exited.connect(show.bind(false))
	b.focus_entered.connect(func(): Sfx.play("ui_move", -14.0))
	b.pressed.connect(func(): Sfx.play("ui_ok", -8.0); cb.call())
	return b


## Bulleted appearance-list entry.
static func bullet(t: String, cb: Callable, selected := false) -> Button:
	var b := item("     " + t, cb, selected, 17, false)
	b.add_theme_font_override("font", cond())
	var g := glyph("bullet", 10)
	g.position = Vector2(2, 8)
	b.add_child(g)
	return b


## Round icon button: "ok" (check), "back" (arrow), "close" (cross) or "time" (clock).
class CircleButton extends Button:
	var kind := "ok"
	var caption: Label
	var radius := 21.0

	func _init(k := "ok", cap := "", r := 21.0) -> void:
		kind = k
		radius = r
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(r * 2 + 6, r * 2 + 6)
		if cap != "":
			caption = Label.new()
			caption.text = cap
			caption.add_theme_font_size_override("font_size", 13)
			caption.add_theme_font_override("font", CCUI.cond(true))
			caption.add_theme_color_override("font_color", CCUI.HI)
			caption.position = Vector2(-20, r * 2 + 4)
			caption.size = Vector2(r * 2 + 46, 16)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.visible = false
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(caption)
		mouse_entered.connect(_hl.bind(true)); mouse_exited.connect(func(): _hl(has_focus()))
		focus_entered.connect(_hl.bind(true)); focus_exited.connect(_hl.bind(false))
		focus_entered.connect(func(): Sfx.play("ui_move", -14.0))
		pressed.connect(func(): Sfx.play("ui_back" if kind == "back" or kind == "close" else "ui_ok", -8.0))

	func _hl(on: bool) -> void:
		if caption: caption.visible = on
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var on := has_focus() or is_hovered()
		var col := CCUI.HI if on else Color("#bfe8ff")
		draw_circle(c, radius + 3, Color(0.2, 0.6, 1.0, 0.28 if on else 0.12))
		draw_circle(c, radius, Color(0.02, 0.1, 0.25, 0.55))
		draw_arc(c, radius, 0, TAU, 40, col, 2.5, true)
		var r := radius
		match kind:
			"ok":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, 0), c + Vector2(-r * 0.1, r * 0.38), c + Vector2(r * 0.5, -r * 0.42)]), col, 3.0, true)
			"back":
				draw_line(c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, 0), col, 3.0, true)
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.42), c + Vector2(-r * 0.48, 0), c + Vector2(-r * 0.05, r * 0.42)]), col, 3.0, true)
			"close":
				draw_line(c + Vector2(-r * 0.38, -r * 0.38), c + Vector2(r * 0.38, r * 0.38), col, 3.0, true)
				draw_line(c + Vector2(-r * 0.38, r * 0.38), c + Vector2(r * 0.38, -r * 0.38), col, 3.0, true)
			"time":
				draw_line(c, c + Vector2(0, -r * 0.55), col, 2.0, true)
				draw_line(c, c + Vector2(r * 0.4, 0), col, 2.0, true)
			"prev":
				draw_polyline(PackedVector2Array([c + Vector2(r * 0.2, -r * 0.45), c + Vector2(-r * 0.25, 0), c + Vector2(r * 0.2, r * 0.45)]), col, 3.0, true)
			"next":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.45), c + Vector2(r * 0.25, 0), c + Vector2(-r * 0.2, r * 0.45)]), col, 3.0, true)


static func circle(kind: String, cb: Callable, cap := "", r := 21.0) -> CircleButton:
	var b := CircleButton.new(kind, cap, r)
	b.pressed.connect(cb)
	return b


## Outlined pill button, e.g. "Randomize Appearance".
static func pill(t: String, cb: Callable, width := 260.0, size := 17) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(width, 30)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.08, 0.2, 0.55); sb.border_color = Color(0.7, 0.9, 1.0, 0.9); sb.set_border_width_all(2); sb.set_corner_radius_all(15)
	var hv := sb.duplicate(); hv.bg_color = Color(0.15, 0.45, 0.85, 0.55); hv.border_color = HI
	b.add_theme_stylebox_override("normal", sb)
	for s in ["hover", "focus", "pressed", "hover_pressed"]: b.add_theme_stylebox_override(s, hv)
	b.focus_entered.connect(func(): Sfx.play("ui_move", -14.0))
	b.pressed.connect(func(): Sfx.play("ui_ok", -8.0); cb.call())
	return b


## Radio entry (ring with a dot when chosen), as in the Pose / Attire selectors.
class Radio extends Button:
	var on := false

	func _init(t: String, chosen: bool) -> void:
		text = "      " + t
		on = chosen
		flat = true
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_theme_font_size_override("font_size", 15)
		custom_minimum_size = Vector2(0, 22)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := Vector2(9, size.y * 0.5)
		var col := CCUI.HI if (has_focus() or is_hovered()) else Color("#bfe8ff")
		draw_arc(c, 7, 0, TAU, 24, col, 1.6, true)
		if on: draw_circle(c, 4, col)


static func radio(t: String, chosen: bool, cb: Callable) -> Radio:
	var r := Radio.new(t, chosen)
	r.pressed.connect(func(): Sfx.play("ui_ok", -8.0); cb.call())
	return r


## Round environment thumbnail: sky colour above, ground colour below.
class Orb extends Button:
	var top := Color.BLUE
	var bottom := Color.GREEN
	var chosen := false

	func _init(a: Color, b: Color, sel: bool) -> void:
		top = a; bottom = b; chosen = sel
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(46, 46)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := 20.0
		if chosen: draw_circle(c, r + 4, Color(0.4, 0.8, 1.0, 0.45))
		draw_circle(c, r, top)
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI * float(i) / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, bottom)
		draw_circle(c + Vector2(-6, -7), 6, Color(1, 1, 1, 0.18))
		var on := has_focus() or is_hovered() or chosen
		draw_arc(c, r, 0, TAU, 36, CCUI.HI if on else Color(0.6, 0.85, 1.0, 0.7), 2.0 if on else 1.2, true)


static func orb(a: String, b: String, sel: bool, cb: Callable, tip := "") -> Orb:
	var o := Orb.new(Color(a), Color(b), sel)
	o.tooltip_text = tip
	o.pressed.connect(func(): Sfx.play("ui_ok", -8.0); cb.call())
	return o


## Colour grid with PREVIOUS / CURRENT readouts. cb(hex) is called on selection.
static func palette(colors: Array, current: String, previous: String, cb: Callable, cell := Vector2(15, 11)) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 0); g.add_theme_constant_override("v_separation", 0)
	var frame := PanelContainer.new()
	var fs := StyleBoxFlat.new(); fs.bg_color = Color(0, 0, 0, 0.5); fs.border_color = Color(0.6, 0.85, 1.0, 0.6); fs.set_border_width_all(1)
	fs.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	frame.add_child(g)
	v.add_child(frame)
	var cur_hex := current.trim_prefix("#").to_lower().substr(0, 6)
	var readout := VBoxContainer.new()
	var info := HBoxContainer.new(); info.add_theme_constant_override("separation", 6)
	var sw := ColorRect.new(); sw.custom_minimum_size = Vector2(26, 40); sw.color = Color(current)
	info.add_child(sw)
	var lab := text("", 12, HI, cond(true))
	info.add_child(lab)
	var upd := func(hex: String):
		var p := Color(previous); var c := Color(hex)
		lab.text = "PREVIOUS\nRGB: %d,%d,%d\nCURRENT\nRGB: %d,%d,%d" % [p.r8, p.g8, p.b8, c.r8, c.g8, c.b8]
		sw.color = c
	upd.call(current)
	readout.add_child(info)
	for col in colors:
		var hex: String = col
		var b := Button.new()
		b.custom_minimum_size = cell
		b.focus_mode = Control.FOCUS_ALL
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(hex)
		var chosen: bool = hex.trim_prefix("#").to_lower().substr(0, 6) == cur_hex
		if chosen:
			sb.border_color = Color(0.4, 1.0, 0.7); sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		var f := sb.duplicate(); f.border_color = HI; f.set_border_width_all(2)
		for s in ["hover", "focus", "pressed", "hover_pressed"]: b.add_theme_stylebox_override(s, f)
		b.focus_entered.connect(func(): upd.call(hex))
		b.mouse_entered.connect(func(): upd.call(hex))
		b.pressed.connect(func(): Sfx.play("ui_ok", -10.0); cb.call(hex))
		g.add_child(b)
	v.add_child(readout)
	v.set_meta("grid", g)
	return v
