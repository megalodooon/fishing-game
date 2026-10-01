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

#------------------------# Little glyphs

# Draws a picture from rows of letters: "." is empty, letters pick colors.
const PALETTE : Dictionary = {
	"W": Color(0.95, 0.96, 1.0), "K": Color(0.1, 0.1, 0.14), "R": Color(0.92, 0.32, 0.36), "Y": Color(1.0, 0.82, 0.3),
	"G": Color(0.45, 0.85, 0.4), "D": Color(0.25, 0.55, 0.3), "B": Color(0.4, 0.62, 1.0), "C": Color(0.45, 0.88, 0.95),
	"P": Color(0.72, 0.48, 1.0), "O": Color(1.0, 0.6, 0.25), "N": Color(0.62, 0.42, 0.25), "S": Color(0.7, 0.74, 0.8),
}

func glyph(rows : Array) -> Image:
	var image : Image = blank(rows[0].length(), rows.size())
	for y in rows.size():
		for x in rows[y].length():
			var letter : String = rows[y][x]
			if PALETTE.has(letter):
				image.set_pixel(x, y, PALETTE[letter])
	return image

const TIDE_GLYPHS : Dictionary = {
	"heart": [".CC..CC.", "CCCCCCCC", "CWCCCCCC", "CCCCCCCC", ".CCCCCC.", "..CCCC..", "...CC...", "........"],
	"swift_line": ["....S...", "....S...", "W...S...", "WW..S...", "....S..S", "W...SS.S", "WW...SS.", "........"],
	"deep_luck": ["..GG....", ".GGGG.GG", ".GGGGGGG", "..GDGGG.", ".GGDDG..", "GGGGD...", "GG..D...", "....D..."],
	"forager": ["......G.", "....GGG.", "...GGGG.", "..GGGG..", ".RR.G...", "RRRR....", "RRRR....", ".RR....."],
	"haggler": ["..YYYY..", ".YYKKYY.", "YYKYYYYY", "YYYKKYYY", "YYYYYKYY", "YYKKKYYY", ".YYYYYY.", "..YYYY.."],
	"double_hook": [".S....S.", ".S....S.", ".S....S.", ".S....S.", "SS.S.SS.", ".SSS..SS", "........", "........"],
	"monster_lure": ["........", ".PPPPPP.", "PPWWWWPP", "PWWKKWWP", "PWWKKWWP", "PPWWWWPP", ".PPPPPP.", "........"],
	"treasure_sense": ["........", ".NNNNNN.", "NYYYYYYN", "NNNYYNNN", "NNNYYNNN", "NNNNNNNN", "NNNNNNNN", "........"],
	"green_hands": ["...G....", ".GGG.GG.", "..GGGG..", "...GG...", "...D....", "NNNDNNN.", ".NNNNN..", "........"],
	"artisan": [".SSSS...", "SSSSSS..", ".SSSS...", "...N....", "...N....", "...N....", "...N....", "........"],
	"foreman": ["..O..O..", ".OOO.OOO", "..O..O..", ".OOO.OOO", "OOOOOOOO", ".O.O.O.O", ".O.O.O.O", "........"],
	"trophy_eye": ["YYYYYYYY", "Y.YYYY.Y", ".YYYYYY.", "..YYYY..", "...YY...", "...YY...", "..YYYY..", ".YYYYYY."],
	"scholar": [".BBB.BBB", "BWWWBWWW", "BWWWBWWW", "BWWWBWWW", "BWWWBWWW", "BBBBBBBB", "........", "........"],
	"brewer": ["...SS...", "...SS...", "..PPPP..", ".PPWPPP.", "PPPPPPPP", "PPPPPPPP", ".PPPPPP.", "........"],
	"voyager": ["...CC...", "..C..C..", "...CC...", ".CCCCCC.", "...CC...", "C..CC..C", ".CCCCCC.", "...CC..."],
	"crown": ["........", "Y..Y..Y.", "YY.Y.YY.", "YYYYYYY.", "YRYYYRY.", "YYYYYYY.", "........", "........"],
}

func art_tide_icons() -> void:
	for id in TIDE_GLYPHS:
		save(glyph(TIDE_GLYPHS[id]), "res://player/tide_icons/%s.png" % id)

#------------------------# Bramblewick's land

const LAYOUT : GDScript = preload("res://../tools/village/layout.gd")

