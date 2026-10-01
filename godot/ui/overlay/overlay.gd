extends CanvasLayer

# Things drawn over every screen (the "Overlay" autoload): the frame rate in
# the corner when the settings ask for it.

var label : Label


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.position = Vector2(4.0, 2.0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _process(_delta : float) -> void:
	label.visible = bool(Settings.get_value("showFps"))
	if label.visible:
		label.text = "%d FPS" % Engine.get_frames_per_second()
