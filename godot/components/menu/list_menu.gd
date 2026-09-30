extends MenuPanel
class_name ListMenu

# A scrollable list with a search box and a sort button, drawn with a
# MenuSkin (the logbook look when none is set). Rows are dictionaries:
#   value: handed back by chosen and pointed
#   text: the name shown. search: what the search box matches (text if left out)
#   icon, tint, detail, detailColor, dim, marked, cross (an X instead of an icon)
#   badge: a small tag after the name, like "NEW". badgeColor: its fill.
#   detailIcon: a small picture at the right end, before the detail text if any.
#   header: true for a section title row that can't be picked.
# Pinned rows stay on top and only show while the search box is empty.

signal chosen(value : Variant)
signal pointed(value : Variant)

const NOTHING : int = -1

#------------------------#
@export var ui : InventoryUI
@export var skin : MenuSkin:
	set(value):
		skin = value
		style_search()
		queue_redraw()
@export var title : String = "":
	set(value):
		title = value
		layout()
@export var framed : bool = true
# Shown when there are no rows.
@export var emptyText : String = "Nothing here"
@export var searchable : bool = true:
	set(value):
		searchable = value
		layout()
@export var rowHeight : int = 12
@export var headerHeight : int = 8
@export var sortWidth : int = 24
@export var scrollSpeed : float = 20.0
@export var wheelRows : float = 1.5
@export var flashColor : Color = Color(0.95, 0.38, 0.34)
@export var flashTime : float = 0.35

var rows : Array[Dictionary] = []
var pinned : Array[Dictionary] = []
var shownRows : Array[Dictionary] = []
var sortNames : PackedStringArray = PackedStringArray()
var sorters : Array[Callable] = []
var sortIndex : int = 0
var search : LineEdit
var view : Control
var scroll : float = 0.0
var scrollGoal : float = 0.0
var hovered : int = NOTHING
var hoverGlide : float = 0.0
var dragging : bool = false
var dragOffset : float = 0.0
var flashValue : Variant = null
var flashLeft : float = 0.0
var inner : Rect2
var sortRect : Rect2
var listRect : Rect2
var barRect : Rect2
var mouse : Vector2 = Vector2(-100.0, -100.0)
#------------------------#


func _ready() -> void:
	super()
	view = Control.new()
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.clip_contents = true
	view.draw.connect(draw_rows)
	add_child(view)
	search = LineEdit.new()
	search.placeholder_text = "Search"
	search.context_menu_enabled = false
	search.caret_blink = true
	search.add_theme_font_override("font", ui.font)
	search.add_theme_font_size_override("font_size", ui.statSize)
	search.add_theme_constant_override("minimum_character_width", 0)
	search.text_changed.connect(refilter.unbind(1))
	search.text_submitted.connect(search.release_focus.unbind(1))
	search.gui_input.connect(search_input)
	add_child(search)
	style_search()
	resized.connect(layout)
	set_process(false)
	layout()

func look() -> MenuSkin:
	return skin if skin else MenuSkin.default_skin()

func style_search() -> void:
	if not search:
		return
	var s : MenuSkin = look()
	search.add_theme_color_override("font_color", s.text)
	search.add_theme_color_override("font_placeholder_color", Color(s.dim, 0.8))
	search.add_theme_color_override("caret_color", s.text)
	search.add_theme_color_override("selection_color", Color(s.accent, 0.35))
	for state in ["normal", "focus", "read_only"]:
		var box : StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.0, 0.0, 0.0, 0.12) if s.light else Color(0.0, 0.0, 0.0, 0.25)
		box.border_color = s.accent if state == "focus" else s.line
		box.set_border_width_all(1)
		box.set_content_margin_all(1.0)
		box.content_margin_left = 3.0
		search.add_theme_stylebox_override(state, box)

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
	if search:
		search.text = ""

func flash(value : Variant) -> void:
	flashValue = value
	flashLeft = flashTime
	set_process(true)

func refilter() -> void:
	var query : String = search.text.strip_edges().to_lower() if search else ""
	var matched : Array[Dictionary] = []
	for row in rows:
		if query.is_empty() or (not row.get("header", false) and String(row.get("search", row.get("text", ""))).to_lower().contains(query)):
			matched.append(row)
	if not sorters.is_empty():
		matched.sort_custom(sorters[sortIndex])
	shownRows = []
	if query.is_empty():
		shownRows.append_array(pinned)
	shownRows.append_array(matched)
	clamp_scroll()
	hovered = NOTHING
	redraw()

func redraw() -> void:
	queue_redraw()
	if view:
		view.queue_redraw()