const GRASS : Array = [Color("6ba84f"), Color("629a48"), Color("73ad59"), Color("6aa74e"), Color("6ca850"), Color("578a40")]
const SPECKS : Array = [Color("f299b2"), Color("f2e57f"), Color("f4f4f4"), Color("9aa6f0")]
const DIRT : Array = [Color("ad8759"), Color("9f7c52"), Color("b28e63")]
const SAND_COLORS : Array = [Color("e2cc91"), Color("e5d29e"), Color("d8c086")]
const STONE : Array = [Color("a9a39a"), Color("9a948b"), Color("b6b0a6"), Color("8c867e")]
const PLANK : Array = [Color("9c7a52"), Color("8a6a45"), Color("7a5c3b")]

# The whole island in one picture, then cut into the rooms' tiles.
func art_town() -> void:
	var size : Vector2i = Vector2i(LAYOUT.SIZE)
	var image : Image = blank(size.x, size.y)
	var noise : FastNoiseLite = FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.03
	var shade : FastNoiseLite = FastNoiseLite.new()
	shade.seed = 11
	shade.frequency = 0.012
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1234
	for y in size.y:
		for x in size.x:
			var at : Vector2 = Vector2(x, y) + Vector2(0.5, 0.5)
			var inside : float = land_depth(at, noise)
			if inside <= 0.0:
				continue
			var color : Color
			if inside < LAYOUT.SAND + noise.get_noise_2d(x * 3.0, y * 3.0) * 2.0:
				color = SAND_COLORS[random.randi() % 3] if random.randf() < 0.18 else SAND_COLORS[0]
			else:
				var tone : float = shade.get_noise_2d(x, y)
				color = GRASS[0].lerp(GRASS[2] if tone > 0.0 else GRASS[1], absf(tone) * 1.6)
				if random.randf() < 0.22:
					color = GRASS[random.randi() % GRASS.size()]
				if random.randf() < 0.012:
					color = SPECKS[random.randi() % SPECKS.size()]
			image.set_pixel(x, y, color)
	# Paths, the square and the piers on top.
	for line in LAYOUT.PATHS:
		paint_path(image, line, random)
	for y in range(int(LAYOUT.PLAZA.y - LAYOUT.PLAZA_RADIUS) - 1, int(LAYOUT.PLAZA.y + LAYOUT.PLAZA_RADIUS) + 2):
		for x in range(int(LAYOUT.PLAZA.x - LAYOUT.PLAZA_RADIUS) - 1, int(LAYOUT.PLAZA.x + LAYOUT.PLAZA_RADIUS) + 2):
			var d : float = Vector2(x + 0.5, y + 0.5).distance_to(LAYOUT.PLAZA)
			if d <= LAYOUT.PLAZA_RADIUS:
				var brick : bool = (int(x / 4) + int(y / 3)) % 2 == 0
				var color : Color = STONE[0] if brick else STONE[1]
				if (x % 4 == 0 and (int(y / 3)) % 2 == 0) or y % 3 == 0:
					color = STONE[3]
				if d > LAYOUT.PLAZA_RADIUS - 1.5:
					color = STONE[3].darkened(0.15)
				image.set_pixel(x, y, color)
	for pier in LAYOUT.PIERS:
		var rect : Rect2 = pier
		for y in range(int(rect.position.y), int(rect.end.y)):
			for x in range(int(rect.position.x), int(rect.end.x)):
				if x < 0 or y < 0 or x >= size.x or y >= size.y:
					continue
				var along : bool = rect.size.y > rect.size.x
				var seam : bool = (y % 4 == 0) if along else (x % 4 == 0)
				var color : Color = PLANK[2] if seam else PLANK[0 if random.randf() < 0.8 else 1]
				if x == int(rect.position.x) or x == int(rect.end.x) - 1 or (not along and (y == int(rect.position.y) or y == int(rect.end.y) - 1)):
					color = PLANK[2]
				image.set_pixel(x, y, color)
	save(image, "res://world/village/land/town.png")
	for ry in LAYOUT.ROOMS.y:
		for rx in LAYOUT.ROOMS.x:
			var tile : Image = image.get_region(Rect2i(Vector2i(rx, ry) * Vector2i(LAYOUT.ROOM), Vector2i(LAYOUT.ROOM)))
			save(tile, "res://world/village/land/town_%d_%d.png" % [rx, ry])

