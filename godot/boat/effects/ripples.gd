@tool
extends Node2D
class_name BoatRipples

const FAR : float = 1e20
const MAX_RINGS : int = 24

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
@export var margin : int = 32:
	set(value):
		margin = value
		build()

@export_group("Rings")
@export var interval : float = 0.9
@export var waveSpeed : float = 4.0
@export var lifetime : float = 3.0

@onready var boat : Boat = owner as Boat

var distanceTexture : ImageTexture
var rings : Array[Vector4] = []
var seeds : PackedFloat32Array = PackedFloat32Array()
var timer : float = 0.0
var bounds : Rect2
var waterlineRect : Rect2
#------------------------#


func _ready() -> void:
	build()
	for i in floori(lifetime / interval):
		rings.append(Vector4(global_position.x, global_position.y, lifetime - (i + 1) * interval, 1.0))
		seeds.append(randf() * 100.0)

func _process(delta : float) -> void:
	var speed : float = boat.speed if boat and not Engine.is_editor_hint() else 0.0
	for i in range(rings.size() - 1, -1, -1):
		rings[i].x -= speed * delta
		rings[i].z += delta
		if rings[i].z > lifetime:
			rings.remove_at(i)
			seeds.remove_at(i)
	timer += delta
	if timer >= interval:
		timer = fmod(timer, interval)
		if rings.size() < MAX_RINGS:
			rings.append(Vector4(global_position.x, global_position.y, 0.0, 1.0))
			seeds.append(randf() * 100.0)
	update_shader()
	queue_redraw()

func update_shader() -> void:
	if not distanceTexture:
		return
	var packed : PackedVector4Array = PackedVector4Array()
	var packedSeeds : PackedFloat32Array = seeds.duplicate()
	packed.resize(MAX_RINGS)
	packedSeeds.resize(MAX_RINGS)
	var reach : float = 2.0 * shader_value("crest_width") + 2.5 * shader_value("trough_width") + 0.5 * absf(shader_value("wobble")) + 1.0
	var hullCenter : Vector2 = shader_value("hull_center")
	var hullRadii : Vector2 = shader_value("hull_radii")
	bounds = Rect2()
	for i in rings.size():
		var ring : Vector4 = rings[i]
		var center : Vector2 = to_local(Vector2(ring.x, ring.y))
		var radius : float = ring.z * waveSpeed
		packed[i] = Vector4(center.x, center.y, radius, ring.w * pow(1.0 - ring.z / lifetime, 2.0))
		var extent : float = radius + reach
		var area : Rect2 = waterlineRect.grow(extent + 2.0).merge(Rect2(hullCenter - hullRadii, hullRadii * 2.0).grow(extent + 2.0))
		area.position += center
		bounds = area if i == 0 else bounds.merge(area)
	var rid : RID = material.get_rid()
	RenderingServer.material_set_param(rid, "distance_field", distanceTexture.get_rid())
	RenderingServer.material_set_param(rid, "rings", packed)
	RenderingServer.material_set_param(rid, "seeds", packedSeeds)
	RenderingServer.material_set_param(rid, "ring_count", rings.size())

func shader_value(parameter : StringName) -> Variant:
	var value : Variant = material.get_shader_parameter(parameter)
	return value if value != null else RenderingServer.shader_get_parameter_default(material.shader.get_rid(), parameter)

func _draw() -> void:
	if not rings.is_empty():
		draw_rect(bounds, Color.WHITE)

func build() -> void:
	if not is_node_ready() or not deckTexture or not frontTexture:
		return
	var deck : Image = deckTexture.get_image()
	var front : Image = frontTexture.get_image()
	var width : int = deck.get_width() + margin * 2
	var height : int = deck.get_height() + margin * 2
	var inside : PackedByteArray = waterline_mask(deck, front, width, height)
	var low : Vector2i = Vector2i(width, height)
	var high : Vector2i = Vector2i(-1, -1)
	for i in inside.size():
		if inside[i]:
			@warning_ignore("integer_division")
			var cell : Vector2i = Vector2i(i % width, i / width)
			low = low.min(cell)
			high = high.max(cell)
	waterlineRect = Rect2(Vector2(low) - Vector2(width, height) / 2.0, Vector2(high - low + Vector2i.ONE))
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
	var breaks : PackedFloat32Array = PackedFloat32Array()
	breaks.resize(n + 1)
	var k : int = 0
	breaks[0] = -FAR
	breaks[1] = FAR
	for q in range(1, n):
		var s : float = intersection(f, q, hull[k])
		while s <= breaks[k]:
			k -= 1
			s = intersection(f, q, hull[k])
		k += 1
		hull[k] = q
		breaks[k] = s
		breaks[k + 1] = FAR
	k = 0
	for q in n:
		while breaks[k + 1] < q:
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
