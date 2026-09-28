extends MenuPanel
class_name ListMenu

# A scrollable list with a search box and a sort button, drawn in the
# inventory UI's style. Rows are dictionaries:
#   value: handed back by chosen and pointed
#   text: the name shown. search: what the search box matches (text if left out)
#   icon, tint, detail, detailColor, dim, marked, cross (an X instead of an icon)
# Pinned rows stay on top and only show while the search box is empty.

signal chosen(value : Variant)
signal pointed(value : Variant)

const NOTHING : int = -1

#------------------------#
@export var ui : InventoryUI
@export var title : String = "":
	set(value):
		title = value
		layout()
@export var framed : bool = true
@export var rowHeight : int = 12
@export var headerHeight : int = 8
@export var sortWidth : int = 24
@export var scrollSpeed : float = 20.0
@export var wheelRows : float = 1.5
@export var markColor : Color = Color(0.56, 0.93, 0.44)
@export var flashColor : Color = Color(0.95, 0.38, 0.34)
@export var flashTime : float = 0.35

var rows : Array[Dictionary] = []
var pinned : Array[Dictionary] = []
var shownRows : Array[Dictionary] = []
var sortNames : PackedStringArray = PackedStringArray()
var sorters : Array[Callable] = []
var sortIndex : int = 0
var search : LineEdit
var scroll : float = 0.0
var scrollGoal : float = 0.0
var hovered : int = NOTHING
var dragging : bool = false
var dragOffset : float = 0.0
var flashValue : Variant = null
var flashLeft : float = 0.0
var inner : Rect2
var sortRect : Rect2
var listRect : Rect2
var barRect : Rect2
#------------------------#


func _ready() -> void:
	super()
	clip_contents = true
	search = LineEdit.new()
	search.placeholder_text = "Search"
	search.context_menu_enabled = false
	search.caret_blink = true
	search.add_theme_font_override("font", ui.font)
	search.add_theme_font_size_override("font_size", ui.statSize)
	search.add_theme_color_override("font_color", ui.textColor)
	search.add_theme_color_override("font_placeholder_color", ui.dimColor)
	search.add_theme_color_override("caret_color", ui.textColor)
	search.add_theme_constant_override("minimum_character_width", 0)
	for state in ["normal", "focus", "read_only"]:
		var box : StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = ui.slotColor
		box.border_color = ui.hoverColor if state == "focus" else ui.frameColor
		box.set_border_width_all(1)
		box.set_content_margin_all(1.0)
		box.content_margin_left = 2.0
		search.add_theme_stylebox_override(state, box)
	search.text_changed.connect(refilter.unbind(1))
	search.text_submitted.connect(search.release_focus.unbind(1))
	search.gui_input.connect(search_input)
	add_child(search)
	resized.connect(layout)
	set_process(false)
	layout()

func search_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		search.release_focus()
		search.accept_event()

func set_rows(list : Array[Dictionary], top : Array[Dictionary] = []) -> void:
	rows = list
	pinned = top
	refilter()

func set_sorts(names : PackedStringArray, callables : Array[Callable]) -> void:
	sortNames = names
	sorters = callables
	sortIndex = clampi(sortIndex, 0, maxi(sorters.size() - 1, 0))
	layout()

func reset_scroll() -> void:
	scroll = 0.0
	scrollGoal = 0.0

func flash(value : Variant) -> void:
	flashValue = value
	flashLeft = flashTime
	set_process(true)

func refilter() -> void:
	var query : String = search.text.strip_edges().to_lower() if search else ""
	var matched : Array[Dictionary] = []
	for row in rows:
		if query.is_empty() or String(row.get("search", row.get("text", ""))).to_lower().contains(query):
			matched.append(row)
	if not sorters.is_empty():
		matched.sort_custom(sorters[sortIndex])
	shownRows = []
	if query.is_empty():
		shownRows.append_array(pinned)
	shownRows.append_array(matched)
	clamp_scroll()
	hovered = NOTHING
	queue_redraw()

