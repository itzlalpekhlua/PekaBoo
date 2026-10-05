extends Control
## Code-drawn branding; no world assets or rendering settings are changed.

var _time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var space := Control.new()
	space.custom_minimum_size = Vector2(440, 148)
	v.add_child(space)
	var eyebrow := Label.new()
	eyebrow.text = "READY OR NOT…"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", Color("#d8b4ee"))
	v.add_child(eyebrow)
	var title := Label.new()
	title.text = "PekaBoo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 86)
	title.add_theme_color_override("font_color", Color("#fff7ef"))
	v.add_child(title)
	var tagline := Label.new()
	tagline.text = "A little mischief. A lot of memories."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", Color("#d8b4ee"))
	v.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 28
	v.add_child(gap)
	var bar := ProgressBar.new()
	bar.name = "bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(440, 5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#463353")
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ff7dac")
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	# Main owns the shader warm-up progress; expose the actual bar directly.
	set_meta("bar", bar)
	var preparing := Label.new()
	preparing.text = "Making the house feel like home"
	preparing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preparing.add_theme_font_size_override("font_size", 16)
	preparing.add_theme_color_override("font_color", Color("#b49dc4"))
	v.add_child(preparing)
	var credit := Label.new()
	credit.text = "RUBINBASTAKOTI  /  A GAME FOR TWO"
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color("#b49dc4"))
	credit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	credit.position = Vector2(-170, -44)
	add_child(credit)

func _process(dt: float) -> void:
	_time += dt
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#160e22"))
	var c := size * 0.5 + Vector2(0, -146)
	for i in 4:
		draw_arc(c, 180 + i * 96, 0.0, TAU, 96, Color(0.65, 0.38, 0.85, 0.06), 1.5, true)
	var lift := sin(_time * 1.3) * 3.0
	c.y += lift
	var pink := Color("#ff7dac")
	var cream := Color("#fff7ef")
	draw_polyline(PackedVector2Array([c + Vector2(-62, -6), c + Vector2(0, -62), c + Vector2(62, -6)]), pink, 6, true)
	draw_polyline(PackedVector2Array([c + Vector2(-46, -12), c + Vector2(-46, 58), c + Vector2(46, 58), c + Vector2(46, -12)]), cream, 5, true)
	draw_style_box(_door_box(), Rect2(c + Vector2(-20, 10), Vector2(40, 48)))
	# Two tiny eyes peek out from the doorway.
	draw_circle(c + Vector2(-8, 26), 4, cream)
	draw_circle(c + Vector2(8, 26), 4, cream)
	for star in [Vector2(-108, -40), Vector2(102, 28), Vector2(80, -78)]:
		draw_line(c + star - Vector2(5, 0), c + star + Vector2(5, 0), pink, 2, true)
		draw_line(c + star - Vector2(0, 5), c + star + Vector2(0, 5), pink, 2, true)

func _door_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#49305e")
	box.set_corner_radius_all(10)
	return box
