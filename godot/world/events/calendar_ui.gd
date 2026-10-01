extends MenuPanel
class_name CalendarUI

# A paper wall calendar (C), one season at a time: two weeks of days under
# the weekday names, each day marked with what's on it (festivals as colored
# bands, happenings as dots, birthdays as hearts, the Saturday tournament and
# Sunday market as small marks) and today ringed in red. The arrows turn to
# the other seasons. The page on the right shows the picked day: everything
# on it with its hours, and what the hovered or first one is about. Below the
# days, what's coming up next.

enum Zone { NONE, DAY, ENTRY, PREVIOUS, NEXT, UPCOMING }
const STAR : Texture2D = preload("res://ui/hub/icons/star.png")
const WEEKDAYS : PackedStringArray = ["M", "T", "W", "T", "F", "S", "S"]

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin
@export var maxWidth : float = 184.0
@export var cellSize : Vector2 = Vector2(14.0, 15.0)
@export var ringColor : Color = Color(0.75, 0.77, 0.82)
@export var todayColor : Color = Color(0.85, 0.2, 0.18)

var panel : Rect2
var gridRect : Rect2
var pageRect : Rect2
var upcomingRect : Rect2
var previousRect : Rect2
var nextRect : Rect2
var dayRects : Array[Rect2] = []
var entryRects : Array[Rect2] = []
var upcomingRects : Array[Rect2] = []
var entries : Array[Dictionary] = []
var coming : Array = []
# Each shown day's entries, worked out when the season is turned to.
var seasonEntries : Array = []
var season : int = 0
var picked : int = 1
var zone : Zone = Zone.NONE
var index : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var today : int = 1
var seasonStart : int = 1
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
	gridRect = Rect2(inner.position + Vector2(0.0, 10.0), Vector2(cellSize.x * 7.0, cellSize.y * 2.0 + 7.0))
	previousRect = Rect2(inner.position.x, inner.position.y, 8.0, 8.0)
	nextRect = Rect2(gridRect.end.x - 8.0, inner.position.y, 8.0, 8.0)
	upcomingRect = Rect2(inner.position.x, gridRect.end.y + 3.0, gridRect.size.x, inner.end.y - gridRect.end.y - 3.0)
	pageRect = Rect2(gridRect.end.x + 3.0, inner.position.y, inner.end.x - gridRect.end.x - 3.0, inner.size.y)
	dayRects.clear()
	for i in Calendar.SEASON_DAYS:
		@warning_ignore("integer_division")
		dayRects.append(Rect2(gridRect.position.x + (i % 7) * cellSize.x, gridRect.position.y + 7.0 + (i / 7) * cellSize.y, cellSize.x - 1.0, cellSize.y - 1.0))
	upcomingRects.clear()
	for i in floori((upcomingRect.size.y - 10.0) / 8.0):
		upcomingRects.append(Rect2(upcomingRect.position.x + 2.0, upcomingRect.position.y + 9.0 + i * 8.0, upcomingRect.size.x - 4.0, 7.0))
	lay_entries()
	queue_redraw()

func hub_open() -> void:
	if not shown:
		open_calendar()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

# Something running today.
func hub_news() -> bool:
	return not Calendar.active(get_tree()).is_empty()

func open_calendar() -> void:
	Features.introduce(player, "calendar")
	MenuHub.menu_opened(get_tree(), self)
	player.frozen = true
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	today = cycle.day if cycle else 1
	picked = today
	turn_to(Calendar.season(today), false)
	coming = Calendar.upcoming(today + 1, upcomingRects.size())
	open_menu()
	set_process(true)

func close() -> void:
	if not shown:
		return
	close_menu()
	set_process(false)
	player.frozen = false

# Shows a season of this year (0-3), or of the next one past winter.
func turn_to(which : int, pick_first : bool = true) -> void:
	var yearStart : int = today - Calendar.day_of_year(today) + 1
	season = which
	seasonStart = yearStart + which * Calendar.SEASON_DAYS
	seasonEntries.clear()
	for i in Calendar.SEASON_DAYS:
		seasonEntries.append(Calendar.entries_on(seasonStart + i))
	if pick_first:
		picked = today if Calendar.season(today) == season and seasonStart <= today and today < seasonStart + Calendar.SEASON_DAYS else seasonStart
	lay_entries()

func lay_entries() -> void:
	entries = Calendar.entries_on(picked)
	entryRects.clear()
	var y : float = pageRect.position.y + 17.0
	for entry in entries:
		entryRects.append(Rect2(pageRect.position.x + 2.0, y, pageRect.size.x - 4.0, 8.0))
		y += 9.0

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(2.0).has_point(point)

func _unhandled_input(event : InputEvent) -> void:
	if not shown:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		turn_to(posmod(season + (1 if event.is_action_pressed("ui_right") else -1), 4))
		queue_redraw()

