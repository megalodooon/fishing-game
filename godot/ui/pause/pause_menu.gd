extends MenuPanel
class_name PauseMenu

# Esc opens it: a slim column of buttons in the middle (resume, all menus,
# the sea chart, settings, multiplayer, save, main menu) with small cards
# either side summing up the day: date and time, coins, energy, weather,
# Angler Level, the council, places, orders and the next festival. The game
# pauses (unless a friend is playing). Settings open the shared settings
# panel; Multiplayer invites a friend from right here, showing the join code.
# Closing the window saves too.
# Keys: up/down or the mouse to pick, Enter or click to go, Esc to go back.

enum Page { MAIN, SETTINGS, LEAVE, FRIENDS }

const TITLE_SCENE : String = "res://ui/title/title_screen.tscn"
const COLUMN : float = 66.0
const ROW : float = 9.0
const CARD : float = 56.0

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
# Kept for the scene; the column draws no icons any more.
@export var icons : Array[Texture2D] = []
@export var coinIcon : Texture2D

@export_group("Look")
@export var dimColor : Color = Color(0.02, 0.04, 0.08, 0.55)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)
@export var skin : MenuSkin

var page : int = Page.MAIN
var selected : int = 0
var hovered : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var rowRects : Array[Rect2] = []
# Above 0 after a save worked, below 0 after it failed, fading to 0.
var saveFlash : float = 0.0
var copiedFlash : float = 0.0
var settings : SettingsPanel
var time : float = 0.0
var autosaveTimer : float = 0.0
#------------------------#


func _ready() -> void:
	super()
	process_mode = PROCESS_MODE_ALWAYS
	slide = Vector2(0.0, 6.0)
	if not skin:
		skin = MenuSkin.default_skin()
	set_anchors_preset(PRESET_TOP_LEFT)
	ui.laid_out.connect(fit)
	settings = SettingsPanel.new()
	settings.setup(ui.font, skin)
	settings.visible = false
	settings.changed.connect(apply_settings)
	settings.done.connect(func() -> void:
		page = Page.MAIN
		selected = 3
		settings.visible = false)
	add_child(settings)
	Settings.apply_global()
	apply_settings()
	fit()
	Net.address_ready.connect(func(_code : String, _note : String) -> void: queue_redraw())

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	settings.position = Vector2.ZERO
	settings.size = size
	queue_redraw()

func _has_point(_point : Vector2) -> bool:
	return shown

func column() -> Rect2:
	var count : int = entries().size()
	var height : float = 13.0 + count * ROW + 3.0
	return Rect2(floorf((size.x - COLUMN) * 0.5), floorf((size.y - height) * 0.5) + 6.0, COLUMN, height)

func entries() -> Array[Array]:
	match page:
		Page.LEAVE:
			return [["Save and leave", "", &"leave"], ["Stay", "", &"back"]]
		Page.FRIENDS:
			var list : Array[Array] = []
			if not Net.is_online():
				list.append(["Invite a friend", "", &"invite"])
			elif Net.is_host():
				list.append(["Copy join code", "", &"copy"])
				list.append(["Stop hosting", "", &"unhost"])
			list.append(["Back", "", &"back"])
			return list
		Page.SETTINGS:
			return []
	var main : Array[Array] = [["Resume", "Esc", &"resume"], ["All menus", "Tab", &"menus"], ["Sea chart", "M", &"map"], ["Settings", "", &"settings"]]
	if Net.supported():
		main.append(["Multiplayer", "", &"friends"])
	main.append(["Save game", "", &"save"])
	main.append(["Main menu", "", &"title"])
	return main

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
	if not shown or page == Page.SETTINGS:
		return
	var count : int = entries().size()
	if event.is_action_pressed("ui_cancel"):
		back()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down"):
		selected = posmod(selected + 1, count)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up"):
		selected = posmod(selected - 1, count)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate(selected)
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
			activate(hovered)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			back()
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()
		queue_redraw()

func open_pause() -> void:
	page = Page.MAIN
	selected = 0
	get_tree().paused = not Net.has_company()
	player.frozen = true
	open_menu()
	queue_redraw()

func resume() -> void:
	close_menu()
	settings.visible = false
	get_tree().paused = false
	player.frozen = false

func close() -> void:
	if shown:
		resume()

func back() -> void:
	match page:
		Page.MAIN:
			resume()
		Page.FRIENDS:
			go_to(Page.MAIN)
			selected = 4
		_:
			go_to(Page.MAIN)
			selected = entries().size() - 1

func go_to(which : int) -> void:
	page = which
	selected = 0
	hovered = -1
	settings.visible = page == Page.SETTINGS

