extends Control
class_name NoticeBoard

# Short messages that slide in at the top right, stack under each other and
# slide back out after a while. Drawn in the inventory UI's style.

#------------------------#
@export var ui : InventoryUI
@export var maxWidth : int = 96
@export var margin : int = 2
@export var gap : int = 2
@export var padding : int = 3
@export var duration : float = 5.0
# Older notices slide out early to keep at most this many on screen.
@export var maxShown : int = 2
@export var inTime : float = 0.35
@export var outTime : float = 0.25

var notices : Array[Dictionary] = []
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_TOP_LEFT)
	set_process(false)
	ui.laid_out.connect(fit)
	fit()

func fit() -> void:
	scale = ui.scale
	size = ui.size

# The icon sits left of the text, the color is the title's and the edge's.
func post(title : String, text : String, color : Color, icon : Texture2D = null) -> void:
	var inset : float = icon.get_width() + 2.0 if icon else 0.0
	var lines : PackedStringArray = ui.wrap_lines(text, maxWidth - padding * 2.0 - inset, ui.statSize) if not text.is_empty() else PackedStringArray()
	var width : float = ui.font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize).x
	for line in lines:
		width = maxf(width, ui.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x)
	var height : float = ui.titleSize + lines.size() * (ui.statSize + 1.0)
	if icon:
		height = maxf(height, icon.get_height())
	var box : Vector2 = Vector2(ceilf(width + inset), height).ceil() + Vector2(padding * 2.0 + 1.0, padding * 2.0)
	for i in range(maxShown - 1, notices.size()):
		notices[i].age = maxf(notices[i].age, duration)
	notices.push_front({"title": title, "lines": lines, "color": color, "icon": icon, "size": box, "age": 0.0, "y": float(margin)})
	set_process(true)

func clear() -> void:
	notices.clear()
	queue_redraw()

func _process(delta : float) -> void:
	var top : float = margin
	for i in range(notices.size() - 1, -1, -1):
		notices[i].age += delta
		if notices[i].age >= duration + outTime:
			notices.remove_at(i)
	for notice in notices:
		notice.y = lerpf(notice.y, top, 1.0 - exp(-14.0 * delta))
		top += notice.size.y + gap
	set_process(not notices.is_empty())
	queue_redraw()

# 0 while hidden to the right, 1 in place. Slides in with a little overshoot.
func shown(notice : Dictionary) -> float:
	if notice.age >= duration:
		var out : float = clampf((notice.age - duration) / outTime, 0.0, 1.0)
		return 1.0 - out * out
	var t : float = clampf(notice.age / inTime, 0.0, 1.0) - 1.0
	return 1.0 + t * t * (2.7 * t + 1.7)

func _draw() -> void:
	var font : Font = ui.font
	for notice in notices:
		var box : Vector2 = notice.size
		var amount : float = shown(notice)
		var at : Vector2 = Vector2(size.x - margin - box.x + (1.0 - amount) * (box.x + margin + 2.0), notice.y).round()
		var area : Rect2 = Rect2(at, box)
		var alpha : float = clampf(amount * 1.5, 0.0, 1.0)
		draw_rect(area, Color(ui.frameColor, alpha))
		draw_rect(area.grow(-1.0), Color(ui.slotColor, 0.97 * alpha))
		draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(1.0, box.y - 2.0)), Color(notice.color, alpha))
		var pen : Vector2 = at + Vector2(padding + 1.0, padding)
		var icon : Texture2D = notice.icon
		if icon:
			draw_texture(icon, (pen + Vector2(-1.0, (box.y - padding * 2.0 - icon.get_height()) * 0.5)).round(), Color(1.0, 1.0, 1.0, alpha))
			pen.x += icon.get_width() + 1.0
		draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.titleSize)), notice.title, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize, Color(notice.color, alpha))
		pen.y += ui.titleSize + 1.0
		for line in notice.lines:
			draw_string(font, pen + Vector2(0.0, font.get_ascent(ui.statSize)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, Color(ui.textColor, alpha))
			pen.y += ui.statSize + 1.0
