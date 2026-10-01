extends Control
class_name TitleScreen

# The first screen. Continue loads the last save; Singleplayer opens the save
# slots (a filled slot loads, an empty one starts a new game); Multiplayer
# hosts one of your worlds for a friend or joins a friend's with their code;
# Settings changes the game's settings. The background is
# res://ui/title/background.png when it's there (drawn to cover the screen),
# a plain night sky otherwise.

enum Page { MAIN, SAVES, MULTI, JOIN, SETTINGS, BUSY }

const BACKGROUND : String = "res://ui/title/background.png"
const NAME_LENGTH : int = 14
const CODE_LENGTH : int = 21

#------------------------#
@export_file("*.tscn") var loadingScene : String = "res://ui/loading/loading_screen.tscn"
@export var font : Font
@export var title : String = "Fishing Game"
@export var tagline : String = "A story of the sea"
@export var skyTop : Color = Color(0.03, 0.06, 0.13)
@export var skyBottom : Color = Color(0.08, 0.17, 0.28)
@export var textColor : Color = Color(0.94, 0.97, 1.0)
@export var accentColor : Color = Color(1.0, 0.9, 0.4)
@export var dimColor : Color = Color(0.58, 0.67, 0.78)
@export var badColor : Color = Color(0.95, 0.42, 0.38)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)

var skin : MenuSkin
var background : Texture2D
var time : float = 0.0
var page : Page = Page.MAIN
# Hosting from the save slots instead of playing alone.
var hosting : bool = false
var selected : int = 0
var buttons : Array[Array] = []
var summaries : Array[Dictionary] = []
# The slot a delete button was pressed on once, -1 for none.
var deleting : int = -1
var leaving : bool = false
var settings : SettingsPanel
# The join page's text boxes: 0 the name, 1 the code.
var field : int = 0
var nameText : String = ""
var codeText : String = ""
var message : String = ""
var messageColor : Color = Color.WHITE
#------------------------#


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	Settings.apply_global()
	get_tree().paused = false
	skin = MenuSkin.default_skin()
	if ResourceLoader.exists(BACKGROUND):
		background = load(BACKGROUND)
	# The game's content loads in the background while the title is up (the
	# loading screen does it on the web, where there are no worker threads).
	if not OS.has_feature("web"):
		Preloader.start()
	nameText = Settings.get_value("playerName")
	codeText = Settings.get_value("lastCode")
	settings = SettingsPanel.new()
	settings.setup(font, skin)
	settings.set_anchors_preset(PRESET_FULL_RECT)
	settings.visible = false
	settings.done.connect(func() -> void: go(Page.MAIN))
	add_child(settings)
	refresh_slots()
	Net.failed.connect(on_net_failed)
	if not Net.lastError.is_empty():
		say(Net.lastError, badColor)
		Net.lastError = ""

func _exit_tree() -> void:
	if Net.failed.is_connected(on_net_failed):
		Net.failed.disconnect(on_net_failed)

func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Preloader.stop()

func refresh_slots() -> void:
	summaries.clear()
	for i in SaveGame.SLOTS:
		summaries.append(SaveGame.summary(i))

func say(text : String, color : Color) -> void:
	message = text
	messageColor = color

func go(to : Page) -> void:
	page = to
	selected = 0
	deleting = -1
	settings.visible = page == Page.SETTINGS
	if settings.visible:
		settings.grab_focus()

# The buttons on this page: label and what it does.
func options() -> Array[Array]:
	match page:
		Page.SAVES:
			var list : Array[Array] = []
			for i in SaveGame.SLOTS:
				list.append(["slot", i])
			list.append(["Back", &"back"])
			return list
		Page.MULTI:
			return [["Host a world", &"host"], ["Join a friend", &"join"], ["Back", &"back"]]
		Page.JOIN:
			return [["name", &"name"], ["code", &"code"], ["Join", &"connect"], ["Back", &"back_multi"]]
		Page.BUSY:
			return [["Cancel", &"cancel"]]
		Page.SETTINGS:
			return []
	var main : Array[Array] = []
	if SaveGame.latest() >= 0:
		main.append(["Continue", &"continue"])
	main.append(["Singleplayer", &"single"])
	if Net.supported():
		main.append(["Multiplayer", &"multi"])
	main.append(["Settings", &"settings"])
	if not OS.has_feature("web"):
		main.append(["Quit", &"quit"])
	return main