func activate(index : int) -> void:
	var list : Array[Array] = entries()
	if index < 0 or index >= list.size():
		return
	match list[index][2]:
		&"resume":
			resume()
		&"menus":
			resume()
			var hub : MenuHub = MenuHub.find(get_tree())
			if hub:
				hub.switch_to(hub.last if hub.last >= 0 else hub.firstTab)
		&"map":
			resume()
			map.try_open()
		&"save":
			saveFlash = 1.5 if SaveGame.save_game(get_tree()) else -1.5
		&"settings":
			go_to(Page.SETTINGS)
		&"friends":
			go_to(Page.FRIENDS)
		&"invite":
			if Net.host() != OK:
				var board : NoticeBoard = NoticeBoard.find(get_tree())
				if board:
					board.post("Couldn't host", Net.lastError, ui.blockedColor)
		&"copy":
			DisplayServer.clipboard_set(Net.joinCode)
			copiedFlash = 1.5
		&"unhost":
			SaveGame.save_game(get_tree())
			Net.leave()
			go_to(Page.MAIN)
		&"title":
			go_to(Page.LEAVE)
			selected = 1
		&"leave":
			leave_game()
		&"back":
			back()

func leave_game() -> void:
	SaveGame.save_game(get_tree())
	# A guest's last save goes over the network: give it a moment to arrive.
	if Net.is_guest():
		await get_tree().create_timer(0.4, true).timeout
	Net.leave()
	get_tree().paused = false
	# At the end of the frame: changing scenes frees this menu, and the
	# click that got here still has to finish.
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)

func apply_settings() -> void:
	ui.uiScale = float(Settings.get_value("uiScale"))
	ui.hotbarOnTop = bool(Settings.get_value("hotbarOnTop"))
	player.heldItemScale = float(Settings.get_value("heldItemScale"))
	if weather:
		weather.showEffects = bool(Settings.get_value("weatherEffects"))
	if statusHud:
		statusHud.showTracker = bool(Settings.get_value("questTracker"))

func _process(delta : float) -> void:
	time += delta
	if shown:
		saveFlash = move_toward(saveFlash, 0.0, delta)
		copiedFlash = move_toward(copiedFlash, 0.0, delta)
		queue_redraw()
	# Saves every few minutes of play when the settings ask for it.
	var every : int = Settings.get_value("autosave")
	if every > 0 and not player.asleep and not get_tree().paused:
		autosaveTimer += delta
		if autosaveTimer >= every * 60.0:
			autosaveTimer = 0.0
			SaveGame.save_game(get_tree())

func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Preloader.stop()
		if Player.find(get_tree()):
			SaveGame.save_game(get_tree())

#------------------------# Drawing

func _draw() -> void:
	draw_rect(Rect2(-position, size + Vector2(24.0, 24.0)), dimColor)
	if page == Page.SETTINGS:
		return
	var font : Font = ui.font
	draw_header(font)
	draw_column(font)
	draw_cards(font)

func draw_header(font : Font) -> void:
	var location : Location = player.atlas.current if player.atlas else null
	var title : String = location.displayName if location else "Out at sea"
	UiKit.label(self, font, Vector2(0.0, 10.0), title, 6, ui.selectedColor, HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.0, 0.0, 0.0, 0.8))
	if cycle:
		var date : String = "%s, %s   %d:%02d" % [cycle.weekday_name(), Calendar.date_text(cycle.day), floori(cycle.time), floori(fmod(cycle.time, 1.0) * 60.0)]
		UiKit.label(self, font, Vector2(0.0, 16.0), date, 3, ui.textColor, HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.0, 0.0, 0.0, 0.8))

