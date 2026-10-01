extends SceneTree

# Draws the placeholder art the game uses until the real art replaces it.
# Every picture is a plain PNG at the path it's loaded from, so painting over
# it (same size) is all a replacement takes. Run from the godot folder:
#   godot --headless --path . -s ../tools/placeholder_art/make.gd -- [names...]
# With no names it makes everything that doesn't exist yet; "--force" redoes
# the named ones even when they exist.

const OUTLINE : Color = Color(0.09, 0.08, 0.1)

var force : bool = false


func _initialize() -> void:
	var names : PackedStringArray = OS.get_cmdline_user_args()
	force = names.has("--force")
	var wanted : Array = Array(names).filter(func(n : String) -> bool: return not n.begins_with("--"))
	for method in get_method_list():
		var name_now : String = method.name
		if name_now.begins_with("art_") and (wanted.is_empty() or wanted.has(name_now.substr(4))):
			call(name_now)
	quit()

func save(image : Image, path : String) -> void:
	var file : String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and not force:
		return
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	image.save_png(file)
	print("made ", path)

func blank(width : int, height : int) -> Image:
	var image : Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image

# Fills where the test is true.
func paint(image : Image, test : Callable, color : Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			if test.call(x, y):
				image.set_pixel(x, y, color)

# A one pixel dark edge around everything drawn so far.
func outline(image : Image, color : Color = OUTLINE) -> void:
	var copy : Image = image.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			if copy.get_pixel(x, y).a > 0.0:
				continue
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p : Vector2i = Vector2i(x, y) + offset
				if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height() and copy.get_pixelv(p).a > 0.0:
					image.set_pixel(x, y, color)
					break

#------------------------# Portraits

# The player, like their placeholder sprite: a white blob, looking at you.
func art_player_portrait() -> void:
	var image : Image = blank(24, 24)
	var white : Color = Color(0.96, 0.96, 0.98)
	var shade : Color = Color(0.78, 0.8, 0.86)
	paint(image, func(x : int, y : int) -> bool: return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12.0, 11.0)) < 8.2, white)
	paint(image, func(x : int, y : int) -> bool: return y >= 18 and x >= 4 and x <= 19, white)
	paint(image, func(x : int, y : int) -> bool: return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12.0, 11.0)) < 8.2 and x >= 16, shade)
	paint(image, func(x : int, y : int) -> bool: return y >= 20 and x >= 15 and x <= 19, shade)
	outline(image)
	for eye in [Vector2i(9, 10), Vector2i(14, 10)]:
		image.set_pixelv(eye, OUTLINE)
		image.set_pixelv(eye + Vector2i(0, 1), OUTLINE)
	image.set_pixel(11, 14, shade.darkened(0.3))
	image.set_pixel(12, 14, shade.darkened(0.3))
	save(image, "res://world/portraits/player.png")