func zone_at(point : Vector2) -> Vector2i:
	if previousRect.grow(1.0).has_point(point):
		return Vector2i(Zone.PREVIOUS, 0)
	if nextRect.grow(1.0).has_point(point):
		return Vector2i(Zone.NEXT, 0)
	for i in dayRects.size():
		if dayRects[i].has_point(point):
			return Vector2i(Zone.DAY, i)
	for i in entryRects.size():
		if entryRects[i].has_point(point):
			return Vector2i(Zone.ENTRY, i)
	for i in mini(upcomingRects.size(), coming.size()):
		if upcomingRects[i].has_point(point):
			return Vector2i(Zone.UPCOMING, i)
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
			match found.x:
				Zone.DAY:
					picked = seasonStart + found.y
					lay_entries()
				Zone.PREVIOUS:
					turn_to(posmod(season - 1, 4))
				Zone.NEXT:
					turn_to(posmod(season + 1, 4))
				Zone.UPCOMING:
					var day : int = today + 1 + int(coming[found.y][1])
					turn_to(Calendar.season(day))
					picked = seasonStart + Calendar.day_of_season(day) - 1
					lay_entries()
			queue_redraw()
	accept_event()

func _process(delta : float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	for i in 6:
		var x : float = panel.position.x + 12.0 + i * (panel.size.x - 24.0) / 5.0
		draw_rect(Rect2(x, panel.position.y - 3.0, 2.0, 6.0), ringColor)
		draw_rect(Rect2(x, panel.position.y - 3.0, 1.0, 6.0), ringColor.lightened(0.3))
	var color : Color = Calendar.SEASON_COLORS[season]
	var title : String = "%s, Year %d" % [Calendar.SEASONS[season], Calendar.year(seasonStart)]
	UiKit.label(self, font, Vector2(gridRect.position.x, previousRect.position.y + font.get_ascent(ui.titleSize)), title, ui.titleSize, skin.readable(color.darkened(0.35)), HORIZONTAL_ALIGNMENT_CENTER, gridRect.size.x)
	draw_arrow(previousRect, true, zone == Zone.PREVIOUS)
	draw_arrow(nextRect, false, zone == Zone.NEXT)
	for day in 7:
		UiKit.label(self, font, Vector2(gridRect.position.x + day * cellSize.x, gridRect.position.y + font.get_ascent(ui.statSize)), WEEKDAYS[day], ui.statSize, todayColor if day >= 5 else skin.dim, HORIZONTAL_ALIGNMENT_CENTER, cellSize.x - 1.0)
	for i in dayRects.size():
		draw_day(font, i)
	draw_upcoming(font)
	draw_page(font)
	draw_tip()

func draw_arrow(area : Rect2, left : bool, hover : bool) -> void:
	var center : Vector2 = area.get_center()
	var tint : Color = skin.title if hover else skin.dim
	var points : PackedVector2Array = PackedVector2Array([center + Vector2(1.5, -3.0), center + Vector2(1.5, 3.0), center + Vector2(-1.5, 0.0)]) if left else PackedVector2Array([center + Vector2(-1.5, -3.0), center + Vector2(-1.5, 3.0), center + Vector2(1.5, 0.0)])
	draw_colored_polygon(points, tint)

func draw_day(font : Font, i : int) -> void:
	var area : Rect2 = dayRects[i]
	var day : int = seasonStart + i
	draw_rect(area, Color(Calendar.SEASON_COLORS[season], 0.2 if day >= today else 0.08))
	if day == picked:
		draw_rect(area, Color(skin.accent, 0.25))
	elif zone == Zone.DAY and index == i:
		draw_rect(area, skin.hover)
	UiKit.label(self, font, Vector2(area.position.x + 1.0, area.position.y + 1.0 + font.get_ascent(ui.statSize)), "%d" % (i + 1), ui.statSize, skin.text if day >= today else skin.dim)
	var list : Array = seasonEntries[i] if i < seasonEntries.size() else []
	var dotX : float = area.position.x + 1.0
	for entry in list:
		match entry.kind:
			"festival":
				draw_rect(Rect2(area.position.x, area.end.y - 2.0, area.size.x, 2.0), entry.color)
			"happening":
				draw_rect(Rect2(dotX, area.end.y - 5.0, 2.0, 2.0), entry.color)
				dotX += 3.0
			"birthday":
				var at : Vector2 = Vector2(area.end.x - 5.0, area.position.y + 1.0)
				for cell in DialogueUI.HEART_SHAPE:
					draw_rect(Rect2(at + Vector2(cell), Vector2.ONE), Friendship.HEART_COLOR)
			"weekly":
				if Calendar.weekday(day) == 5:
					draw_texture(STAR, Vector2(area.end.x - 6.0, area.end.y - 7.0), Color(1.0, 1.0, 1.0, 0.8))
				elif entry.name == "Sunday market":
					draw_rect(Rect2(area.end.x - 4.0, area.end.y - 5.0, 2.0, 2.0), Color(0.3, 0.55, 0.25))
	if day == today:
		UiKit.outline(self, area.grow(0.5 + 0.5 * sin(time * 4.0)), todayColor)

func draw_upcoming(font : Font) -> void:
	UiKit.box(self, skin.well, upcomingRect)
	UiKit.label(self, font, Vector2(upcomingRect.position.x + 2.0, upcomingRect.position.y + 1.0 + font.get_ascent(ui.statSize)), "Coming up", ui.statSize, skin.title)
	for i in mini(upcomingRects.size(), coming.size()):
		var area : Rect2 = upcomingRects[i]
		if area.end.y > upcomingRect.end.y:
			break
		var event : GameEvent = coming[i][0]
		if zone == Zone.UPCOMING and index == i:
			draw_rect(area, skin.hover)
		draw_rect(Rect2(area.position.x, area.position.y + 2.0, 2.0, 3.0), event.color)
		UiKit.label(self, font, Vector2(area.position.x + 4.0, UiKit.baseline(font, area, ui.statSize)), event.displayName, ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 22.0)
		var wait : int = int(coming[i][1]) + 1
		UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, area, ui.statSize)), "tmrw" if wait == 1 else "%dd" % wait, ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x)

