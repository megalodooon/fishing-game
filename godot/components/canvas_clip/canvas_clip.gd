extends RefCounted
class_name CanvasClip


#------------------------#
var items : Array[RID] = []
#------------------------#


func _init(parent : CanvasItem, count : int = 4) -> void:
	for i in count:
		var item : RID = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, parent.get_canvas_item())
		RenderingServer.canvas_item_set_use_parent_material(item, true)
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

static func art_rect(sprite : Sprite2D, margin : int) -> Rect2:
	var full : Vector2 = sprite.texture.get_size()
	var used : Rect2 = Rect2(sprite.texture.get_image().get_used_rect().grow(margin)).intersection(Rect2(Vector2.ZERO, full))
	var rect : Rect2 = Rect2(sprite.offset - (full / 2.0 if sprite.centered else Vector2.ZERO) + used.position, used.size)
	for child in sprite.get_children():
		if child is Sprite2D and child.texture:
			rect = rect.merge(child.transform * art_rect(child, margin))
	return rect

static func clip_to_rect(item : CanvasItem, rect : Rect2) -> void:
	RenderingServer.canvas_item_set_custom_rect(item.get_canvas_item(), true, rect)
	RenderingServer.canvas_item_set_clip(item.get_canvas_item(), true)
	item.draw.connect(RenderingServer.canvas_item_set_clip.bind(item.get_canvas_item(), true))

static func pixel_aligned(item : CanvasItem) -> bool:
	var xform : Transform2D = item.get_viewport().get_final_transform() * item.get_global_transform_with_canvas()
	return xform.x.y == 0.0 and xform.y.x == 0.0 and xform.x.x == xform.y.y and xform.x.x == floorf(xform.x.x) and xform.origin == xform.origin.floor()

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