func layout() -> void:
	if not search:
		return
	inner = Rect2(Vector2.ZERO, size).grow(-2.0 if framed else 0.0)
	var top : float = inner.position.y + (ui.titleSize + 3.0 if not title.is_empty() else 0.0)
	var sorting : bool = not sorters.is_empty()
	search.visible = searchable
	if searchable or sorting:
		sortRect = Rect2(inner.end.x - sortWidth, top, sortWidth, headerHeight) if sorting else Rect2()
		search.position = Vector2(inner.position.x, top)
		search.size = Vector2(inner.size.x - (sortWidth + 1.0 if sorting else 0.0), headerHeight)
		if not searchable and sorting:
			sortRect = Rect2(inner.position.x, top, inner.size.x, headerHeight)
		top += headerHeight + 1.0
	listRect = Rect2(inner.position.x, top, inner.size.x - 3.0, inner.end.y - top)
	barRect = Rect2(inner.end.x - 2.0, listRect.position.y, 2.0, listRect.size.y)
	view.position = listRect.position
	view.size = listRect.size
	clamp_scroll()
	redraw()

func max_scroll() -> float:
	return maxf(shownRows.size() * rowHeight - listRect.size.y, 0.0)

func clamp_scroll() -> void:
	scrollGoal = clampf(scrollGoal, 0.0, max_scroll())
	scroll = clampf(scroll, 0.0, max_scroll())

# A row's rect in the list's own space.
func row_rect(index : int) -> Rect2:
	return Rect2(listRect.position.x, listRect.position.y + index * rowHeight - scroll, listRect.size.x, rowHeight)

func row_at(point : Vector2) -> int:
	if not listRect.has_point(point):
		return NOTHING
	var index : int = floori((point.y - listRect.position.y + scroll) / rowHeight)
	if index < 0 or index >= shownRows.size() or shownRows[index].get("header", false):
		return NOTHING
	return index

func thumb_rect() -> Rect2:
	var most : float = max_scroll()
	if most <= 0.0:
		return Rect2()
	var height : float = maxf(listRect.size.y * listRect.size.y / (shownRows.size() * rowHeight), 4.0)
	return Rect2(barRect.position.x, listRect.position.y + (listRect.size.y - height) * scroll / most, barRect.size.x, height)

func point_at(index : int) -> void:
	if index != hovered:
		hovered = index
		hoverGlide = 0.0
		set_process(true)
		pointed.emit(shownRows[index].get("value") if index != NOTHING else null)
		redraw()

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not dragging:
		mouse = Vector2(-100.0, -100.0)
		point_at(NOTHING)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		if dragging:
			drag_to(event.position)
		point_at(row_at(event.position))
		if sortRect.size.x > 0.0:
			queue_redraw()
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
		redraw()

func _process(delta : float) -> void:
	var moving : bool = not is_equal_approx(scroll, scrollGoal)
	if moving:
		scroll = lerpf(scroll, scrollGoal, 1.0 - exp(-scrollSpeed * delta))
		if absf(scroll - scrollGoal) < 0.05:
			scroll = scrollGoal
		point_at(row_at(get_local_mouse_position()))
	flashLeft = maxf(flashLeft - delta, 0.0)
	hoverGlide = minf(hoverGlide + delta * 8.0, 1.0)
	redraw()
	if not moving and flashLeft <= 0.0 and hoverGlide >= 1.0:
		set_process(false)

func _draw() -> void:
	if not ui:
		return
	var s : MenuSkin = look()
	var font : Font = ui.font
	if framed:
		UiKit.box(self, s.well, Rect2(Vector2.ZERO, size))
	if not title.is_empty():
		UiKit.label(self, font, inner.position + Vector2(1.0, font.get_ascent(ui.titleSize)), title, ui.titleSize, s.title)
	if not sorters.is_empty():
		var hover : bool = sortRect.has_point(mouse)
		UiKit.box(self, s.tabHover if hover else s.tab, sortRect)
		var label : String = sortNames[sortIndex] if sortIndex < sortNames.size() else ""
		UiKit.label(self, font, Vector2(sortRect.position.x, UiKit.baseline(font, sortRect, ui.statSize)), label, ui.statSize, s.buttonText if not s.light else Color(0.94, 0.97, 1.0), HORIZONTAL_ALIGNMENT_CENTER, sortRect.size.x)
	if shownRows.is_empty():
		UiKit.label(self, font, Vector2(listRect.position.x, listRect.position.y + 3.0 + font.get_ascent(ui.statSize)), emptyText, ui.statSize, s.dim, HORIZONTAL_ALIGNMENT_CENTER, listRect.size.x)
	if max_scroll() > 0.0:
		draw_rect(barRect, Color(s.line, 0.5))
		draw_rect(thumb_rect(), s.dim)

