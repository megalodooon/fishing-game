extends RefCounted
class_name CanvasClip


#------------------------#
var items : Array[RID] = []
#------------------------#


func _init(parent : CanvasItem, count : int = 4, useParentMaterial : bool = true) -> void:
	for i in count:
		var item : RID = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, parent.get_canvas_item())
		RenderingServer.canvas_item_set_use_parent_material(item, useParentMaterial)
		items.append(item)

func _notification(what : int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for item in items:
			RenderingServer.free_rid(item)

func record(rects : Array[Rect2], draw : Callable) -> void:
	for i in items.size():
		RenderingServer.canvas_item_clear(items[i])
		if i < rects.size() and rects[i].has_area():
			RenderingServer.canvas_item_set_clip(items[i], true)
			RenderingServer.canvas_item_set_custom_rect(items[i], true, rects[i])
			draw.call(items[i])

static func art_rect(sprite : Sprite2D, margin : int, extra : Rect2i = Rect2i()) -> Rect2:
	var full : Rect2i = Rect2i(Vector2i.ZERO, Vector2i(sprite.texture.get_size()))
	var used : Rect2i = sprite.texture.get_image().get_used_rect()
	if extra.has_area():
		used = used.merge(extra)
	var bounds : Rect2i = used.grow(margin).intersection(full)
	var rect : Rect2 = Rect2(sprite.offset - (Vector2(full.size) / 2.0 if sprite.centered else Vector2.ZERO) + Vector2(bounds.position), bounds.size)
	for child in sprite.get_children():
		if child is Sprite2D and child.texture:
			rect = rect.merge(child.transform * art_rect(child, margin))
	return rect

static func clip_to_art(sprite : Sprite2D, margin : int, extra : Rect2i = Rect2i()) -> void:
	if not sprite.texture or sprite.region_enabled:
		return
	clip_to_rect(sprite, art_rect(sprite, margin, extra))
	if not sprite.has_meta(&"clip_refresh"):
		var refresh : Callable = func() -> void: CanvasClip.clip_to_art(sprite, margin, extra)
		sprite.set_meta(&"clip_refresh", refresh)
		sprite.texture_changed.connect(refresh)
		sprite.child_entered_tree.connect(refresh.unbind(1))
		sprite.child_exiting_tree.connect(refresh.unbind(1))
	var own : Callable = sprite.get_meta(&"clip_refresh")
	for child in sprite.get_children():
		if child is Sprite2D and not child.texture_changed.is_connected(own):
			child.texture_changed.connect(own)

static func clip_to_rect(item : CanvasItem, rect : Rect2) -> void:
	RenderingServer.canvas_item_set_custom_rect(item.get_canvas_item(), true, rect)
	RenderingServer.canvas_item_set_clip(item.get_canvas_item(), true)
	var keep : Callable = RenderingServer.canvas_item_set_clip.bind(item.get_canvas_item(), true)
	if not item.draw.is_connected(keep):
		item.draw.connect(keep)

static func pixel_aligned(item : CanvasItem) -> bool:
	var xform : Transform2D = item.get_viewport().get_final_transform() * item.get_global_transform_with_canvas()
	return xform.x.y == 0.0 and xform.y.x == 0.0 and xform.x.x == xform.y.y and xform.x.x == floorf(xform.x.x) and xform.origin == xform.origin.floor()

static func inner_rect(xform : Transform2D, rect : Rect2) -> Rect2:
	var center : Vector2 = xform * rect.get_center()
	var half : Vector2 = rect.size / 2.0 * xform.get_scale().abs()
	var angle : float = xform.get_rotation()
	var c : float = absf(cos(angle))
	var s : float = absf(sin(angle))
	var inner : Vector2 = Vector2(half.x * c - half.y * s, half.y * c - half.x * s)
	if inner.x <= 0.0 or inner.y <= 0.0:
		return Rect2()
	return Rect2(center - inner, inner * 2.0)

# Grid the uncovered rects snap to, in pixels.
const COVER_BLOCK : int = 4
# Per cover texture, the rects its opaque pixels leave open (see open_rects).
static var coverCache : Dictionary = {}

# The parts of area (in item's local pixels) that the cover sprite's fully
# opaque pixels don't hide, as a few rects. What's under the cover never
# shows, so drawing item only inside them gives the same picture. Works when
# the cover sits unscaled and unrotated exactly over the area (an island
# room's land over its water); otherwise it's the whole area.
static func uncovered_rects(item : CanvasItem, area : Rect2, cover : Sprite2D) -> Array[Rect2]:
	var whole : Array[Rect2] = [area]
	if not cover or not cover.texture or cover.region_enabled or cover.flip_h or cover.flip_v or cover.centered:
		return whole
	var relative : Transform2D = item.get_global_transform().affine_inverse() * cover.get_global_transform()
	if relative.x != Vector2.RIGHT or relative.y != Vector2.DOWN or relative.origin + cover.offset != area.position or cover.texture.get_size() != area.size:
		return whole
	var open : Variant = open_rects(cover.texture)
	if open == null:
		return whole
	var rects : Array[Rect2] = []
	for rect in open:
		rects.append(Rect2(rect.position + area.position, rect.size))
	return rects

# The texture's pixels that aren't fully opaque, grown by one pixel to spare
# and snapped out to a grid of COVER_BLOCK, as rows of runs merged into rects.
# Null when the texture's pixels can't be read.
static func open_rects(texture : Texture2D) -> Variant:
	if not coverCache.has(texture):
		Preloader.hand_over()
	if not coverCache.has(texture):
		coverCache[texture] = find_open_rects(texture)
	return coverCache[texture]

# What open_rects gives, worked out without the cache. Safe on any thread
# when the texture is a PNG file (the Preloader does it for the island land).
static func find_open_rects(texture : Texture2D) -> Variant:
	var source : Image = null
	var path : String = texture.resource_path
	if path.ends_with(".png") and FileAccess.file_exists(path):
		source = Image.new()
		if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			source = null
	if not source:
		source = texture.get_image()
	var size : Vector2i = Vector2i(texture.get_size())
	if not source or source.get_size() != size or size.x % COVER_BLOCK != 0 or size.y % COVER_BLOCK != 0:
		return null
	if source.is_compressed():
		source.decompress()
	# Fully opaque pixels only, then one pixel less all round.
	var solid : BitMap = BitMap.new()
	solid.create_from_image_alpha(source, 254.5 / 255.0)
	solid.grow_mask(-1, Rect2i(Vector2i.ZERO, size))
	# Averaged down to one value per block: 255 only where the whole block is solid.
	var blocks : Image = solid.convert_to_image()
	var level : int = COVER_BLOCK
	while level > 1:
		blocks.shrink_x2()
		level = level >> 1
	@warning_ignore("integer_division")
	var columns : int = size.x / COVER_BLOCK
	@warning_ignore("integer_division")
	var rows : int = size.y / COVER_BLOCK
	var data : PackedByteArray = blocks.get_data()
	var rects : Array[Rect2] = []
	var running : Dictionary = {}
	for row in rows:
		var next : Dictionary = {}
		var start : int = -1
		for column in columns + 1:
			var covered : bool = column == columns or data[row * columns + column] == 255
			if not covered and start < 0:
				start = column
			elif covered and start >= 0:
				var run : Vector2i = Vector2i(start, column)
				if running.has(run):
					var index : int = running[run]
					rects[index].size.y += COVER_BLOCK
					next[run] = index
				else:
					rects.append(Rect2(start * COVER_BLOCK, row * COVER_BLOCK, (column - start) * COVER_BLOCK, COVER_BLOCK))
					next[run] = rects.size() - 1
				start = -1
		running = next
	return rects

static func band_rects(outer : Rect2, hole : Rect2) -> Array[Rect2]:
	var start : Vector2 = hole.position.ceil()
	var end : Vector2 = hole.end.floor()
	if end.x <= start.x or end.y <= start.y:
		return [outer]
	var cut : Rect2 = Rect2(start, end - start).intersection(outer)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [outer]
	return [
		Rect2(outer.position.x, outer.position.y, outer.size.x, cut.position.y - outer.position.y),
		Rect2(outer.position.x, cut.end.y, outer.size.x, outer.end.y - cut.end.y),
		Rect2(outer.position.x, cut.position.y, cut.position.x - outer.position.x, cut.size.y),
		Rect2(cut.end.x, cut.position.y, outer.end.x - cut.end.x, cut.size.y),
	]
