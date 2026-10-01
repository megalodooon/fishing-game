extends MenuPanel
class_name PauseMenu

# Esc opens it: the game pauses, a column on the right resumes, opens the
# menus (the same as Tab), the settings, saves, or goes back to the title
# screen (saving first), and a card on the left sums up the day: the date and
# season, the weather, the Angler Level, the council's perk, festivals and
# orders. Closing the window saves too.
# Keys: up/down or the mouse to pick, Enter or click to go, Esc to go back.

enum Page { MAIN, SETTINGS, LEAVE }

const TITLE_SCENE : String = "res://ui/title/title_screen.tscn"

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var tacklebox : TackleboxUI
@export var journal : JournalUI
@export var map : WorldMapUI
@export var questLog : QuestLog
@export var pets : PetsUI
@export var profile : ProfileUI
@export var weather : Weather
@export var cycle : DayNightCycle
@export var statusHud : StatusHud
# Any of these being open means Esc is theirs, not the pause menu's.
@export var menus : Array[Control] = []
# One per main entry: bag, tacklebox, journal, profile, chart, quests, pets,
# settings, save, leave.
@export var icons : Array[Texture2D] = []
@export var coinIcon : Texture2D

@export_group("Look")
@export var columnWidth : float = 74.0
@export var rowHeight : float = 8.0
@export var margin : float = 5.0
@export var dimColor : Color = Color(0.02, 0.04, 0.08, 0.6)
@export var headerColor : Color = Color(0.09, 0.14, 0.22, 1.0)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)
@export var skin : MenuSkin

var page : int = Page.MAIN
var selected : int = 0
var hovered : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var column : Rect2
var card : Rect2
var rowRects : Array[Rect2] = []
var slideIn : Array[float] = []
# Above 0 after a save worked, below 0 after it failed, fading to 0.
var saveFlash : float = 0.0
#------------------------#


func _ready() -> void:
	super()
	process_mode = PROCESS_MODE_ALWAYS
	slide = Vector2(12.0, 0.0)
	if not skin:
		skin = MenuSkin.default_skin()
	set_anchors_preset(PRESET_TOP_LEFT)
	ui.laid_out.connect(fit)
	Settings.apply_global()
	apply_settings()
	fit()

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	column = Rect2(size.x - columnWidth - margin, margin, columnWidth, size.y - margin * 2.0)
	card = Rect2(margin, margin, maxf(column.position.x - margin * 3.0, 40.0), size.y - margin * 2.0)
	queue_redraw()

func _has_point(_point : Vector2) -> bool:
	return shown

func entries() -> Array[Array]:
	match page:
		Page.SETTINGS:
			var list : Array[Array] = [
				["UI size", "%d%%" % roundi(float(Settings.get_value("uiScale")) * 100.0), &"uiScale"],
				["Hotbar", "Top" if Settings.get_value("hotbarOnTop") else "Bottom", &"hotbarOnTop"],
				["Held items", "%d%%" % roundi(float(Settings.get_value("heldItemScale")) * 100.0), &"heldItemScale"],
				["Volume", "%d%%" % roundi(float(Settings.get_value("volume")) * 100.0), &"volume"],
				["Weather fx", on_off(Settings.get_value("weatherEffects")), &"weatherEffects"],
				["Quest HUD", on_off(Settings.get_value("questTracker")), &"questTracker"],
			]
			if not OS.has_feature("web"):
				list.append(["Fullscreen", on_off(Settings.get_value("fullscreen")), &"fullscreen"])
			list.append(["Back", "", &"back"])
			return list
		Page.LEAVE:
			return [["Leave", "", &"leave"], ["Stay", "", &"back"]]
	return [["Resume", "Esc", &"resume"], ["All menus", "Tab", &"menus"], ["Sea chart", "M", &"map"], ["Settings", "", &"settings"], ["Save game", "", &"save"], ["Main menu", "", &"title"]]

static func on_off(value : Variant) -> String:
	return "On" if value else "Off"

func other_menu_open() -> bool:
	if ui.open:
		return true
	for menu in menus:
		if menu is MenuPanel and (menu as MenuPanel).shown:
			return true
	return false

func can_pause() -> bool:
	return not player.asleep and not player.charting and not (player.minigameScreen and player.minigameScreen.shown)

func _unhandled_input(event : InputEvent) -> void:
	if shown:
		return
	if event.is_action_pressed("ui_cancel") and can_pause():
		if ui.open:
			ui.close()
		elif other_menu_open():
			return
		else:
			open_pause()
		get_viewport().set_input_as_handled()

