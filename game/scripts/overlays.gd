class_name Overlays
extends Control
## Pop-up panels used by chill mode: fortune / dare cards, typing a sky message, the cooking
## game, the selfie photo frame and the wardrobe. Built from the same look as the rest of the UI.

var ui: UI
var card: PanelContainer
var _card_icon: Label
var _card_title: Label
var _card_text: Label
var _card_btns: HBoxContainer

var asker: PanelContainer
var _ask_label: Label
var _ask_edit: LineEdit
var _ask_cb: Callable

var game: PanelContainer
var _game_title: Label
var _game_steps: Label
var _game_turn: Label
var _game_bar: ProgressBar
var _game_opts: Array[Button] = []
var game_pick: Callable          # called with the option index

var frame: Control               # selfie polaroid frame
var _frame_caption: Label
var flash: ColorRect


func setup(u: UI) -> void:
	ui = u
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	_build_asker()
	_build_game()
	_build_frame()


func _center(panel: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.add_child(panel)
	panel.visible = false
	return c


# ---------- a card: fortunes, dares, questions, game results ----------

func _build_card() -> void:
	card = ui._card(UI.CREAM)
	card.custom_minimum_size = Vector2(520, 0)
	_center(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	_card_icon = ui._label("🔮", 64)
	_card_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_icon)
	_card_title = ui._label("", 22, UI.MUTED)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_title)
	_card_text = ui._label("", 28, UI.INK)
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(460, 0)
	v.add_child(_card_text)
	_card_btns = HBoxContainer.new()
	_card_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_btns.add_theme_constant_override("separation", 12)
	v.add_child(_card_btns)


## buttons: [[label, color, callable], ...]; an empty list gives a plain "Close".
func show_card(icon: String, title: String, text: String, buttons := []) -> void:
	_card_icon.text = icon
	_card_title.text = title
	_card_text.text = text
	for c in _card_btns.get_children():
		c.queue_free()
	if buttons.is_empty():
		buttons = [["Close", UI.PURPLE, Callable()]]
	for b in buttons:
		var btn := ui._btn(b[0], b[1], Vector2(180, 58), 24)
		var cb: Callable = b[2]
		btn.pressed.connect(func():
			card.visible = false
			if cb.is_valid():
				cb.call())
		_card_btns.add_child(btn)
	card.visible = true
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = card.size / 2.0
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- type a short message ----------

func _build_asker() -> void:
	asker = ui._card(UI.CREAM)
	asker.custom_minimum_size = Vector2(540, 0)
	_center(asker)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	asker.add_child(v)
	_ask_label = ui._label("", 26)
	_ask_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_ask_label)
	_ask_edit = ui._edit("", 18)
	_ask_edit.add_theme_font_size_override("font_size", 30)
	_ask_edit.custom_minimum_size = Vector2(0, 64)
	v.add_child(_ask_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var cancel := ui._btn("Cancel", UI.MUTED, Vector2(170, 58), 24)
	cancel.pressed.connect(func(): asker.visible = false)
	row.add_child(cancel)
	var ok := ui._btn("Send 💜", UI.PINK, Vector2(170, 58), 24)
	ok.pressed.connect(_ask_done)
	row.add_child(ok)
	_ask_edit.text_submitted.connect(func(_t): _ask_done())


func ask_text(prompt: String, placeholder: String, cb: Callable) -> void:
	_ask_label.text = prompt
	_ask_edit.placeholder_text = placeholder
	_ask_edit.text = ""
	_ask_cb = cb
	asker.visible = true
	_ask_edit.grab_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show("")


func _ask_done() -> void:
	var t := _ask_edit.text.strip_edges()
	asker.visible = false
	DisplayServer.virtual_keyboard_hide()
	if t != "" and _ask_cb.is_valid():
		_ask_cb.call(t)


# ---------- cooking game panel ----------

func _build_game() -> void:
	game = ui._card(Color(1.0, 0.97, 0.94, 0.96))
	game.custom_minimum_size = Vector2(560, 0)
	var holder := _center(game)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	holder.position.x = 30
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	game.add_child(v)
	_game_title = ui._label("", 30)
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_game_title)
	_game_bar = ProgressBar.new()
	_game_bar.show_percentage = false
	_game_bar.custom_minimum_size = Vector2(0, 12)
	v.add_child(_game_bar)
	_game_steps = ui._label("", 22, UI.MUTED)
	_game_steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_game_steps)
	_game_turn = ui._label("", 26, UI.PINK)
	_game_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_game_turn)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for i in 4:
		var b := ui._btn("", UI.ORANGE, Vector2(250, 76), 34)
		b.pressed.connect(func(): if game_pick.is_valid(): game_pick.call(i))
		grid.add_child(b)
		_game_opts.append(b)