func choose(index : int) -> void:
	var list : Array[Array] = options()
	if leaving or index < 0 or index >= list.size():
		return
	var key : Variant = list[index][1]
	if list[index][0] == "slot":
		pick_slot(key)
		return
	match key:
		&"continue":
			start(SaveGame.latest())
		&"single":
			hosting = false
			say("", textColor)
			go(Page.SAVES)
		&"multi":
			say("", textColor)
			go(Page.MULTI)
		&"settings":
			go(Page.SETTINGS)
		&"host":
			hosting = true
			say("Pick the world to share. Your friend joins with the code shown in the game (Esc menu).", dimColor)
			go(Page.SAVES)
		&"join":
			say("Type your name and your friend's code.", dimColor)
			field = 0 if nameText.is_empty() else 1
			go(Page.JOIN)
		&"name":
			field = 0
		&"code":
			field = 1
		&"connect":
			join()
		&"back":
			say("", textColor)
			go(Page.MULTI if hosting else Page.MAIN)
		&"back_multi":
			go(Page.MULTI)
		&"cancel":
			Net.leave()
			say("", textColor)
			go(Page.JOIN)
		&"quit":
			Preloader.stop()
			get_tree().quit()

func pick_slot(which : int) -> void:
	var info : Dictionary = summaries[which]
	if info.get("outdated", false):
		say("That save is from an older version and can't be loaded. Delete it to use the slot.", badColor)
		return
	start(which)

# Loads the slot, or starts a new game in it when it's empty.
func start(which : int) -> void:
	if hosting and Net.host() != OK:
		say(Net.lastError if not Net.lastError.is_empty() else "Couldn't start hosting.", badColor)
		return
	if not hosting:
		Net.leave()
	leaving = true
	SaveGame.slot = which
	SaveGame.pending = SaveGame.read(which)
	SaveGame.newName = ""
	if SaveGame.pending.is_empty():
		Net.guestData = {}
	get_tree().change_scene_to_file.call_deferred(loadingScene)

func join() -> void:
	nameText = nameText.strip_edges()
	if nameText.is_empty():
		say("Type your name first.", badColor)
		field = 0
		return
	if Net.decode_address(codeText).is_empty():
		say("That code doesn't look right. It's like 4KQ2-8M7X-ZD.", badColor)
		field = 1
		return
	Settings.set_value("playerName", nameText)
	Settings.set_value("lastCode", codeText.strip_edges())
	if Net.join(codeText, nameText) != OK:
		say(Net.lastError, badColor)
		return
	say("Connecting to your friend...", accentColor)
	go(Page.BUSY)

func on_net_failed(reason : String) -> void:
	if page == Page.BUSY:
		go(Page.JOIN)
	say(reason, badColor)

func delete_slot(which : int) -> void:
	if deleting == which:
		SaveGame.erase(which)
		deleting = -1
		refresh_slots()
		say("Deleted.", dimColor)
	else:
		deleting = which
		say("Click delete again to erase this save for good.", badColor)

#------------------------# Input

func _gui_input(event : InputEvent) -> void:
	if page == Page.SETTINGS:
		return
	if event is InputEventMouseMotion:
		for i in buttons.size():
			if buttons[i][0].has_point(event.position):
				selected = buttons[i][1]
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Last drawn first: the Del button sits on top of its slot.
		for index in range(buttons.size() - 1, -1, -1):
			var each : Array = buttons[index]
			if each[0].has_point(event.position):
				if each.size() > 2 and each[2] == &"delete":
					delete_slot(each[1])
				else:
					choose(each[1])
				break

func _unhandled_input(event : InputEvent) -> void:
	if page == Page.SETTINGS:
		return
	if page == Page.JOIN and event is InputEventKey and event.pressed and type_key(event):
		get_viewport().set_input_as_handled()
		return
	var count : int = options().size()
	if count == 0:
		return
	if event.is_action_pressed("ui_down") or (event.is_action_pressed("down") and page != Page.JOIN):
		selected = posmod(selected + 1, count)
	elif event.is_action_pressed("ui_up") or (event.is_action_pressed("up") and page != Page.JOIN):
		selected = posmod(selected - 1, count)
	elif event.is_action_pressed("ui_accept"):
		choose(selected)
	elif event.is_action_pressed("ui_cancel") and page != Page.MAIN:
		choose(count - 1)

