extends Control
class_name TitleScreen

# The first screen: the name over a calm night sea with fish drifting past.
# Continue loads the last save, Play opens the three save slots: a filled slot
# loads, an empty one starts a new game, right-clicking a filled slot twice
# deletes it. Quit isn't there on the web.

#------------------------#
@export_file("*.tscn") var loadingScene : String = "res://ui/loading/loading_screen.tscn"
@export var font : Font
@export var fishIcons : Array[Texture2D] = []
@export var title : String = "Fishing Game"
@export var tagline : String = "Cast off, catch them all"
@export var skyTop : Color = Color(0.03, 0.06, 0.13)
@export var skyBottom : Color = Color(0.07, 0.16, 0.28)
@export var waveColor : Color = Color(0.35, 0.6, 0.8, 0.35)
@export var textColor : Color = Color(0.94, 0.97, 1.0)
@export var accentColor : Color = Color(1.0, 0.9, 0.4)
@export var dimColor : Color = Color(0.58, 0.67, 0.78)
@export var frameColor : Color = Color(0.04, 0.07, 0.13)
@export var buttonColor : Color = Color(0.16, 0.24, 0.34)
@export var buttonHover : Color = Color(0.22, 0.46, 0.3)

var time : float = 0.0
var mouse : Vector2 = Vector2(-100.0, -100.0)
var buttons : Array[Array] = []
var selected : int = 0
var swimmers : Array[Array] = []
var leaving : bool = false
var slotsOpen : bool = false
# The slot a right click armed for deleting, -1 for none.
var deleting : int = -1
var summaries : Array[Dictionary] = []
#------------------------#


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	Settings.apply_global()
	get_tree().paused = false
	# The game's content loads in the background while the title is up (the
	# loading screen does it on the web, where there are no worker threads).
	if not OS.has_feature("web"):
		Preloader.start()
	refresh_slots()
	for i in 7:
		swimmers.append([randf() * 220.0 - 20.0, randf_range(62.0, 104.0), randf_range(4.0, 11.0) * (1.0 if randf() < 0.5 else -1.0), fishIcons.pick_random() if not fishIcons.is_empty() else null, randf() * TAU])

func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Preloader.stop()

func refresh_slots() -> void:
	summaries.clear()
	for i in SaveGame.SLOTS:
		summaries.append(SaveGame.summary(i))

func options() -> PackedStringArray:
	if slotsOpen:
		var list : PackedStringArray = PackedStringArray()
		for i in SaveGame.SLOTS:
			list.append("slot")
		list.append("Back")
		return list
	var main : PackedStringArray = PackedStringArray()
	if SaveGame.latest() >= 0:
		main.append("Continue")
	main.append("Play")
	if not OS.has_feature("web"):
		main.append("Quit")
	return main

func choose(index : int) -> void:
	if leaving:
		return
	match options()[index]:
		"Continue":
			start(SaveGame.latest())
		"Play":
			slotsOpen = true
			selected = 0
		"Back":
			slotsOpen = false
			selected = 0
		"slot":
			start(index)
		"Quit":
			Preloader.stop()
			get_tree().quit()

# Loads the slot, or starts a new game in it when it's empty.
func start(which : int) -> void:
	leaving = true
	SaveGame.slot = which
	SaveGame.pending = SaveGame.read(which)
	get_tree().change_scene_to_file.call_deferred(loadingScene)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		for i in buttons.size():
			if buttons[i][0].has_point(mouse):
				selected = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in buttons.size():
			if buttons[i][0].has_point(event.position):
				choose(i)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and slotsOpen:
		for i in mini(buttons.size(), SaveGame.SLOTS):
			if buttons[i][0].has_point(event.position) and not summaries[i].is_empty():
				if deleting == i:
					SaveGame.erase(i)
					deleting = -1
					refresh_slots()
				else:
					deleting = i

func _unhandled_input(event : InputEvent) -> void:
	var count : int = options().size()
	if event.is_action_pressed("ui_down") or event.is_action_pressed("down"):
		selected = posmod(selected + 1, count)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up"):
		selected = posmod(selected - 1, count)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		choose(selected)

func _process(delta : float) -> void:
	time += delta
	Preloader.poll()
	for swimmer in swimmers:
		swimmer[0] += swimmer[2] * delta
		if swimmer[0] > size.x + 20.0:
			swimmer[0] = -20.0
		elif swimmer[0] < -20.0:
			swimmer[0] = size.x + 20.0
	queue_redraw()