func layout() -> void:
	if not search:
		return
	inner = Rect2(Vector2.ZERO, size).grow(-2.0 if framed else 0.0)
	var top : float = inner.position.y + (ui.titleSize + 2.0 if not title.is_empty() else 0.0)
	var sorting : bool = not sorters.is_empty()
	sortRect = Rect2(inner.end.x - sortWidth, top, sortWidth, headerHeight) if sorting else Rect2()
	search.position = Vector2(inner.position.x, top)
	search.size = Vector2(inner.size.x - (sortWidth + 1.0 if sorting else 0.0), headerHeight)
	listRect = Rect2(inner.position.x, top + headerHeight + 1.0, inner.size.x - 3.0, inner.end.y - top - headerHeight - 1.0)
	barRect = Rect2(inner.end.x - 2.0, listRect.position.y, 2.0, listRect.size.y)
	clamp_scroll()
	queue_redraw()

func max_scroll() -> float:
	return maxf(shownRows.size() * rowHeight - listRect.size.y, 0.0)

func clamp_scroll() -> void:
	scrollGoal = clampf(scrollGoal, 0.0, max_scroll())
	scroll = clampf(scroll, 0.0, max_scroll())

func row_rect(index : int) -> Rect2:
	return Rect2(listRect.position.x, listRect.position.y + index * rowHeight - scroll, listRect.size.x, rowHeight)

func row_at(point : Vector2) -> int:
	if not listRect.has_point(point):
		return NOTHING
	var index : int = floori((point.y - listRect.position.y + scroll) / rowHeight)
	return index if index >= 0 and index < shownRows.size() else NOTHING

func thumb_rect() -> Rect2:
	var most : float = max_scroll()
	if most <= 0.0:
		return Rect2()
	var height : float = maxf(listRect.size.y * listRect.size.y / (shownRows.size() * rowHeight), 4.0)
	return Rect2(barRect.position.x, listRect.position.y + (listRect.size.y - height) * scroll / most, barRect.size.x, height)

func point_at(index : int) -> void:
	if index != hovered:
		hovered = index
		pointed.emit(shownRows[index].get("value") if index != NOTHING else null)
		queue_redraw()

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not dragging:
		point_at(NOTHING)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging:
			drag_to(event.position)
		point_at(row_at(event.position))
	elif event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					search.release_focus()
					press(event.position)
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					scrollGoal = clampf(scrollGoal + rowHeight * wheelRows * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 0.0, max_scroll())
					set_process(true)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false
		accept_event()

func press(point : Vector2) -> void:
	if sortRect.has_point(point) and not sorters.is_empty():
		sortIndex = (sortIndex + 1) % sorters.size()
		refilter()
	elif barRect.grow_individual(1.0, 0.0, 1.0, 0.0).has_point(point) and max_scroll() > 0.0:
		var thumb : Rect2 = thumb_rect()
		dragging = true
		dragOffset = point.y - thumb.position.y if thumb.has_point(point) else thumb.size.y * 0.5
		drag_to(point)
	else:
		var index : int = row_at(point)
		if index != NOTHING:
			chosen.emit(shownRows[index].get("value"))

func drag_to(point : Vector2) -> void:
	var travel : float = listRect.size.y - thumb_rect().size.y
	if travel > 0.0:
		scroll = clampf((point.y - dragOffset - listRect.position.y) / travel, 0.0, 1.0) * max_scroll()
		scrollGoal = scroll
		queue_redraw()

func _process(delta : float) -> void:
	var moving : bool = not is_equal_approx(scroll, scrollGoal)
	if moving:
		scroll = lerpf(scroll, scrollGoal, 1.0 - exp(-scrollSpeed * delta))
		if absf(scroll - scrollGoal) < 0.05:
			scroll = scrollGoal
		point_at(row_at(get_local_mouse_position()))
	flashLeft = maxf(flashLeft - delta, 0.0)
	queue_redraw()
	if not moving and flashLeft <= 0.0:
		set_process(false)