# Typing into the join page's boxes. Returns whether the key was used.
func type_key(key : InputEventKey) -> bool:
	if key.keycode == KEY_TAB or (key.keycode in [KEY_ENTER, KEY_KP_ENTER] and field == 0):
		field = 1 - field
		selected = field
		return true
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		join()
		return true
	var text : String = nameText if field == 0 else codeText
	var limit : int = NAME_LENGTH if field == 0 else CODE_LENGTH
	if key.keycode == KEY_BACKSPACE:
		text = text.left(text.length() - 1)
	elif key.keycode == KEY_V and key.is_command_or_control_pressed():
		text = (text + DisplayServer.clipboard_get().strip_edges()).left(limit)
	elif key.unicode >= 32 and key.unicode < 127 and text.length() < limit:
		var letter : String = char(key.unicode)
		if field == 1:
			letter = letter.to_upper()
		text += letter
	else:
		return false
	if field == 0:
		nameText = text
	else:
		codeText = text
	return true

func _process(delta : float) -> void:
	time += delta
	Preloader.poll()
	queue_redraw()

#------------------------# Drawing

func _draw() -> void:
	draw_background()
	if not font:
		return
	buttons.clear()
	if page != Page.SETTINGS:
		draw_title()
	match page:
		Page.MAIN:
			draw_column(options(), 52.0, 56.0)
		Page.MULTI:
			draw_column(options(), 52.0, 64.0)
		Page.SAVES:
			draw_slots()
		Page.JOIN:
			draw_join()
		Page.BUSY:
			draw_column(options(), 70.0, 44.0)
	if not message.is_empty() and page != Page.SETTINGS:
		var lines : PackedStringArray = wrap_text(message, size.x - 24.0, 3)
		var y : float = size.y - 4.0 - (lines.size() - 1) * 5.0
		for line in lines:
			UiKit.label(self, font, Vector2(0.0, y), line, 3, messageColor, HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.0, 0.0, 0.0, 0.8))
			y += 5.0

func draw_background() -> void:
	if background:
		var scale_to : float = maxf(size.x / background.get_width(), size.y / background.get_height())
		var drawn : Vector2 = background.get_size() * scale_to
		draw_texture_rect(background, Rect2((size - drawn) * 0.5, drawn), false)
		return
	var bands : int = 24
	for i in bands:
		var t : float = float(i) / bands
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / bands + 1.0), skyTop.lerp(skyBottom, t))

func draw_title() -> void:
	var titleSize : int = 12 if page == Page.MAIN or page == Page.MULTI else 8
	var y : float = (24.0 if titleSize == 12 else 13.0) + sin(time * 1.2)
	UiKit.label(self, font, Vector2(1.0, y + 1.0), title, titleSize, Color(0.02, 0.04, 0.08, 0.9), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	UiKit.label(self, font, Vector2(0.0, y), title, titleSize, accentColor, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if titleSize == 12:
		UiKit.label(self, font, Vector2(0.0, y + 9.0), tagline, 4, dimColor, HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.0, 0.0, 0.0, 0.6))

func draw_column(list : Array[Array], top : float, width : float) -> void:
	for i in list.size():
		var area : Rect2 = Rect2(floorf((size.x - width) * 0.5), top + i * 11.0, width, 9.0)
		buttons.append([area, i])
		UiKit.button(self, font, skin, area, list[i][0], 4, true, i == selected)

func draw_slots() -> void:
	var heading : String = "Host a world" if hosting else "Your saves"
	UiKit.label(self, font, Vector2(0.0, 24.0), heading, 4, textColor, HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.0, 0.0, 0.0, 0.7))
	var width : float = minf(150.0, size.x - 16.0)
	var left : float = floorf((size.x - width) * 0.5)
	for i in SaveGame.SLOTS:
		var area : Rect2 = Rect2(left, 29.0 + i * 21.0, width, 19.0)
		buttons.append([area, i])
		draw_slot(i, area, i == selected)
		if not summaries[i].is_empty():
			var bin : Rect2 = Rect2(area.end.x - 13.0, area.position.y + 2.0, 11.0, 7.0)
			buttons.append([bin, i, &"delete"])
			draw_rect(bin, badColor.darkened(0.3) if deleting == i else Color(0.0, 0.0, 0.0, 0.35))
			UiKit.label(self, font, Vector2(bin.position.x, UiKit.baseline(font, bin, 3)), "Del", 3, textColor, HORIZONTAL_ALIGNMENT_CENTER, bin.size.x)
	var back : Rect2 = Rect2(floorf((size.x - 36.0) * 0.5), 29.0 + SaveGame.SLOTS * 21.0, 36.0, 9.0)
	buttons.append([back, SaveGame.SLOTS])
	UiKit.button(self, font, skin, back, "Back", 4, true, selected == SaveGame.SLOTS)