func _draw() -> void:
	var bands : int = 24
	for i in bands:
		var t : float = float(i) / bands
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / bands + 1.0), skyTop.lerp(skyBottom, t))
	var horizon : float = size.y * 0.52
	for i in 9:
		var y : float = horizon + i * i * 0.75 + 2.0
		var points : PackedVector2Array = PackedVector2Array()
		for x in range(0, int(size.x) + 8, 4):
			points.append(Vector2(x, y + sin(x * 0.08 + time * (0.8 + i * 0.15) + i) * (0.4 + i * 0.12)))
		draw_polyline(points, Color(waveColor, waveColor.a * (0.4 + i * 0.07)), 0.3, true)
	for swimmer in swimmers:
		var icon : Texture2D = swimmer[3]
		if icon:
			var at : Vector2 = Vector2(swimmer[0], swimmer[1] + sin(time * 1.5 + swimmer[4]) * 1.5)
			draw_set_transform(at, 0.0, Vector2(-0.6 if swimmer[2] < 0.0 else 0.6, 0.6))
			draw_texture(icon, -icon.get_size() * 0.5, Color(0.02, 0.05, 0.1, 0.55))
			draw_set_transform(Vector2.ZERO)
	for i in 14:
		var star : Vector2 = Vector2(fmod(i * 53.7, size.x), fmod(i * 17.3, horizon - 6.0) + 2.0)
		draw_rect(Rect2(star, Vector2(0.5, 0.5)), Color(1.0, 1.0, 0.9, 0.35 + 0.3 * sin(time * 2.0 + i)))
	if not font:
		return
	var titleSize : int = 12
	var bob : float = sin(time * 1.2) * 1.0
	var titleY : float = 20.0 + bob + font.get_ascent(titleSize)
	draw_string(font, Vector2(1.0, titleY + 1.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, titleSize, frameColor)
	draw_string(font, Vector2(0.0, titleY), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, titleSize, accentColor)
	draw_string(font, Vector2(0.0, titleY + 9.0), tagline, HORIZONTAL_ALIGNMENT_CENTER, size.x, 4, dimColor)
	buttons.clear()
	var list : PackedStringArray = options()
	var width : float = 96.0 if slotsOpen else 44.0
	var height : float = 13.0 if slotsOpen else 10.0
	var top : float = 46.0 if slotsOpen else 52.0
	for i in list.size():
		var area : Rect2 = Rect2(floorf((size.x - width) * 0.5), top + i * (height + 2.0), width, height if list[i] == "slot" else 9.0)
		if not slotsOpen:
			area.position.y = top + i * 13.0
		buttons.append([area])
		var active : bool = i == selected
		draw_rect(Rect2(area.position + Vector2(1.0, 1.0), area.size), Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(area, (Color(0.95, 0.38, 0.34) if deleting == i else frameColor))
		draw_rect(area.grow(-1.0), buttonHover if active else buttonColor)
		draw_rect(Rect2(area.position.x + 1.0, area.position.y + 1.0, area.size.x - 2.0, 1.0), Color(1.0, 1.0, 1.0, 0.18))
		if list[i] == "slot":
			draw_slot(i, area)
		else:
			draw_string(font, Vector2(area.position.x, area.position.y + 3.0 + font.get_ascent(4)), list[i], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 4, accentColor if active else textColor)
	var help : String = "Click a slot. Right-click twice to delete one." if slotsOpen else "Click or press Enter"
	draw_string(font, Vector2(0.0, size.y - 3.0), help, HORIZONTAL_ALIGNMENT_CENTER, size.x, 3, Color(dimColor, 0.7))

func draw_slot(index : int, area : Rect2) -> void:
	var info : Dictionary = summaries[index]
	var pen : Vector2 = area.position + Vector2(3.0, 2.0)
	if info.is_empty():
		draw_string(font, pen + Vector2(0.0, font.get_ascent(4)), "Slot %d - New game" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6.0, 4, textColor)
		return
	if deleting == index:
		draw_string(font, pen + Vector2(0.0, font.get_ascent(4)), "Right-click again to delete", HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6.0, 4, Color(0.95, 0.38, 0.34))
		return
	var playtime : float = info.get("playtime", 0.0)
	var line : String = "Slot %d - Day %d, %s" % [index + 1, info.get("day", 1), info.get("place", "")]
	draw_string(font, pen + Vector2(0.0, font.get_ascent(4)), line, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6.0, 4, accentColor)
	var detail : String = "$%d  %dh%02dm  %s  %.0f%%" % [info.get("coins", 0), floori(playtime / 3600.0), floori(fmod(playtime, 3600.0) / 60.0), info.get("chapter", ""), info.get("completion", 0.0)]
	draw_string(font, pen + Vector2(0.0, 5.0 + font.get_ascent(3)), detail, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6.0, 3, dimColor)