extends MenuPanel
class_name CalendarUI

# A paper wall calendar (C): the year's four seasons, a week each, one row per
# season. Every day shows what's on: festivals as colored bands, tournament
# results on Saturdays, the market on Sundays, and today circled in red. The
# picked day's page on the right says what's happening and how long until
# the next festival, with the festival's fish and stall.

enum Zone { NONE, DAY, EVENT }
const STAR : Texture2D = preload("res://ui/hub/icons/star.png")

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin
@export var maxWidth : float = 184.0
@export var cellSize : Vector2 = Vector2(13.0, 12.0)
@export var labelWidth : float = 22.0
@export var ringColor : Color = Color(0.75, 0.77, 0.82)
@export var todayColor : Color = Color(0.85, 0.2, 0.18)

var panel : Rect2
var gridRect : Rect2
var pageRect : Rect2
var dayRects : Array[Rect2] = []
var eventRects : Array[Rect2] = []
var shownEvents : Array[GameEvent] = []
var picked : int = 1
var zone : Zone = Zone.NONE
var index : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var today : int = 1
var yearStart : int = 1
var time : float = 0.0
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/paper.tres") as MenuSkin
	ui.laid_out.connect(fit)
	ui.opened.connect(close)
	set_process(false)
	fit()

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	var width : float = minf(ui.size.x - 6.0, maxWidth)
	var top : float = MenuHub.top_of(get_tree(), 3.0) + 2.0 if is_inside_tree() else 5.0
	panel = Rect2(floorf((ui.size.x - width) * 0.5), top, width, ui.size.y - top - 2.0)
	var inner : Rect2 = panel.grow(-4.0)
	gridRect = Rect2(inner.position + Vector2(0.0, 8.0), Vector2(labelWidth + cellSize.x * Calendar.SEASON_DAYS, cellSize.y * 4.0 + 8.0))
	pageRect = Rect2(gridRect.end.x + 3.0, inner.position.y, inner.end.x - gridRect.end.x - 3.0, inner.size.y)
	dayRects.clear()
	for season in 4:
		for day in Calendar.SEASON_DAYS:
			dayRects.append(Rect2(gridRect.position.x + labelWidth + day * cellSize.x, gridRect.position.y + 8.0 + season * cellSize.y, cellSize.x - 1.0, cellSize.y - 1.0))
	queue_redraw()

func hub_open() -> void:
	if not shown:
		open_calendar()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

# A festival running today.
func hub_news() -> bool:
	return not Calendar.active(get_tree()).is_empty()

func open_calendar() -> void:
	MenuHub.menu_opened(get_tree(), self)
	player.frozen = true
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	today = cycle.day if cycle else 1
	yearStart = today - Calendar.day_of_year(today) + 1
	picked = today
	lay_events()
	open_menu()
	set_process(true)

func close() -> void:
	if not shown:
		return
	close_menu()
	set_process(false)
	player.frozen = false

func lay_events() -> void:
	shownEvents = Calendar.events_on(picked)
	eventRects.clear()
	var y : float = pageRect.position.y + 20.0
	for event in shownEvents:
		eventRects.append(Rect2(pageRect.position.x + 2.0, y, pageRect.size.x - 4.0, 8.0))
		y += 9.0

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(2.0).has_point(point)

func _unhandled_input(event : InputEvent) -> void:
	if shown and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func zone_at(point : Vector2) -> Vector2i:
	for i in dayRects.size():
		if dayRects[i].has_point(point):
			return Vector2i(Zone.DAY, i)
	for i in eventRects.size():
		if eventRects[i].has_point(point):
			return Vector2i(Zone.EVENT, i)
	return Vector2i(Zone.NONE, -1)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		var found : Vector2i = zone_at(mouse)
		zone = found.x as Zone
		index = found.y
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var found : Vector2i = zone_at(event.position)
			if found.x == Zone.DAY:
				picked = yearStart + found.y
				lay_events()
			queue_redraw()
	accept_event()

func _process(delta : float) -> void:
	time += delta
	queue_redraw()
	set_process(shown)

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	for i in 6:
		var x : float = panel.position.x + 12.0 + i * (panel.size.x - 24.0) / 5.0
		draw_rect(Rect2(x, panel.position.y - 3.0, 2.0, 6.0), ringColor)
		draw_rect(Rect2(x, panel.position.y - 3.0, 1.0, 6.0), ringColor.lightened(0.3))
	var title : String = "Year %d" % Calendar.year(today)
	UiKit.label(self, font, Vector2(gridRect.position.x, panel.position.y + 4.0 + font.get_ascent(ui.titleSize)), title, ui.titleSize, skin.title)
	var weekdays : PackedStringArray = ["M", "T", "W", "T", "F", "S", "S"]
	for day in Calendar.SEASON_DAYS:
		UiKit.label(self, font, Vector2(gridRect.position.x + labelWidth + day * cellSize.x, gridRect.position.y + font.get_ascent(ui.statSize) + 2.0), weekdays[day], ui.statSize, todayColor if day >= 5 else skin.dim, HORIZONTAL_ALIGNMENT_CENTER, cellSize.x - 1.0)
	for season in 4:
		var y : float = gridRect.position.y + 8.0 + season * cellSize.y
		UiKit.label(self, font, Vector2(gridRect.position.x, y + roundf((cellSize.y + font.get_ascent(ui.statSize)) * 0.5) - 1.0), Calendar.SEASONS[season].left(3), ui.statSize, Calendar.SEASON_COLORS[season].darkened(0.45))
	for i in dayRects.size():
		draw_day(font, i)
	draw_page(font)
	draw_tip()

