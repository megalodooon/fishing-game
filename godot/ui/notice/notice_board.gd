extends Control
class_name NoticeBoard

# Small toasts in the top right corner: an icon, a title and at most two short
# lines, stacked three deep, fading out after a few seconds. The same title
# again while it's still up refreshes it (and counts, like "x3") instead of
# stacking. Big moments (a level up, a rare drop, a quest done) use banner():
# one line in the middle of the top edge for a moment. Everything is drawn
# at the HUD's smaller scale (UiKit.HUD).

#------------------------#
@export var ui : InventoryUI
@export var maxWidth : int = 84
@export var margin : int = 2
@export var gap : int = 1
@export var padding : int = 2
@export var duration : float = 3.6
@export var maxShown : int = 3
@export var inTime : float = 0.25
@export var outTime : float = 0.3
@export var bannerTime : float = 2.6

var notices : Array[Dictionary] = []
var banners : Array[Dictionary] = []
# A hint that stays up until replaced (the first-fish tutorial).
var coachText : PackedStringArray = PackedStringArray()
var coachIcon : Texture2D
#------------------------#


static func find(tree : SceneTree) -> NoticeBoard:
	return tree.get_first_node_in_group(&"notice_boards") as NoticeBoard

func _ready() -> void:
	add_to_group(&"notice_boards")
	# Toasts keep moving while the game is paused (like under a conversation).
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_TOP_LEFT)
	set_process(false)
	ui.laid_out.connect(fit)
	fit()

func fit() -> void:
	scale = ui.scale * UiKit.HUD
	size = ui.size / UiKit.HUD

# The icon sits left of the title, the color is the title's and the edge's.
func post(title : String, text : String, color : Color, icon : Texture2D = null) -> void:
	for notice in notices:
		if notice.title == title and notice.age < duration:
			if notice.text != text:
				notice.text = text
				notice.lines = wrap_text(text, notice.icon)
				notice.size = measure(title, notice.lines, notice.icon, notice.count + 1)
			notice.count += 1
			notice.age = minf(notice.age, inTime)
			return
	var lines : PackedStringArray = wrap_text(text, icon)
	notices.push_front({"title": title, "text": text, "lines": lines, "color": color, "icon": icon, "size": measure(title, lines, icon, 1), "age": 0.0, "y": top_edge() - 6.0, "count": 1})
	for i in range(maxShown, notices.size()):
		notices[i].age = maxf(notices[i].age, duration)
	set_process(true)

# A short line in the middle of the top edge, for big moments.
func banner(title : String, text : String, color : Color, icon : Texture2D = null) -> void:
	banners.append({"title": title, "text": text, "color": color, "icon": icon, "age": 0.0})
	set_process(true)

func coach(text : String, icon : Texture2D = null) -> void:
	coachText = ui.wrap_lines(text, 150.0, ui.statSize) if not text.is_empty() else PackedStringArray()
	coachIcon = icon
	queue_redraw()

func wrap_text(text : String, icon : Texture2D) -> PackedStringArray:
	if text.is_empty():
		return PackedStringArray()
	var lines : PackedStringArray = ui.wrap_lines(text, maxWidth - padding * 2.0 - inset(icon), ui.statSize)
	if lines.size() > 2:
		lines.resize(2)
		lines[1] = lines[1].left(maxi(lines[1].length() - 2, 0)) + ".."
	return lines

func inset(icon : Texture2D) -> float:
	return minf(icon.get_width(), 9.0) + 2.0 if icon else 0.0

func measure(title : String, lines : PackedStringArray, icon : Texture2D, count : int) -> Vector2:
	var shown : String = title + (" x%d" % count if count > 1 else "")
	var width : float = ui.font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x
	for line in lines:
		width = maxf(width, ui.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x)
	var height : float = ui.statSize + 1.0 + lines.size() * (ui.statSize + 1.0)
	if icon:
		height = maxf(height, minf(icon.get_height(), 9.0))
	return Vector2(ceilf(minf(width, maxWidth - padding * 2.0 - inset(icon)) + inset(icon)), height).ceil() + Vector2(padding * 2.0 + 1.0, padding * 2.0)

func clear() -> void:
	notices.clear()
	banners.clear()
	queue_redraw()

# Notices fade back behind open menus once they've been seen.
func menu_open() -> bool:
	var hub : MenuHub = MenuHub.find(get_tree())
	return hub != null and hub.dim > 0.5

# Notices sit under the menus' tab strip while it's up.
func top_edge() -> float:
	var hub : MenuHub = MenuHub.find(get_tree())
	return margin + (MenuHub.HEIGHT / UiKit.HUD if hub and hub.current >= 0 else 0.0)

func _process(delta : float) -> void:
	var top : float = top_edge()
	for i in range(notices.size() - 1, -1, -1):
		notices[i].age += delta
		if notices[i].age >= duration + outTime:
			notices.remove_at(i)
	for notice in notices:
		notice.y = lerpf(notice.y, top, 1.0 - exp(-16.0 * delta))
		top += notice.size.y + gap
	if not banners.is_empty():
		banners[0].age += delta
		if banners[0].age >= bannerTime:
			banners.pop_front()
	set_process(not notices.is_empty() or not banners.is_empty())
	queue_redraw()