func _input(event : InputEvent) -> void:
	if not shown:
		return
	var count : int = entries().size()
	if event.is_action_pressed("ui_cancel"):
		back()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down"):
		selected = posmod(selected + 1, count)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up"):
		selected = posmod(selected - 1, count)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate(selected, 1)
	elif page == Page.SETTINGS and (event.is_action_pressed("ui_left") or event.is_action_pressed("left")):
		activate(selected, -1)
	elif page == Page.SETTINGS and (event.is_action_pressed("ui_right") or event.is_action_pressed("right")):
		activate(selected, 1)
	elif event is InputEventMouseMotion:
		mouse = (make_input_local(event) as InputEventMouse).position
		hovered = -1
		for i in rowRects.size():
			if rowRects[i].has_point(mouse):
				hovered = i
				selected = i
		queue_redraw()
		return
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and hovered >= 0:
			activate(hovered, 1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			back()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if page == Page.SETTINGS and hovered >= 0:
				activate(hovered, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()
		queue_redraw()

func open_pause() -> void:
	page = Page.MAIN
	selected = 0
	get_tree().paused = true
	open_menu()
	queue_redraw()

func resume() -> void:
	close_menu()
	get_tree().paused = false

func close() -> void:
	if shown:
		resume()

func back() -> void:
	if page == Page.MAIN:
		resume()
	else:
		selected = 3 if page == Page.SETTINGS else 5
		page = Page.MAIN

func go_to(which : int) -> void:
	page = which
	selected = 0
	hovered = -1

func activate(index : int, direction : int) -> void:
	var list : Array[Array] = entries()
	if index < 0 or index >= list.size():
		return
	var key : StringName = list[index][2]
	match key:
		&"resume":
			resume()
		&"menus":
			resume()
			var hub : MenuHub = MenuHub.find(get_tree())
			if hub:
				hub.switch_to(hub.last if hub.last >= 0 else hub.firstTab)
		&"bag":
			resume()
			ui.show_backpack()
		&"tacklebox":
			resume()
			tacklebox.toggle()
		&"journal":
			resume()
			journal.toggle()
		&"map":
			resume()
			map.try_open()
		&"quests":
			resume()
			questLog.open_log(player)
		&"pets":
			resume()
			pets.open_own(player)
		&"profile":
			resume()
			profile.open_profile()
		&"save":
			saveFlash = 1.5 if SaveGame.save_game(get_tree()) else -1.5
		&"settings":
			go_to(Page.SETTINGS)
		&"title":
			go_to(Page.LEAVE)
			selected = 1
		&"leave":
			SaveGame.save_game(get_tree())
			get_tree().paused = false
			# At the end of the frame: changing scenes frees this menu, and the
			# click that got here still has to finish.
			get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
		&"back":
			back()
		&"uiScale":
			step("uiScale", 0.25, 0.75, 1.25, direction)
			apply_settings()
		&"heldItemScale":
			step("heldItemScale", 0.25, 0.5, 1.5, direction)
			apply_settings()
		&"volume":
			step("volume", 0.1, 0.0, 1.0, direction)
			Settings.apply_global()
		_:
			Settings.set_value(key, not Settings.get_value(key))
			apply_settings()
			Settings.apply_global()

# Moves a number setting one step, wrapping around at either end.
func step(key : String, amount : float, low : float, high : float, direction : int) -> void:
	var value : float = snappedf(float(Settings.get_value(key)) + amount * direction, amount)
	if value > high + 0.001:
		value = low
	elif value < low - 0.001:
		value = high
	Settings.set_value(key, value)

func apply_settings() -> void:
	ui.uiScale = float(Settings.get_value("uiScale"))
	ui.hotbarOnTop = bool(Settings.get_value("hotbarOnTop"))
	player.heldItemScale = float(Settings.get_value("heldItemScale"))
	if weather:
		weather.showEffects = bool(Settings.get_value("weatherEffects"))
	if statusHud:
		statusHud.showTracker = bool(Settings.get_value("questTracker"))

func _process(delta : float) -> void:
	if shown:
		saveFlash = move_toward(saveFlash, 0.0, delta)
		queue_redraw()

func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Preloader.stop()
		if Player.find(get_tree()):
			SaveGame.save_game(get_tree())

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(-position, size + Vector2(24.0, 0.0)), dimColor)
	draw_column(font)
	if page == Page.MAIN:
		draw_card(font)
	elif page == Page.LEAVE:
		draw_box(card, "Leave the game?")
		var lines : PackedStringArray = ui.wrap_lines("The game saves first, then you go back to the title screen.", card.size.x - 8.0, ui.statSize)
		var y : float = card.position.y + 16.0
		for line in lines:
			draw_string(font, Vector2(card.position.x + 4.0, y + font.get_ascent(ui.statSize)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.textColor)
			y += ui.statSize + 2.0
	else:
		draw_box(card, "Settings")
		var lines : PackedStringArray = ui.wrap_lines("Click or press Enter to change a setting, left and right step back and forth. Settings are kept for next time.", card.size.x - 8.0, ui.statSize)
		var y : float = card.position.y + 16.0
		for line in lines:
			draw_string(font, Vector2(card.position.x + 4.0, y + font.get_ascent(ui.statSize)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
			y += ui.statSize + 2.0

# A panel with a header band and its title.
func draw_box(area : Rect2, title : String) -> void:
	var font : Font = ui.font
	draw_rect(Rect2(area.position + Vector2(2.0, 2.0), area.size), Color(0.0, 0.0, 0.0, 0.35))
	UiKit.box(self, skin.frame, area)
	var band : Rect2 = Rect2(area.position + Vector2(4.0, 3.0), Vector2(area.size.x - 8.0, 9.0))
	draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 1.0), Color(ui.frameColor, 0.8))
	draw_string(font, Vector2(band.position.x, band.position.y + 1.0 + font.get_ascent(ui.titleSize)), title, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 6.0, ui.titleSize, ui.selectedColor)

func draw_column(font : Font) -> void:
	var list : Array[Array] = entries()
	var height : float = 14.0 + list.size() * rowHeight + 3.0
	var area : Rect2 = Rect2(column.position, Vector2(column.size.x, minf(height, column.size.y)))
	draw_box(area, "Menu" if page == Page.MAIN else ("Settings" if page == Page.SETTINGS else "Main menu"))
	rowRects.clear()
	if slideIn.size() != list.size():
		slideIn.resize(list.size())
		slideIn.fill(0.0)
	var y : float = area.position.y + 14.0
	for i in list.size():
		var row : Rect2 = Rect2(area.position.x + 3.0, y, area.size.x - 6.0, rowHeight - 1.0)
		rowRects.append(row)
		var active : bool = i == selected
		slideIn[i] = lerpf(slideIn[i], 1.0 if active else 0.0, 0.35)
		if active:
			draw_rect(row, ui.frameColor)
			draw_rect(row.grow(-1.0), ui.slotColor.lightened(0.12))
			draw_rect(Rect2(row.position.x + 1.0, row.position.y + 1.0, 1.0, row.size.y - 2.0), ui.selectedColor)
		var x : float = row.position.x + 3.0 + roundf(slideIn[i] * 2.0)
		if page == Page.MAIN and i < icons.size() and icons[i]:
			draw_texture(icons[i], Vector2(x, row.position.y + floorf((row.size.y - icons[i].get_height()) * 0.5)))
			x += icons[i].get_width() + 2.0
		var color : Color = ui.selectedColor if active else ui.textColor
		if list[i][2] == &"leave":
			color = ui.blockedColor
		if list[i][2] == &"save" and saveFlash != 0.0:
			color = goodColor if saveFlash > 0.0 else ui.blockedColor
		draw_string(font, Vector2(x, row.position.y + 2.0 + font.get_ascent(ui.titleSize)), list[i][0], HORIZONTAL_ALIGNMENT_LEFT, row.end.x - x, ui.titleSize, color)
		var hint : String = list[i][1]
		if list[i][2] == &"save" and saveFlash != 0.0:
			hint = "Saved!" if saveFlash > 0.0 else "Failed"
		if not hint.is_empty():
			var valueColor : Color = ui.dimColor if page == Page.MAIN else (goodColor if hint == "On" else ui.textColor)
			draw_string(font, Vector2(row.position.x, row.position.y + 3.0 + font.get_ascent(ui.statSize)), hint, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 2.0, ui.statSize, valueColor)
		y += rowHeight
	draw_string(font, Vector2(area.position.x, area.position.y + 4.0 + font.get_ascent(ui.statSize)), "Esc", HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 4.0, ui.statSize, Color(ui.dimColor, 0.8))

func draw_card(font : Font) -> void:
	var location : Location = player.atlas.current if player.atlas else null
	draw_box(card, location.displayName if location else "Out at sea")
	var y : float = card.position.y + 15.0
	var left : float = card.position.x + 4.0
	var width : float = card.size.x - 8.0
	if cycle:
		draw_row(font, "%s, %s" % [cycle.weekday_name(), Calendar.date_text(cycle.day)], "%d:%02d" % [floori(cycle.time), floori(fmod(cycle.time, 1.0) * 60.0)], y, ui.textColor)
		y += ui.statSize + 3.0
	var coins : String = "%d" % player.wallet.coins
	if coinIcon:
		draw_texture(coinIcon, Vector2(left, y))
	draw_string(font, Vector2(left + 7.0, y + font.get_ascent(ui.statSize + 1)), coins, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize + 1, ui.selectedColor)
	y += ui.statSize + 4.0
	var bar : Rect2 = Rect2(left, y, width, 4.0)
	draw_rect(bar, ui.frameColor)
	draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2.0) * player.energy.fraction(), 2.0)), Color(0.98, 0.82, 0.32).lerp(goodColor, player.energy.fraction()))
	draw_string(font, Vector2(left, y + 5.0 + font.get_ascent(ui.statSize)), "Energy %d/%d" % [ceili(player.energy.value), roundi(player.energy.maximum)], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
	y += ui.statSize + 8.0
	draw_rect(Rect2(left, y, width, 1.0), Color(ui.frameColor, 0.8))
	y += 3.0
	if weather:
		var icon : Texture2D = weather.icon(weather.state)
		if icon:
			draw_texture(icon, Vector2(left, y))
		var text : String = "%s: %s" % [Weather.NAMES[weather.state], weather.effect_text(weather.state)]
		draw_string(font, Vector2(left + 15.0, y + 2.0 + font.get_ascent(ui.statSize)), text, HORIZONTAL_ALIGNMENT_LEFT, width - 15.0, ui.statSize, ui.textColor)
		draw_string(font, Vector2(left + 15.0, y + ui.statSize + 4.0 + font.get_ascent(ui.statSize)), "Tomorrow: %s" % Weather.NAMES[weather.forecast()], HORIZONTAL_ALIGNMENT_LEFT, width - 15.0, ui.statSize, ui.dimColor)
		y += 15.0
	var found : int = player.journal.found_in(player.journal.all_fish())
	var total : int = player.journal.all_fish().size()
	draw_row(font, "Journal", "%d/%d fish" % [found, total], y, ui.textColor)
	y += ui.statSize + 2.0
	draw_row(font, "Angler Level", "%d" % AnglerLevel.level(player), y, Color(1.0, 0.78, 0.35))
	y += ui.statSize + 2.0
	var seat : Array = Council.current(get_tree(), player.progress)
	draw_row(font, "Council", seat[1], y, ui.textColor)
	y += ui.statSize + 2.0
	var unlocked : int = player.atlas.unlocked.size()
	draw_row(font, "Places", "%d/%d" % [unlocked, player.atlas.locations.size()], y, ui.textColor)
	y += ui.statSize + 2.0
	var festivals : Array[GameEvent] = EventDirector.active(get_tree())
	if not festivals.is_empty():
		draw_row(font, "Festival", festivals[0].displayName, y, festivals[0].color)
	elif cycle:
		var next : GameEvent = null
		var soonest : int = 1000
		for event in GameEvent.all():
			var wait : int = Calendar.days_until(event, cycle.day)
			if wait > 0 and wait < soonest:
				soonest = wait
				next = event
		if next:
			draw_row(font, "Next festival", "%s in %dd" % [next.displayName, soonest], y, next.color)
	y += ui.statSize + 2.0
	var orders : Dictionary = player.progress.orders
	var done : int = (orders.get("done", []) as Array).count(true) if cycle and orders.get("day", -1) == cycle.day else 0
	draw_row(font, "Harbor orders", "%d/%d" % [done, DailyOrders.COUNT], y, goodColor if done >= DailyOrders.COUNT else ui.textColor)

func draw_row(font : Font, label : String, value : String, y : float, color : Color) -> void:
	draw_string(font, Vector2(card.position.x + 4.0, y + font.get_ascent(ui.statSize)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
	draw_string(font, Vector2(card.position.x + 4.0, y + font.get_ascent(ui.statSize)), value, HORIZONTAL_ALIGNMENT_RIGHT, card.size.x - 8.0, ui.statSize, color)
