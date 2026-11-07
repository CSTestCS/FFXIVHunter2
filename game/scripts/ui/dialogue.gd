class_name Dialogue
extends CanvasLayer
## FFXIV-style dialogue window with typewriter text and optional choices.

signal advanced
signal chosen(i: int)

var active := false
var panel: PanelContainer
var name_lbl: Label
var text_lbl: RichTextLabel
var hint: Label
var choices: VBoxContainer
var _typing := false
var _visible_chars := 0.0
var _choice_mode := false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = UI.panel(Vector2(1000, 190))
	var r := UI.screen_root()
	add_child(r)
	UI.fit(r, panel, Vector2(0.5, 1.0), Vector4(16, 16, 16, 110))
	var v := UI.vbox(6)
	panel.add_child(v)
	name_lbl = UI.label("", 22, UI.GOLD)
	v.add_child(name_lbl)
	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = false
	text_lbl.fit_content = true
	text_lbl.custom_minimum_size = Vector2(980, 90)
	text_lbl.add_theme_font_size_override("normal_font_size", 22)
	text_lbl.add_theme_color_override("default_color", UI.TEXT)
	v.add_child(text_lbl)
	choices = UI.vbox(4)
	v.add_child(choices)
	hint = UI.label("", 15, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(hint)
	panel.visible = false


func say(speaker: String, text: String) -> void:
	active = true
	_choice_mode = false
	UI.clear(choices)
	panel.visible = true
	name_lbl.text = speaker
	text_lbl.text = text
	text_lbl.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	hint.text = "[%s] Continue" % Inputs.glyph("ui_accept")
	await advanced


func choose(speaker: String, text: String, opts: Array) -> int:
	active = true
	_choice_mode = true
	panel.visible = true
	name_lbl.text = speaker
	text_lbl.text = text
	text_lbl.visible_characters = -1
	_typing = false
	hint.text = ""
	UI.clear(choices)
	for i in opts.size():
		var idx := i
		choices.add_child(UI.button(str(opts[i]), func(): chosen.emit(idx)))
	UI.focus_first(choices)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var r: int = await chosen
	UI.clear(choices)
	_choice_mode = false
	return r


func close() -> void:
	active = false
	panel.visible = false
	UI.clear(choices)


func _process(delta: float) -> void:
	if not panel.visible: return
	if _typing:
		_visible_chars += delta * 55.0 * float(Settings.v["text_speed"])
		text_lbl.visible_characters = int(_visible_chars)
		if _visible_chars >= text_lbl.text.length():
			_typing = false
			text_lbl.visible_characters = -1


func _input(e: InputEvent) -> void:
	if not panel.visible or _choice_mode: return
	var adv := e.is_action_pressed("ui_accept") or e.is_action_pressed("interact") or e.is_action_pressed("light") or e.is_action_pressed("jump")
	if adv:
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false; text_lbl.visible_characters = -1
		else:
			Sfx.play("ui_move", -10.0)
			advanced.emit()