func draw_day(font : Font, i : int) -> void:
	var area : Rect2 = dayRects[i]
	var day : int = yearStart + i
	var dayOfSeason : int = i % Calendar.SEASON_DAYS + 1
	var season : int = floori(i / float(Calendar.SEASON_DAYS))
	draw_rect(area, Color(Calendar.SEASON_COLORS[season], 0.18))
	if day == picked:
		draw_rect(area, Color(skin.accent, 0.22))
	elif zone == Zone.DAY and index == i:
		draw_rect(area, skin.hover)
	var events : Array[GameEvent] = Calendar.events_on(day)
	for e in events.size():
		draw_rect(Rect2(area.position.x, area.end.y - 2.0 - e * 2.0, area.size.x, 2.0), events[e].color)
	UiKit.label(self, font, Vector2(area.position.x + 1.0, area.position.y + 1.0 + font.get_ascent(ui.statSize)), "%d" % dayOfSeason, ui.statSize, skin.text if day >= today else skin.dim)
	var weekday : int = posmod(day - 1, 7)
	if weekday == 5:
		draw_texture(STAR, Vector2(area.end.x - 6.0, area.position.y + 1.0))
	elif weekday == 6:
		draw_rect(Rect2(area.end.x - 4.0, area.position.y + 2.0, 2.0, 2.0), Color(0.3, 0.55, 0.25))
	if day == today:
		var ring : Rect2 = area.grow(0.5 + 0.5 * sin(time * 4.0))
		UiKit.outline(self, ring, todayColor)

func draw_page(font : Font) -> void:
	UiKit.box(self, skin.well, pageRect)
	var inner : Rect2 = pageRect.grow(-2.0)
	var y : float = inner.position.y
	var weekday : String = DayNightCycle.WEEKDAYS[posmod(picked - 1, 7)]
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), "%s %d" % [Calendar.season_name(picked), Calendar.day_of_season(picked)], ui.statSize, skin.title)
	y += ui.statSize + 1.0
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), weekday + (" (today)" if picked == today else ""), ui.statSize, skin.dim)
	y = pageRect.position.y + 20.0
	for i in shownEvents.size():
		var event : GameEvent = shownEvents[i]
		var area : Rect2 = eventRects[i]
		if zone == Zone.EVENT and index == i:
			draw_rect(area, skin.hover)
		draw_rect(Rect2(area.position.x, area.position.y + 1.0, 2.0, area.size.y - 2.0), event.color)
		UiKit.label(self, font, Vector2(area.position.x + 4.0, UiKit.baseline(font, area, ui.statSize)), event.displayName, ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 4.0)
		y = area.end.y + 1.0
	var lines : Array = []
	match posmod(picked - 1, 7):
		5:
			lines.append(["Tournament results", "18:00"])
		6:
			lines.append(["Market day", "Square"])
	if shownEvents.is_empty() and lines.is_empty():
		lines.append(["A quiet day", ""])
	for line in lines:
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), line[0], ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
		y += ui.statSize + 1.0
		if not String(line[1]).is_empty():
			UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), line[1], ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
			y += ui.statSize + 1.0
	var next : GameEvent = null
	var soonest : int = 1000
	for event in GameEvent.all():
		var wait : int = Calendar.days_until(event, today)
		if wait > 0 and wait < soonest:
			soonest = wait
			next = event
	if next:
		var at : float = inner.end.y - ui.statSize * 2.0 - 3.0
		draw_rect(Rect2(inner.position.x, at - 2.0, inner.size.x, 1.0), skin.line)
		UiKit.label(self, font, Vector2(inner.position.x, at + font.get_ascent(ui.statSize)), "Next festival", ui.statSize, skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x, at + ui.statSize + 2.0 + font.get_ascent(ui.statSize)), next.displayName, ui.statSize, skin.readable(next.color), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 14.0)
		UiKit.label(self, font, Vector2(inner.position.x, at + ui.statSize + 2.0 + font.get_ascent(ui.statSize)), "%dd" % soonest, ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)

func draw_tip() -> void:
	var title : String = ""
	var color : Color = ui.textColor
	var lines : PackedStringArray = PackedStringArray()
	if zone == Zone.DAY:
		var day : int = yearStart + index
		title = "%s %d" % [Calendar.season_name(day), Calendar.day_of_season(day)]
		for event in Calendar.events_on(day):
			lines.append_array([event.displayName, event.hours_text()])
		if lines.is_empty():
			lines.append_array(["Nothing special", ""])
	elif zone == Zone.EVENT:
		var event : GameEvent = shownEvents[index]
		title = event.displayName
		color = event.color
		for line in ui.wrap_lines(event.description, 80.0, ui.statSize):
			lines.append_array([line, ""])
		lines.append_array(["When", event.dates_text(), "Hours", event.hours_text()])
		if event.page:
			lines.append_array(["Festival fish", "%d" % event.page.fish.size()])
		if not event.host.is_empty():
			lines.append_array(["Stall", Cast.name_of(event.host)])
	if title.is_empty():
		return
	ui.paint_tip(self, mouse, title, color, lines, ui.tip_size(title, lines))