func show_game(title: String, steps_text: String, turn_text: String, options: Array, my_turn: bool, time_frac: float) -> void:
	game.visible = true
	_game_title.text = title
	_game_steps.text = steps_text
	_game_turn.text = turn_text
	_game_bar.value = time_frac * 100.0
	for i in 4:
		var b := _game_opts[i]
		b.visible = i < options.size()
		if i < options.size():
			b.text = options[i]
			b.disabled = not my_turn
			b.modulate.a = 1.0 if my_turn else 0.55


func hide_game() -> void:
	game.visible = false


# ---------- selfie frame + flash ----------

func _build_frame() -> void:
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	add_child(frame)
	var border := 26.0
	for k in 4:
		var r := ColorRect.new()
		r.color = Color("#fffaf5")
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match k:
			0:
				r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				r.offset_bottom = border
			1:
				r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				r.offset_top = -border * 3.2
			2:
				r.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
				r.offset_right = border
			3:
				r.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
				r.offset_left = -border
		frame.add_child(r)
	_frame_caption = ui._label("", 34, Color("#8a3f6e"))
	_frame_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_frame_caption.offset_top = -border * 3.0
	_frame_caption.offset_bottom = -border * 0.4
	_frame_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(_frame_caption)
	# little hearts in the corners
	for corner in [[0.0, 0.0], [1.0, 0.0]]:
		var h := ui._label("💗", 44)
		h.anchor_left = corner[0]
		h.anchor_right = corner[0]
		h.position = Vector2(-70 if corner[0] > 0.5 else 18, 30)
		frame.add_child(h)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func show_frame(caption: String) -> void:
	_frame_caption.text = caption
	frame.visible = true


func do_flash() -> void:
	flash.color.a = 0.9
	create_tween().tween_property(flash, "color:a", 0.0, 0.5)


# ---------- a menu of big choices (the cooking menu) ----------

var grid_panel: PanelContainer
var _grid_title: Label
var _grid: GridContainer


func show_grid(title: String, items: Array, cb: Callable) -> void:
	if grid_panel == null:
		grid_panel = ui._card(UI.CREAM)
		grid_panel.custom_minimum_size = Vector2(620, 0)
		_center(grid_panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		grid_panel.add_child(v)
		_grid_title = ui._label("", 30)
		_grid_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_grid_title)
		_grid = GridContainer.new()
		_grid.columns = 3
		_grid.add_theme_constant_override("h_separation", 12)
		_grid.add_theme_constant_override("v_separation", 12)
		v.add_child(_grid)
		var close := ui._btn("Not now", UI.MUTED, Vector2(0, 54), 22)
		close.pressed.connect(func(): grid_panel.visible = false)
		v.add_child(close)
	_grid_title.text = title
	for c in _grid.get_children():
		c.queue_free()
	for i in items.size():
		var b := ui._btn("%s\n%s" % [items[i][0], items[i][1]], [UI.PINK, UI.ORANGE, UI.PURPLE, UI.BLUE, UI.GREEN, Color("#e0457b")][i % 6], Vector2(190, 120), 24)
		var idx := i
		b.pressed.connect(func():
			grid_panel.visible = false
			cb.call(idx))
		_grid.add_child(b)
	grid_panel.visible = true
