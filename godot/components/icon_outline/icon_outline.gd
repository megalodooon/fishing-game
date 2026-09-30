extends RefCounted
class_name IconOutline

# The white one-pixel outline the UI draws around an icon's opaque pixels,
# one pixel bigger than the icon on every side, and how far the middle of
# the icon's visible pixels is from the middle of its canvas. Made once per
# icon and shared by every menu, along with the rect of the icon's visible
# pixels (for the icon held in hand).
#
# The Preloader prepares them for all the content ahead of time, on its
# thread, from the icons' PNG files (the export includes them for this).
# Reading an icon back from the GPU instead waits for a whole frame, so
# that's only the fallback for icons that aren't a PNG file.

static var outlines : Dictionary = {}
static var offsets : Dictionary = {}
static var usedRects : Dictionary = {}
# White silhouettes of the icons, for things not found yet, tinted when drawn.
static var fills : Dictionary = {}
# Outline pictures made off the main thread, turned into textures on first use.
static var prepared : Dictionary = {}
static var mutex : Mutex = Mutex.new()


static func outline(icon : Texture2D) -> Texture2D:
	mutex.lock()
	var known : bool = outlines.has(icon)
	var texture : Texture2D = outlines.get(icon)
	var ready : Array = prepared.get(icon, [])
	mutex.unlock()
	if known:
		return texture
	if not ready.is_empty():
		texture = ImageTexture.create_from_image(ready[0])
		store(icon, texture, ready[1], ready[2], ImageTexture.create_from_image(ready[3]))
		return texture
	return make(icon)

# The icon as a flat white shape, the same size as the icon.
static func fill(icon : Texture2D) -> Texture2D:
	outline(icon)
	mutex.lock()
	var shape : Texture2D = fills.get(icon)
	mutex.unlock()
	return shape

# The rect of the icon's visible pixels.
static func used_rect(icon : Texture2D) -> Rect2:
	outline(icon)
	mutex.lock()
	var used : Rect2 = usedRects.get(icon, Rect2())
	mutex.unlock()
	return used

static func offset(icon : Texture2D) -> Vector2:
	outline(icon)
	mutex.lock()
	var shift : Vector2 = offsets.get(icon, Vector2.ZERO)
	mutex.unlock()
	return shift

# Builds the outline from the icon's PNG file, without the GPU. Safe to call
# from any thread; does nothing for icons that aren't a PNG file.
static func prepare(icon : Texture2D) -> void:
	var path : String = icon.resource_path if icon else ""
	if not path.ends_with(".png") or not FileAccess.file_exists(path):
		return
	var source : Image = Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return
	var built : Array = build(source)
	mutex.lock()
	prepared[icon] = built
	mutex.unlock()

# Builds it from the texture on the GPU.
static func make(icon : Texture2D) -> Texture2D:
	var source : Image = icon.get_image() if icon else null
	if not source:
		store(icon, null, null, null)
		return null
	var built : Array = build(source)
	var texture : ImageTexture = ImageTexture.create_from_image(built[0])
	store(icon, texture, built[1], built[2], ImageTexture.create_from_image(built[3]))
	return texture

# The outline picture, the offset of the visible middle, the visible rect and
# the white silhouette.
static func build(source : Image) -> Array:
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var width : int = source.get_width()
	var height : int = source.get_height()
	var pixels : PackedByteArray = source.get_data()
	# Opaque pixels (alpha over half), with two empty pixels of padding all
	# round so the neighbour checks need no bounds checks.
	var stride : int = width + 4
	var solid : PackedByteArray = PackedByteArray()
	solid.resize(stride * (height + 4))
	for y in height:
		var row : int = (y + 2) * stride + 2
		for x in width:
			if pixels[(y * width + x) * 4 + 3] >= 128:
				solid[row + x] = 1
	# Outline pixel (x, y) sits over source pixel (x - 1, y - 1): empty there
	# with an opaque pixel left, right, above or below it.
	var out : PackedByteArray = PackedByteArray()
	out.resize((width + 2) * (height + 2) * 4)
	for y in height + 2:
		for x in width + 2:
			var at : int = (y + 1) * stride + x + 1
			if solid[at] == 0 and (solid[at - 1] == 1 or solid[at + 1] == 1 or solid[at - stride] == 1 or solid[at + stride] == 1):
				var index : int = (y * (width + 2) + x) * 4
				out[index] = 255
				out[index + 1] = 255
				out[index + 2] = 255
				out[index + 3] = 255
	var shape : PackedByteArray = PackedByteArray()
	shape.resize(width * height * 4)
	for y in height:
		var row : int = (y + 2) * stride + 2
		for x in width:
			if solid[row + x] == 1:
				var index : int = (y * width + x) * 4
				shape[index] = 255
				shape[index + 1] = 255
				shape[index + 2] = 255
				shape[index + 3] = 255
	var used : Rect2 = Rect2(source.get_used_rect())
	return [Image.create_from_data(width + 2, height + 2, false, Image.FORMAT_RGBA8, out), used.get_center() - Vector2(width, height) * 0.5, used, Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, shape)]

static func store(icon : Texture2D, texture : Texture2D, shift : Variant, used : Variant, shape : Texture2D = null) -> void:
	mutex.lock()
	outlines[icon] = texture
	if shape:
		fills[icon] = shape
	prepared.erase(icon)
	if shift != null:
		offsets[icon] = shift
	if used != null:
		usedRects[icon] = used
	mutex.unlock()