func draw_column(font : Font) -> void:
	var list : Array[Array] = entries()
	var area : Rect2 = column()
	UiKit.box(self, skin.frame, area)
	var heading : String = "Paused" if not Net.has_company() else "Menu"
	match page:
		Page.LEAVE:
			heading = "Leave?"
		Page.FRIENDS:
			heading = "Multiplayer"
	UiKit.label(self, font, Vector2(area.position.x, area.position.y + 4.0 + font.get_ascent(4)), heading, 4, skin.title, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	rowRects.clear()
	var y : float = area.position.y + 12.0
	for i in list.size():
		var row : Rect2 = Rect2(area.position.x + 3.0, y, area.size.x - 6.0, ROW - 1.0)
		rowRects.append(row)
		var text : String = list[i][0]
		var key : StringName = list[i][2]
		if key == &"save" and saveFlash != 0.0:
			text = "Saved!" if saveFlash > 0.0 else "Save failed"
		if key == &"copy" and copiedFlash > 0.0:
			text = "Copied!"
		UiKit.button(self, font, skin, row, text, 4, true, i == selected)
		if i == selected:
			UiKit.brackets(self, row, ui.selectedColor, time)
		y += ROW

# Small cards either side of the column.
func draw_cards(font : Font) -> void:
	var left : float = column().position.x - CARD - 6.0
	var right : float = column().end.x + 6.0
	var y : float = 24.0
	y = card(font, left, y, "Coins", UiKit.coins_text(player.wallet.coins), ui.selectedColor, coinIcon)
	y = energy_card(font, left, y)
	if weather:
		y = card(font, left, y, Weather.NAMES[weather.state], weather.effect_text(weather.state), ui.textColor, weather.icon(weather.state), "Tomorrow: " + Weather.NAMES[weather.forecast()])
	card(font, left, y, "Angler Level", str(AnglerLevel.level(player)), Color(1.0, 0.78, 0.35))
	y = 24.0
	if Net.is_online() or page == Page.FRIENDS:
		y = friends_card(font, right, y)
	var found : int = player.journal.found_in(player.journal.all_fish())
	y = card(font, right, y, "Journal", "%d/%d fish" % [found, player.journal.all_fish().size()], ui.textColor)
	y = card(font, right, y, "Places", "%d/%d" % [player.atlas.unlocked.size(), player.atlas.locations.size()], ui.textColor)
	var orders : Dictionary = player.progress.orders
	var done : int = (orders.get("done", []) as Array).count(true) if cycle and orders.get("day", -1) == cycle.day else 0
	y = card(font, right, y, "Harbor orders", "%d/%d" % [done, DailyOrders.COUNT], goodColor if done >= DailyOrders.COUNT else ui.textColor)
	var festivals : Array[GameEvent] = EventDirector.active(get_tree())
	if not festivals.is_empty():
		card(font, right, y, "Festival", festivals[0].displayName, festivals[0].color)
	elif cycle:
		var next : GameEvent = null
		var soonest : int = 1000
		for event in GameEvent.all():
			var wait : int = Calendar.days_until(event, cycle.day)
			if wait > 0 and wait < soonest:
				soonest = wait
				next = event
		if next:
			card(font, right, y, "Next festival", "%s in %dd" % [next.displayName, soonest], next.color)

# One card: a small label over a value, with an icon. Returns the next y.
func card(font : Font, x : float, y : float, label : String, value : String, color : Color, icon : Texture2D = null, extra : String = "") -> float:
	var height : float = 13.0 + (5.0 if not extra.is_empty() else 0.0)
	var area : Rect2 = Rect2(x, y, CARD, height)
	UiKit.box(self, skin.card, area)
	var pen : float = x + 3.0
	if icon:
		var fit_in : float = minf(9.0 / maxf(icon.get_height(), 1.0), 1.0)
		var drawn : Vector2 = icon.get_size() * fit_in
		draw_texture_rect(icon, Rect2(Vector2(pen, y + 2.0), drawn), false)
		pen += drawn.x + 2.0
	UiKit.label(self, font, Vector2(pen, y + 2.0 + font.get_ascent(3)), label, 3, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, area.end.x - pen - 2.0)
	UiKit.label(self, font, Vector2(pen, y + 7.0 + font.get_ascent(3)), value, 3, color, HORIZONTAL_ALIGNMENT_LEFT, area.end.x - pen - 2.0)
	if not extra.is_empty():
		UiKit.label(self, font, Vector2(x + 3.0, y + 12.0 + font.get_ascent(3)), extra, 3, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, CARD - 6.0)
	return y + height + 2.0

func energy_card(font : Font, x : float, y : float) -> float:
	var area : Rect2 = Rect2(x, y, CARD, 13.0)
	UiKit.box(self, skin.card, area)
	UiKit.label(self, font, Vector2(x + 3.0, y + 2.0 + font.get_ascent(3)), "Energy", 3, skin.dim)
	UiKit.label(self, font, Vector2(x, y + 2.0 + font.get_ascent(3)), "%d/%d" % [ceili(player.energy.value), roundi(player.energy.maximum)], 3, ui.textColor, HORIZONTAL_ALIGNMENT_RIGHT, CARD - 3.0)
	UiKit.bar(self, Rect2(x + 3.0, y + 8.0, CARD - 6.0, 3.0), player.energy.fraction(), Color(0.98, 0.82, 0.32).lerp(goodColor, player.energy.fraction()))
	return y + 15.0

func friends_card(font : Font, x : float, y : float) -> float:
	var lines : PackedStringArray = PackedStringArray()
	var title : String = "Playing alone"
	if Net.is_host():
		title = "Hosting"
		lines.append("Code: " + Net.joinCode)
		lines.append_array(ui.wrap_lines(Net.addressNote, CARD - 6.0, 3))
	elif Net.is_guest():
		title = "Playing with"
	else:
		lines.append_array(ui.wrap_lines("Invite a friend to play in this world. They join from the title screen with a code.", CARD - 6.0, 3))
	for id in Net.names:
		lines.append(Net.names[id])
	var height : float = 9.0 + lines.size() * 5.0
	var area : Rect2 = Rect2(x, y, CARD, height)
	UiKit.box(self, skin.card, area)
	UiKit.label(self, font, Vector2(x + 3.0, y + 2.0 + font.get_ascent(3)), title, 3, Color(0.55, 0.78, 1.0))
	var pen : float = y + 7.0
	for line in lines:
		UiKit.label(self, font, Vector2(x + 3.0, pen + font.get_ascent(3)), line, 3, ui.selectedColor if line.begins_with("Code") else skin.text, HORIZONTAL_ALIGNMENT_LEFT, CARD - 6.0)
		pen += 5.0
	return y + height + 2.0