func draw_page(font : Font) -> void:
	UiKit.box(self, skin.well, pageRect)
	var inner : Rect2 = pageRect.grow(-2.0)
	var y : float = inner.position.y
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), "%s %d" % [Calendar.season_name(picked), Calendar.day_of_season(picked)], ui.statSize, skin.title)
	y += ui.statSize + 1.0
	var weekday : String = DayNightCycle.WEEKDAYS[Calendar.weekday(picked)]
	var when : String = " (today)" if picked == today else (" (in %dd)" % (picked - today) if picked > today else "")
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), weekday + when, ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	for i in entries.size():
		var entry : Dictionary = entries[i]
		var area : Rect2 = entryRects[i]
		if area.end.y > inner.end.y - 16.0:
			break
		if zone == Zone.ENTRY and index == i:
			draw_rect(area, skin.hover)
		var icon : Texture2D = entry.icon
		if entry.kind == "birthday":
			icon = Cast.portrait(entry.who)
		if icon:
			draw_texture_rect(icon, Rect2(area.position + Vector2(0.0, 0.0), Vector2(8.0, 8.0)), false)
		else:
			draw_rect(Rect2(area.position.x + 2.0, area.position.y + 2.0, 4.0, 4.0), entry.color)
		UiKit.label(self, font, Vector2(area.position.x + 10.0, UiKit.baseline(font, area, ui.statSize)), entry.name, ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 10.0)
	if entries.is_empty():
		UiKit.label(self, font, Vector2(inner.position.x, pageRect.position.y + 17.0 + font.get_ascent(ui.statSize)), "A quiet day", ui.statSize, skin.dim)
		return
	# What the hovered (or first) entry is about, at the bottom of the page.
	var shown_entry : Dictionary = entries[index] if zone == Zone.ENTRY and index < entries.size() else entries[0]
	var lines : PackedStringArray = ui.wrap_lines(shown_entry.text, inner.size.x, ui.statSize)
	var bottom : float = inner.end.y - (ui.statSize + 1.0) * mini(lines.size(), 3) - ui.statSize - 2.0
	draw_rect(Rect2(inner.position.x, bottom - 2.0, inner.size.x, 1.0), skin.line)
	UiKit.label(self, font, Vector2(inner.position.x, bottom + font.get_ascent(ui.statSize)), shown_entry.hours, ui.statSize, skin.readable(shown_entry.color.darkened(0.3)), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	bottom += ui.statSize + 1.0
	for line in lines.slice(0, 3):
		UiKit.label(self, font, Vector2(inner.position.x, bottom + font.get_ascent(ui.statSize)), line, ui.statSize, skin.dim)
		bottom += ui.statSize + 1.0

func draw_tip() -> void:
	if zone != Zone.DAY or index < 0 or index >= seasonEntries.size():
		return
	var day : int = seasonStart + index
	var title : String = "%s %d" % [Calendar.SEASONS[season], index + 1]
	var lines : PackedStringArray = PackedStringArray()
	for entry in seasonEntries[index]:
		lines.append_array([entry.name, entry.hours])
	if lines.is_empty():
		lines.append_array(["Nothing special", ""])
	if day == today:
		title += " (today)"
	ui.paint_tip(self, mouse, title, ui.textColor, lines, ui.tip_size(title, lines))