# How far inside the coast a point is (below 0 is sea).
func land_depth(at : Vector2, noise : FastNoiseLite) -> float:
	var offset : Vector2 = (at - LAYOUT.CENTER) / LAYOUT.RADII
	var depth : float = (1.0 - offset.length()) * minf(LAYOUT.RADII.x, LAYOUT.RADII.y)
	for headland in LAYOUT.HEADLANDS:
		depth = maxf(depth, headland[1] - at.distance_to(headland[0]))
	return depth + noise.get_noise_2d(at.x, at.y) * 9.0

func paint_path(image : Image, line : Array, random : RandomNumberGenerator) -> void:
	var half : float = LAYOUT.PATH_WIDTH * 0.5
	for i in range(1, line.size()):
		var a : Vector2 = line[i - 1]
		var b : Vector2 = line[i]
		var box : Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(half + 1.0)
		for y in range(int(box.position.y), int(box.end.y) + 1):
			for x in range(int(box.position.x), int(box.end.x) + 1):
				if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height() or image.get_pixel(x, y).a <= 0.0:
					continue
				var point : Vector2 = Vector2(x + 0.5, y + 0.5)
				var d : float = point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))
				if d <= half - 0.5 or (d <= half + 0.5 and random.randf() < 0.5):
					image.set_pixel(x, y, DIRT[0] if random.randf() < 0.78 else DIRT[random.randi() % DIRT.size()])

#------------------------# Insides of buildings, furniture, new outsides

func fill(image : Image, rect : Rect2i, color : Color) -> void:
	image.fill_rect(rect.intersection(Rect2i(Vector2i.ZERO, image.get_size())), color)

func frame(image : Image, rect : Rect2i, color : Color) -> void:
	fill(image, Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
	fill(image, Rect2i(rect.position + Vector2i(0, rect.size.y - 1), Vector2i(rect.size.x, 1)), color)
	fill(image, Rect2i(rect.position, Vector2i(1, rect.size.y)), color)
	fill(image, Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i(1, rect.size.y)), color)

# The floor every inside uses: walls along the top, the floor below, a
# doormat at the bottom middle. FLOOR_RECT is where people can walk.
const FLOOR_RECT : Rect2i = Rect2i(20, 36, 152, 66)
const FLOORS : Dictionary = {
	"wood": [Color("8a6440"), Color("7d5a39"), Color("a77d52"), Color("6e4f32")],
	"stone": [Color("8e8a84"), Color("807b75"), Color("a19c95"), Color("6f6a64")],
	"marble": [Color("e6dfd2"), Color("d4ccbd"), Color("f2ede4"), Color("b9b0a0")],
}
const WALLS : Dictionary = {"wood": Color("b98a5a"), "stone": Color("9a8f86"), "marble": Color("c9d6dc")}

func art_interiors() -> void:
	for kind in FLOORS:
		var colors : Array = FLOORS[kind]
		var image : Image = blank(192, 108)
		fill(image, Rect2i(0, 0, 192, 108), Color("17110d"))
		var wall : Color = WALLS[kind]
		fill(image, Rect2i(18, 6, 156, 30), wall)
		for x in range(18, 174, 12):
			fill(image, Rect2i(x, 6, 1, 30), wall.darkened(0.12))
		fill(image, Rect2i(18, 34, 156, 2), wall.darkened(0.35))
		for window in [Rect2i(36, 12, 16, 12), Rect2i(140, 12, 16, 12)]:
			fill(image, window, Color("9fd3ea"))
			frame(image, window, Color("4a3524"))
			fill(image, Rect2i(window.position.x + 7, window.position.y, 2, 12), Color("4a3524"))
		for y in range(FLOOR_RECT.position.y, FLOOR_RECT.end.y):
			for x in range(FLOOR_RECT.position.x, FLOOR_RECT.end.x):
				var color : Color = colors[0]
				match kind:
					"wood":
						color = colors[0] if (y / 4) % 2 == 0 else colors[1]
						if y % 4 == 0 or (x + (y / 4) * 9) % 23 == 0:
							color = colors[3]
					"stone":
						color = colors[0] if ((x / 8) + (y / 8)) % 2 == 0 else colors[1]
						if x % 8 == 0 or y % 8 == 0:
							color = colors[3]
					"marble":
						color = colors[0] if ((x / 10) + (y / 10)) % 2 == 0 else colors[2]
						if x % 10 == 0 or y % 10 == 0:
							color = colors[1]
				image.set_pixel(x, y, color)
		fill(image, Rect2i(86, 100, 20, 8), colors[0])
		fill(image, Rect2i(88, 98, 16, 6), Color("7b2f2f"))
		frame(image, Rect2i(88, 98, 16, 6), Color("5b2020"))
		save(image, "res://world/village/insides/%s.png" % kind)
		# Where people can walk, the same size: the floor and the doorway.
		var mask : Image = blank(192, 108)
		fill(mask, FLOOR_RECT, Color.WHITE)
		fill(mask, Rect2i(86, 100, 20, 8), Color.WHITE)
		save(mask, "res://world/village/insides/%s_floor.png" % kind)
	furniture()
	outsides()

