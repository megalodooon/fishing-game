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
var bands : CanvasClip
var reach : float = 0.0
var hullCenter : Vector2
var hullRadii : Vector2
var paramsRead : bool = false
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
	update_bands()

func read_params() -> bool:
	var values : Array = [shader_value("crest_width"), shader_value("trough_width"), shader_value("wobble"), shader_value("hull_center"), shader_value("hull_radii")]
	if values.has(null):
		return false
	reach = 2.0 * values[0] + 2.5 * values[1] + 0.5 * absf(values[2]) + 1.0
	hullCenter = values[3]
	hullRadii = values[4]
	paramsRead = not Engine.is_editor_hint()
	return true

func update_shader() -> void:
	if not distanceTexture or (not paramsRead and not read_params()):
		return
	var packed : PackedVector4Array = PackedVector4Array()
	var packedSeeds : PackedFloat32Array = seeds.duplicate()
	packed.resize(MAX_RINGS)
	packedSeeds.resize(MAX_RINGS)
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

func update_bands() -> void:
	if not bands:
		bands = CanvasClip.new(self)
	var outer : Rect2 = Rect2(bounds.position.floor() - Vector2.ONE, Vector2.ZERO).expand(bounds.end.ceil() + Vector2.ONE)
	var hole : Rect2 = transform.affine_inverse() * boat.opaque_rect() if boat and not Engine.is_editor_hint() and CanvasClip.pixel_aligned(self) else Rect2()
	var rects : Array[Rect2] = []
	if not rings.is_empty():
		rects = CanvasClip.band_rects(outer, hole)
	bands.record(rects, draw_band)

func draw_band(item : RID) -> void:
	RenderingServer.canvas_item_add_rect(item, bounds, Color.WHITE)

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
	line.resize(height)
	for x in width:
		for y in height:
			line[y] = grid[x + y * width]
		distance_line(line, grid, x, width)
	for y in height:
		distance_line(grid.slice(y * width, (y + 1) * width), grid, y * width, 1)
	return grid

func distance_line(f : PackedFloat32Array, result : PackedFloat32Array, start : int, stride : int) -> void:
	var n : int = f.size()
	var hull : PackedInt32Array = PackedInt32Array()
	hull.resize(n)
	var breaks : PackedFloat32Array = PackedFloat32Array()
	breaks.resize(n + 1)
	var k : int = 0
	breaks[0] = -FAR
	breaks[1] = FAR
	for q in range(1, n):
		var lifted : float = f[q] + q * q
		var p : int = hull[k]
		var s : float = (lifted - (f[p] + p * p)) / (2.0 * (q - p))
		while s <= breaks[k]:
			k -= 1
			p = hull[k]
			s = (lifted - (f[p] + p * p)) / (2.0 * (q - p))
		k += 1
		hull[k] = q
		breaks[k] = s
		breaks[k + 1] = FAR
	k = 0
	for q in n:
		while breaks[k + 1] < q:
			k += 1
		var p : int = hull[k]
		result[start + q * stride] = (q - p) * (q - p) + f[p]

func blur(field : PackedFloat32Array, width : int, height : int, direction : Vector2i) -> PackedFloat32Array:
	var result : PackedFloat32Array = PackedFloat32Array()
	result.resize(field.size())
	var lines : int = height if direction.x != 0 else width
	var length : int = width if direction.x != 0 else height
	var step : int = 1 if direction.x != 0 else width
	var across : int = width if direction.x != 0 else 1
	var last : int = length - 1
	for line in lines:
		var base : int = line * across
		for i in length:
			var sum : float = 0.0
			if i >= 2 and i <= last - 2:
				var at : int = base + i * step
				sum += field[at - step - step] * 1.0
				sum += field[at - step] * 4.0
				sum += field[at] * 6.0
				sum += field[at + step] * 4.0
				sum += field[at + step + step] * 1.0
			else:
				sum += field[base + maxi(i - 2, 0) * step] * 1.0
				sum += field[base + maxi(i - 1, 0) * step] * 4.0
				sum += field[base + i * step] * 6.0
				sum += field[base + mini(i + 1, last) * step] * 4.0
				sum += field[base + mini(i + 2, last) * step] * 1.0
			result[base + i * step] = sum / 16.0
	return result
