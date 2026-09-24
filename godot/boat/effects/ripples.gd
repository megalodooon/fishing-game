@tool
extends Node2D
class_name BoatRipples

const FAR : float = 1e20

#------------------------#
@export var deckTexture : Texture2D:
	set(value):
		deckTexture = value
		build()
@export var frontTexture : Texture2D:
	set(value):
		frontTexture = value
		build()
@export var hullHeight : int = 17:
	set(value):
		hullHeight = value
		build()
@export var margin : int = 24:
	set(value):
		margin = value
		build()

var distanceTexture : ImageTexture
#------------------------#


func _ready() -> void:
	build()

func _draw() -> void:
	if distanceTexture:
		draw_texture(distanceTexture, -distanceTexture.get_size() / 2.0)

func build() -> void:
	if not is_node_ready() or not deckTexture or not frontTexture:
		return
	var deck : Image = deckTexture.get_image()
	var front : Image = frontTexture.get_image()
	var width : int = deck.get_width() + margin * 2
	var height : int = deck.get_height() + margin * 2
	var inside : PackedByteArray = waterline_mask(deck, front, width, height)
	var outsideDistance : PackedFloat32Array = distance_squared(inside, 1, width, height)
	var insideDistance : PackedFloat32Array = distance_squared(inside, 0, width, height)
	var field : PackedFloat32Array = PackedFloat32Array()
	field.resize(width * height)
	for i in field.size():
		if inside[i]:
			field[i] = 0.5 - sqrt(insideDistance[i])
		else:
			field[i] = sqrt(outsideDistance[i]) - 0.5
	field = blur(blur(field, width, height, Vector2i(1, 0)), width, height, Vector2i(0, 1))
	var image : Image = Image.create_empty(width, height, false, Image.FORMAT_RH)
	for y in height:
		for x in width:
			image.set_pixel(x, y, Color(field[x + y * width], 0.0, 0.0))
	distanceTexture = ImageTexture.create_from_image(image)
	queue_redraw()

func waterline_mask(deck : Image, front : Image, width : int, height : int) -> PackedByteArray:
	var inside : PackedByteArray = PackedByteArray()
	inside.resize(width * height)
	for x in deck.get_width():
		var frontTop : int = deck.get_height()
		for y in deck.get_height():
			if front.get_pixel(x, y).a > 0.0:
				frontTop = y
				break
		for y in deck.get_height():
			if front.get_pixel(x, y).a > 0.0:
				inside[x + margin + (y + margin) * width] = 1
			elif deck.get_pixel(x, y).a > 0.0 and y + hullHeight < frontTop:
				inside[x + margin + (y + hullHeight + margin) * width] = 1
	return inside

func distance_squared(inside : PackedByteArray, target : int, width : int, height : int) -> PackedFloat32Array:
	var grid : PackedFloat32Array = PackedFloat32Array()
	grid.resize(width * height)
	for i in grid.size():
		grid[i] = 0.0 if inside[i] == target else FAR
	var line : PackedFloat32Array = PackedFloat32Array()
	for x in width:
		line.resize(height)
		for y in height:
			line[y] = grid[x + y * width]
		line = distance_line(line)
		for y in height:
			grid[x + y * width] = line[y]
	for y in height:
		line = grid.slice(y * width, (y + 1) * width)
		line = distance_line(line)
		for x in width:
			grid[x + y * width] = line[x]
	return grid

func distance_line(f : PackedFloat32Array) -> PackedFloat32Array:
	var n : int = f.size()
	var result : PackedFloat32Array = PackedFloat32Array()
	result.resize(n)
	var hull : PackedInt32Array = PackedInt32Array()
	hull.resize(n)
	var bounds : PackedFloat32Array = PackedFloat32Array()
	bounds.resize(n + 1)
	var k : int = 0
	bounds[0] = -FAR
	bounds[1] = FAR
	for q in range(1, n):
		var s : float = intersection(f, q, hull[k])
		while s <= bounds[k]:
			k -= 1
			s = intersection(f, q, hull[k])
		k += 1
		hull[k] = q
		bounds[k] = s
		bounds[k + 1] = FAR
	k = 0
	for q in n:
		while bounds[k + 1] < q:
			k += 1
		result[q] = (q - hull[k]) * (q - hull[k]) + f[hull[k]]
	return result

func intersection(f : PackedFloat32Array, q : int, p : int) -> float:
	return ((f[q] + q * q) - (f[p] + p * p)) / (2.0 * (q - p))

func blur(field : PackedFloat32Array, width : int, height : int, direction : Vector2i) -> PackedFloat32Array:
	var weights : Array[float] = [1.0, 4.0, 6.0, 4.0, 1.0]
	var result : PackedFloat32Array = PackedFloat32Array()
	result.resize(field.size())
	for y in height:
		for x in width:
			var sum : float = 0.0
			for i in 5:
				var sx : int = clampi(x + (i - 2) * direction.x, 0, width - 1)
				var sy : int = clampi(y + (i - 2) * direction.y, 0, height - 1)
				sum += field[sx + sy * width] * weights[i]
			result[x + y * width] = sum / 16.0
	return result