func furniture() -> void:
	var wood : Color = Color("8b5e34")
	var dark : Color = Color("4a2f1a")
	# A shop counter: a light top, a darker front.
	var counter : Image = blank(46, 14)
	fill(counter, Rect2i(0, 0, 46, 5), Color("c08a52"))
	fill(counter, Rect2i(0, 5, 46, 9), wood)
	for x in range(4, 46, 9):
		fill(counter, Rect2i(x, 6, 1, 7), dark)
	frame(counter, Rect2i(0, 0, 46, 14), Color("2e1d10"))
	save(counter, "res://world/village/insides/counter.png")
	var bed : Image = blank(18, 26)
	fill(bed, Rect2i(0, 0, 18, 26), dark)
	fill(bed, Rect2i(1, 1, 16, 7), Color("f2f2f2"))
	fill(bed, Rect2i(1, 9, 16, 16), Color("b44a4a"))
	fill(bed, Rect2i(1, 9, 16, 2), Color("d46a6a"))
	save(bed, "res://world/village/insides/bed.png")
	var table : Image = blank(20, 12)
	fill(table, Rect2i(1, 1, 18, 7), Color("b8834f"))
	fill(table, Rect2i(2, 8, 2, 4), dark)
	fill(table, Rect2i(16, 8, 2, 4), dark)
	frame(table, Rect2i(0, 0, 20, 9), Color("2e1d10"))
	save(table, "res://world/village/insides/table.png")
	var shelf : Image = blank(30, 22)
	fill(shelf, Rect2i(0, 0, 30, 22), wood)
	frame(shelf, Rect2i(0, 0, 30, 22), Color("2e1d10"))
	var goods : Array = [Color("d65b5b"), Color("5bb0d6"), Color("e3c35a"), Color("6ec26e"), Color("c47be0")]
	for row in 3:
		fill(shelf, Rect2i(1, 7 + row * 7, 28, 1), dark)
		for i in 6:
			fill(shelf, Rect2i(2 + i * 4 + (row % 2), 3 + row * 7, 3, 4), goods[(i + row * 2) % goods.size()])
	save(shelf, "res://world/village/insides/shelf.png")
	var tank : Image = blank(32, 22)
	fill(tank, Rect2i(0, 0, 32, 22), Color("2a3a44"))
	fill(tank, Rect2i(2, 2, 28, 15), Color("4aa6c8"))
	fill(tank, Rect2i(2, 13, 28, 4), Color("d8c08a"))
	for fish in [Vector2i(8, 6), Vector2i(20, 9), Vector2i(14, 4)]:
		fill(tank, Rect2i(fish, Vector2i(4, 2)), Color("f2a24a"))
	save(tank, "res://world/village/insides/tank.png")
	var showcase : Image = blank(18, 16)
	fill(showcase, Rect2i(0, 6, 18, 10), wood)
	fill(showcase, Rect2i(1, 0, 16, 7), Color("bfe3f0"))
	fill(showcase, Rect2i(7, 2, 4, 3), Color("e3c35a"))
	frame(showcase, Rect2i(0, 0, 18, 16), Color("2e1d10"))
	save(showcase, "res://world/village/insides/case.png")
	var bar : Image = blank(64, 14)
	fill(bar, Rect2i(0, 0, 64, 5), Color("6b3f22"))
	fill(bar, Rect2i(0, 5, 64, 9), Color("4f2e18"))
	frame(bar, Rect2i(0, 0, 64, 14), Color("24140a"))
	save(bar, "res://world/village/insides/bar.png")
	var bottles : Image = blank(44, 14)
	fill(bottles, Rect2i(0, 10, 44, 3), wood)
	for i in 9:
		fill(bottles, Rect2i(2 + i * 5, 3 + (i % 2), 3, 7 - (i % 2)), goods[i % goods.size()].darkened(0.2))
	save(bottles, "res://world/village/insides/bottles.png")
	var rug : Image = blank(36, 20)
	fill(rug, Rect2i(0, 0, 36, 20), Color("7b3b5a"))
	frame(rug, Rect2i(2, 2, 32, 16), Color("d9a24a"))
	save(rug, "res://world/village/insides/rug.png")
	var hearth : Image = blank(26, 24)
	fill(hearth, Rect2i(0, 0, 26, 24), Color("8a8580"))
	fill(hearth, Rect2i(6, 10, 14, 14), Color("1c120c"))
	fill(hearth, Rect2i(9, 16, 8, 8), Color("f08a2a"))
	fill(hearth, Rect2i(11, 14, 4, 4), Color("ffd45a"))
	frame(hearth, Rect2i(0, 0, 26, 24), Color("3b3632"))
	save(hearth, "res://world/village/insides/hearth.png")
	var vault : Image = blank(24, 26)
	paint(vault, func(x : int, y : int) -> bool: return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 13)) < 11.0, Color("8d8f96"))
	paint(vault, func(x : int, y : int) -> bool: return Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 13)) < 4.0, Color("c9b45a"))
	outline(vault)
	save(vault, "res://world/village/insides/vault.png")
	var chart : Image = blank(26, 18)
	fill(chart, Rect2i(0, 0, 26, 18), Color("e8d9b0"))
	fill(chart, Rect2i(5, 5, 8, 5), Color("7fb36b"))
	fill(chart, Rect2i(16, 9, 5, 4), Color("7fb36b"))
	frame(chart, Rect2i(0, 0, 26, 18), Color("6b4b2a"))
	save(chart, "res://world/village/insides/chart.png")
	var barrel : Image = blank(10, 13)
	fill(barrel, Rect2i(0, 0, 10, 13), wood)
	fill(barrel, Rect2i(0, 3, 10, 1), dark)
	fill(barrel, Rect2i(0, 9, 10, 1), dark)
	frame(barrel, Rect2i(0, 0, 10, 13), Color("2e1d10"))
	save(barrel, "res://world/village/insides/barrel.png")

