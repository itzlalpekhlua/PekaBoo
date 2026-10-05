extends SceneTree

func _initialize() -> void:
	var image := Image.new()
	var error := image.load_svg_from_string(FileAccess.get_file_as_string("res://desktop_splash.svg"))
	if error == OK:
		error = image.save_png("res://desktop_splash.png")
	quit(error)