# 0 while hidden, 1 in place. Fades and drops in, fades out.
func shown(notice : Dictionary) -> float:
	if notice.age >= duration:
		return 1.0 - clampf((notice.age - duration) / outTime, 0.0, 1.0)
	return clampf(notice.age / inTime, 0.0, 1.0)

func _draw() -> void:
	var font : Font = ui.font
	for notice in notices:
		var box : Vector2 = notice.size
		var amount : float = shown(notice)
		var at : Vector2 = Vector2(size.x - margin - box.x, notice.y).round()
		var area : Rect2 = Rect2(at, box)
		var alpha : float = amount * (lerpf(1.0, 0.35, clampf((notice.age - 1.2) / 0.5, 0.0, 1.0)) if menu_open() else 1.0)
		draw_rect(area, Color(0.03, 0.06, 0.11, 0.82 * alpha))
		draw_rect(Rect2(at, Vector2(1.0, box.y)), Color(notice.color, alpha))
		var pen : Vector2 = at + Vector2(padding + 1.0, padding)
		var icon : Texture2D = notice.icon
		if icon:
			var drawn : float = minf(9.0 / maxf(icon.get_height(), icon.get_width()), 1.0)
			var extent : Vector2 = icon.get_size() * drawn
			draw_texture_rect(icon, Rect2((pen + Vector2(0.0, (box.y - padding * 2.0 - extent.y) * 0.5)).round(), extent), false, Color(1.0, 1.0, 1.0, alpha))
			pen.x += inset(icon)
		var title : String = notice.title + (" x%d" % notice.count if notice.count > 1 else "")
		draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.statSize)), title, HORIZONTAL_ALIGNMENT_LEFT, area.end.x - pen.x - padding, ui.statSize, Color(notice.color, alpha))
		pen.y += ui.statSize + 1.0
		for line in notice.lines:
			draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.statSize)), line, HORIZONTAL_ALIGNMENT_LEFT, area.end.x - pen.x - padding, ui.statSize, Color(ui.textColor.lerp(ui.dimColor, 0.25), alpha))
			pen.y += ui.statSize + 1.0
	draw_banner(font)
	draw_coach(font)

func draw_coach(font : Font) -> void:
	if coachText.is_empty() or menu_open():
		return
	var width : float = 0.0
	for line in coachText:
		width = maxf(width, UiKit.text_width(font, line, ui.statSize))
	var face : float = 12.0 if coachIcon else 0.0
	var box : Rect2 = Rect2(0.0, 0.0, ceilf(width + face + 6.0), maxf(coachText.size() * (ui.statSize + 1.0) + 4.0, face + 2.0))
	box.position = Vector2(floorf((size.x - box.size.x) * 0.5), size.y - box.size.y - 26.0)
	draw_rect(box, Color(0.03, 0.06, 0.11, 0.85))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), Cast.color_of("pip"))
	if coachIcon:
		draw_texture_rect(coachIcon, Rect2(box.position + Vector2(2.0, 1.0), Vector2(10.0, 10.0)), false)
	var pen : Vector2 = box.position + Vector2(face + 3.0, 2.0)
	for line in coachText:
		draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.statSize)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.textColor)
		pen.y += ui.statSize + 1.0

func draw_banner(font : Font) -> void:
	if banners.is_empty():
		return
	var banner_now : Dictionary = banners[0]
	var age : float = banner_now.age
	var alpha : float = clampf(age / 0.2, 0.0, 1.0) * clampf((bannerTime - age) / 0.4, 0.0, 1.0)
	var title : String = banner_now.title
	var text : String = banner_now.text
	var width : float = maxf(UiKit.text_width(font, title, ui.titleSize), UiKit.text_width(font, text, ui.statSize)) + 10.0
	var icon : Texture2D = banner_now.icon
	if icon:
		width += 11.0
	var height : float = ui.titleSize + 4.0 + (ui.statSize + 1.0 if not text.is_empty() else 0.0)
	var box : Rect2 = Rect2(floorf((size.x - width) * 0.5), roundf(top_edge() + 14.0 - (1.0 - clampf(age / 0.2, 0.0, 1.0)) * 3.0), ceilf(width), height)
	draw_rect(box, Color(0.03, 0.06, 0.11, 0.85 * alpha))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), Color(banner_now.color, alpha))
	var x : float = box.position.x + 5.0
	if icon:
		var drawn : float = minf(9.0 / maxf(icon.get_height(), icon.get_width()), 1.0)
		draw_texture_rect(icon, Rect2(Vector2(x, box.position.y + (box.size.y - icon.get_height() * drawn) * 0.5).round(), icon.get_size() * drawn), false, Color(1.0, 1.0, 1.0, alpha))
		x += 11.0
	draw_string(font, Vector2(x, box.position.y + 2.0 + font.get_ascent(ui.titleSize)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize, Color(banner_now.color, alpha))
	if not text.is_empty():
		draw_string(font, Vector2(x, box.position.y + ui.titleSize + 3.0 + font.get_ascent(ui.statSize)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, Color(ui.textColor, alpha))