# Outsides for the new buildings, in the village's style.
func house_art(width : int, height : int, wall : Color, roof : Color, sign_color : Color) -> Image:
	var image : Image = blank(width, height)
	var roofHeight : int = height * 5 / 12
	for y in roofHeight:
		var inset : int = (roofHeight - y) / 2
		fill(image, Rect2i(inset, y, width - inset * 2, 1), roof if y % 3 != 0 else roof.darkened(0.15))
	fill(image, Rect2i(2, roofHeight, width - 4, height - roofHeight), wall)
	for x in range(2, width - 2, 5):
		fill(image, Rect2i(x, roofHeight, 1, height - roofHeight), wall.darkened(0.08))
	var door : Rect2i = Rect2i(width / 2 - 3, height - 10, 6, 10)
	fill(image, door, Color("5a3a22"))
	fill(image, Rect2i(door.position.x + 4, door.position.y + 5, 1, 1), Color("e3c35a"))
	for window in [Rect2i(5, roofHeight + 4, 6, 5), Rect2i(width - 11, roofHeight + 4, 6, 5)]:
		fill(image, window, Color("9fd3ea"))
	if sign_color.a > 0.0:
		fill(image, Rect2i(width / 2 - 5, roofHeight + 1, 10, 4), sign_color)
	outline(image)
	return image

func outsides() -> void:
	save(house_art(46, 34, Color("a0703f"), Color("3f7a4a"), Color("e3c35a")), "res://world/village/buildings/tavern.png")
	save(house_art(40, 32, Color("e6e2d8"), Color("3d5f8f"), Color("9fd3ea")), "res://world/village/buildings/harbor_office.png")
	save(house_art(30, 26, Color("d7c09a"), Color("9a4b3b"), Color(0, 0, 0, 0)), "res://world/village/buildings/cottage.png")

# The tavern keeper: another villager in new colors until the real art.
func art_wren() -> void:
	for pair in [["res://world/npcs/mara.png", "res://world/npcs/wren.png"], ["res://world/portraits/mara.png", "res://world/portraits/wren.png"]]:
		var source : Image = Image.load_from_file(ProjectSettings.globalize_path(pair[0]))
		for y in source.get_height():
			for x in source.get_width():
				var c : Color = source.get_pixel(x, y)
				# Skin (warm, light) stays; hair and clothes change.
				var skin : bool = c.h > 0.0 and c.h < 0.12 and c.v > 0.55 and c.s < 0.6
				if c.a > 0.0 and c.s > 0.25 and not skin:
					c.h = fmod(c.h + 0.45, 1.0)
					source.set_pixel(x, y, c)
		save(source, pair[1])