func draw_slot(index : int, area : Rect2, active : bool) -> void:
	UiKit.box(self, skin.card, area)
	if active:
		UiKit.brackets(self, area, accentColor, time)
	var info : Dictionary = summaries[index]
	var pen : Vector2 = area.position + Vector2(4.0, 3.0)
	if info.is_empty():
		UiKit.label(self, font, pen + Vector2(0.0, font.get_ascent(4) + 3.0), "New game", 4, goodColor)
		UiKit.label(self, font, pen + Vector2(48.0, font.get_ascent(4) + 3.0), "Slot %d - empty" % (index + 1), 3, skin.dim)
		return
	if info.get("outdated", false):
		UiKit.label(self, font, pen + Vector2(0.0, font.get_ascent(4)), "Old save (Slot %d)" % (index + 1), 4, badColor)
		UiKit.label(self, font, pen + Vector2(0.0, 7.0 + font.get_ascent(3)), "Made by an older version. Delete it to reuse.", 3, skin.dim)
		return
	var who : String = str(info.get("name", ""))
	UiKit.label(self, font, pen + Vector2(0.0, font.get_ascent(4)), who if not who.is_empty() else "Angler", 4, accentColor)
	var when : String = "Day %d %s - %s" % [info.get("day", 1), info.get("weekday", ""), info.get("place", "")]
	UiKit.label(self, font, Vector2(pen.x + 44.0, pen.y + font.get_ascent(3) + 0.5), when, 3, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 64.0)
	var playtime : float = info.get("playtime", 0.0)
	var detail : String = "$%s   %dh %02dm   %s   %.0f%%" % [UiKit.coins_text(info.get("coins", 0)), floori(playtime / 3600.0), floori(fmod(playtime, 3600.0) / 60.0), info.get("chapter", ""), info.get("completion", 0.0)]
	UiKit.label(self, font, pen + Vector2(0.0, 7.0 + font.get_ascent(3)), detail, 3, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 8.0)
	var friends : Array = (info.get("players", []) as Array).filter(func(each : Variant) -> bool: return str(each) != who)
	if not friends.is_empty():
		UiKit.label(self, font, pen + Vector2(0.0, 12.0 + font.get_ascent(3)), "With " + ", ".join(PackedStringArray(friends)), 3, Color(0.55, 0.78, 1.0), HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 8.0)

func draw_join() -> void:
	UiKit.label(self, font, Vector2(0.0, 24.0), "Join a friend", 4, textColor, HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.0, 0.0, 0.0, 0.7))
	var width : float = 110.0
	var left : float = floorf((size.x - width) * 0.5)
	var boxes : Array = [["Your name", nameText, 0], ["Friend's code", codeText, 1]]
	for each in boxes:
		var i : int = each[2]
		var area : Rect2 = Rect2(left, 34.0 + i * 17.0, width, 9.0)
		UiKit.label(self, font, Vector2(area.position.x, area.position.y - 2.0), each[0], 3, dimColor)
		buttons.append([area, i])
		UiKit.box(self, skin.well, area)
		if field == i:
			UiKit.outline(self, area, accentColor)
		var shown : String = each[1] + ("_" if field == i and fmod(time, 1.0) < 0.6 else "")
		UiKit.label(self, font, Vector2(area.position.x + 3.0, UiKit.baseline(font, area, 4)), shown, 4, textColor)
	for i in 2:
		var area : Rect2 = Rect2(floorf(size.x * 0.5) - 38.0 + i * 40.0, 70.0, 36.0, 9.0)
		buttons.append([area, i + 2])
		UiKit.button(self, font, skin, area, "Join" if i == 0 else "Back", 4, true, selected == i + 2)

func wrap_text(text : String, width : float, fontSize : int) -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	var line : String = ""
	for word in text.split(" "):
		var test : String = word if line.is_empty() else line + " " + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = test
	if not line.is_empty():
		lines.append(line)
	return lines