# The rows, drawn on a child clipped to the list area.
func draw_rows() -> void:
	var font : Font = ui.font
	var s : MenuSkin = look()
	for i in shownRows.size():
		var area : Rect2 = row_rect(i)
		area.position -= listRect.position
		if area.end.y > 0.0 and area.position.y < listRect.size.y:
			draw_row(i, area, font, s)

func draw_row(index : int, area : Rect2, font : Font, s : MenuSkin) -> void:
	var row : Dictionary = shownRows[index]
	var baseline : float = area.position.y + roundf((rowHeight + font.get_ascent(ui.statSize)) * 0.5)
	if row.get("header", false):
		UiKit.label(view, font, Vector2(area.position.x + 2.0, baseline), row.get("text", ""), ui.statSize, s.title)
		view.draw_rect(Rect2(area.position.x + 2.0, area.end.y - 2.0, area.size.x - 4.0, 1.0), s.line)
		return
	if index == hovered:
		view.draw_rect(area, s.hover)
		view.draw_rect(Rect2(area.position.x, area.position.y, roundf(2.0 * hoverGlide), area.size.y), Color(s.accent, 0.8))
	if row.get("marked", false):
		view.draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), row.get("markColor", s.marked))
	var dim : bool = row.get("dim", false)
	var nudge : float = roundf(hoverGlide * 1.0) if index == hovered else 0.0
	var box : Rect2 = Rect2(area.position.x + 2.0 + nudge, area.position.y + 1.0, rowHeight - 2.0, rowHeight - 2.0)
	var icon : Texture2D = row.get("icon")
	if row.get("cross", false):
		var cross : Rect2 = box.grow(-2.5)
		view.draw_line(cross.position, cross.end, s.dim, 1.0)
		view.draw_line(Vector2(cross.end.x, cross.position.y), Vector2(cross.position.x, cross.end.y), s.dim, 1.0)
	elif icon:
		var fit : float = 1.0
		while maxf(icon.get_width(), icon.get_height()) * fit > box.size.x:
			fit *= 0.5
		var drawn : Vector2 = icon.get_size() * fit
		var tint : Color = row.get("tint", Color.WHITE)
		view.draw_texture_rect(icon, Rect2((box.get_center() - drawn * 0.5).round(), drawn), false, Color(tint, tint.a * (0.4 if dim else 1.0)))
	var detail : String = row.get("detail", "")
	var detailIcon : Texture2D = row.get("detailIcon")
	var iconSide : float = minf(8.0, maxf(detailIcon.get_width(), detailIcon.get_height())) if detailIcon else 0.0
	var detailWidth : float = font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + (iconSide + 1.0 if detailIcon else 0.0)
	var textX : float = box.end.x + 2.0
	var nameColor : Color = row.get("textColor", s.dim if dim else s.text)
	var room : float = area.end.x - textX - detailWidth - 3.0
	var badge : String = row.get("badge", "")
	var badgeWidth : float = UiKit.text_width(font, badge, ui.statSize) + 5.0 if not badge.is_empty() else 0.0
	var text : String = row.get("text", "")
	UiKit.label(view, font, Vector2(textX, baseline), text, ui.statSize, s.readable(nameColor) if row.has("textColor") else nameColor, HORIZONTAL_ALIGNMENT_LEFT, room - badgeWidth)
	if not badge.is_empty():
		var at : float = minf(textX + UiKit.text_width(font, text, ui.statSize) + 2.0, textX + room - badgeWidth + 2.0)
		UiKit.pill(view, font, Vector2(at + badgeWidth - 2.0, area.position.y + floorf((rowHeight - ui.statSize - 3.0) * 0.5)), badge, ui.statSize, row.get("badgeColor", UiKit.NEW_COLOR), Color(0.12, 0.08, 0.04))
	if detailIcon:
		var shrink : float = iconSide / maxf(detailIcon.get_width(), detailIcon.get_height())
		var drawn : Vector2 = (detailIcon.get_size() * shrink).round()
		view.draw_texture_rect(detailIcon, Rect2(Vector2(area.end.x - detailWidth - 1.0, floorf(area.get_center().y - drawn.y * 0.5)), drawn), false, Color(1.0, 1.0, 1.0, 0.9))
	if not detail.is_empty():
		view.draw_string(font, Vector2(area.end.x - font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x - 1.0, baseline), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, s.readable(row.get("detailColor", s.dim)))
	if flashLeft > 0.0 and is_same(row.get("value"), flashValue):
		UiKit.outline(view, area, Color(flashColor, flashLeft / flashTime))

func outline(area : Rect2, color : Color) -> void:
	UiKit.outline(self, area, color)