func _draw() -> void:
	if not ui:
		return
	var font : Font = ui.font
	var whole : Rect2 = Rect2(Vector2.ZERO, size)
	var back : Color = Color(ui.panelColor, 1.0)
	draw_rect(whole, back)
	for i in shownRows.size():
		var area : Rect2 = row_rect(i)
		if area.end.y > listRect.position.y and area.position.y < listRect.end.y:
			draw_row(i, area, font)
	if shownRows.is_empty():
		draw_string(font, Vector2(listRect.position.x, listRect.position.y + 2.0 + font.get_ascent(ui.statSize)), "Nothing found", HORIZONTAL_ALIGNMENT_CENTER, listRect.size.x, ui.statSize, ui.dimColor)
	draw_rect(Rect2(0.0, 0.0, size.x, listRect.position.y), back)
	draw_rect(Rect2(0.0, listRect.end.y, size.x, size.y - listRect.end.y), back)
	if framed:
		outline(whole, ui.frameColor)
	if not title.is_empty():
		draw_string(font, inner.position + Vector2(0.0, font.get_ascent(ui.titleSize)), title, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, ui.titleSize, ui.textColor)
	if not sorters.is_empty():
		draw_rect(sortRect, ui.frameColor)
		draw_rect(sortRect.grow(-1.0), ui.slotColor)
		var label : String = sortNames[sortIndex] if sortIndex < sortNames.size() else ""
		draw_string(font, Vector2(sortRect.position.x, sortRect.position.y + roundf((sortRect.size.y + font.get_ascent(ui.statSize)) * 0.5)), label, HORIZONTAL_ALIGNMENT_CENTER, sortRect.size.x, ui.statSize, ui.textColor)
	if max_scroll() > 0.0:
		draw_rect(barRect, ui.slotColor)
		draw_rect(thumb_rect(), ui.hoverColor)

func draw_row(index : int, area : Rect2, font : Font) -> void:
	var row : Dictionary = shownRows[index]
	if index == hovered:
		draw_rect(area, Color(ui.hoverColor, 0.22))
	if row.get("marked", false):
		draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), markColor)
	var dim : bool = row.get("dim", false)
	var box : Rect2 = Rect2(area.position.x + 2.0, area.position.y + 1.0, rowHeight - 2.0, rowHeight - 2.0)
	var icon : Texture2D = row.get("icon")
	if row.get("cross", false):
		var cross : Rect2 = box.grow(-2.5)
		draw_line(cross.position, cross.end, ui.dimColor, 1.0)
		draw_line(Vector2(cross.end.x, cross.position.y), Vector2(cross.position.x, cross.end.y), ui.dimColor, 1.0)
	elif icon:
		var fit : float = 1.0
		while maxf(icon.get_width(), icon.get_height()) * fit > box.size.x:
			fit *= 0.5
		var drawn : Vector2 = icon.get_size() * fit
		var tint : Color = row.get("tint", Color.WHITE)
		draw_texture_rect(icon, Rect2((box.get_center() - drawn * 0.5).round(), drawn), false, Color(tint, tint.a * (0.4 if dim else 1.0)))
	var detail : String = row.get("detail", "")
	var detailWidth : float = font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x
	var baseline : float = area.position.y + roundf((rowHeight + font.get_ascent(ui.statSize)) * 0.5)
	var textX : float = box.end.x + 2.0
	draw_string(font, Vector2(textX, baseline), row.get("text", ""), HORIZONTAL_ALIGNMENT_LEFT, area.end.x - textX - detailWidth - 3.0, ui.statSize, ui.dimColor if dim else ui.textColor)
	if not detail.is_empty():
		draw_string(font, Vector2(area.end.x - detailWidth - 1.0, baseline), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, row.get("detailColor", ui.dimColor))
	if flashLeft > 0.0 and is_same(row.get("value"), flashValue):
		outline(area, Color(flashColor, flashLeft / flashTime))

func outline(area : Rect2, color : Color) -> void:
	draw_rect(Rect2(area.position, Vector2(area.size.x, 1.0)), color)
	draw_rect(Rect2(area.position.x, area.end.y - 1.0, area.size.x, 1.0), color)
	draw_rect(Rect2(area.position.x, area.position.y + 1.0, 1.0, area.size.y - 2.0), color)
	draw_rect(Rect2(area.end.x - 1.0, area.position.y + 1.0, 1.0, area.size.y - 2.0), color)
