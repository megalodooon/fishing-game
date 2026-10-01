extends Control
class_name SettingsPanel

# Every setting on four tabs (Game, Video, Audio, Controls), drawn in the
# menus' style. The title screen and the pause menu both show it. Click a row
# or press Enter to change it, left/right step through its choices, and on
# the controls tab clicking a row waits for the new key (Esc keeps the old one).

signal changed
signal done

const TABS : PackedStringArray = ["Game", "Video", "Audio", "Controls"]
const ROW : float = 8.0
const SIZE : Vector2 = Vector2(150.0, 92.0)

#------------------------#
var font : Font
var skin : MenuSkin
var tab : int = 0
var selected : int = 0
var hovered : int = -1
var tabHovered : int = -1
var scroll : int = 0
var listening : String = ""
var rects : Array[Rect2] = []
var tabRects : Array[Rect2] = []
var backRect : Rect2
var time : float = 0.0
#------------------------#


func setup(withFont : Font, withSkin : MenuSkin = null) -> void:
	font = withFont
	skin = withSkin if withSkin else MenuSkin.default_skin()
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_ALL

func panel() -> Rect2:
	return Rect2(((size - SIZE) * 0.5).floor(), SIZE)

# Each row: label, shown value, key.
func rows() -> Array[Array]:
	match tab:
		1:
			var list : Array[Array] = []
			if not OS.has_feature("web"):
				list.append(["Window", (Settings.get_value("windowMode") as String).capitalize(), &"windowMode"])
				list.append(["V-Sync", on_off(Settings.get_value("vsync")), &"vsync"])
			var cap : int = Settings.get_value("fpsCap")
			list.append(["Frame limit", "None" if cap <= 0 else "%d fps" % cap, &"fpsCap"])
			list.append(["Show FPS", on_off(Settings.get_value("showFps")), &"showFps"])
			list.append(["UI size", "%d%%" % roundi(float(Settings.get_value("uiScale")) * 100.0), &"uiScale"])
			list.append(["Weather effects", on_off(Settings.get_value("weatherEffects")), &"weatherEffects"])
			list.append(["Screen shake", on_off(Settings.get_value("screenShake")), &"screenShake"])
			list.append(["Reduce flashing", on_off(Settings.get_value("reduceFlashing")), &"reduceFlashing"])
			return list
		2:
			return [
				["Master volume", percent("volume"), &"volume"],
				["Music", percent("musicVolume"), &"musicVolume"],
				["Sound effects", percent("sfxVolume"), &"sfxVolume"],
			]
		3:
			var list : Array[Array] = []
			for pair in Settings.ACTIONS:
				list.append([pair[1], "Press a key..." if listening == pair[0] else Settings.key_name(pair[0]), StringName("key:" + pair[0])])
			list.append(["Reset all keys", "", &"resetKeys"])
			return list
	var speed : float = Settings.get_value("textSpeed")
	var save : int = Settings.get_value("autosave")
	return [
		["Text speed", "Instant" if speed > 10.0 else ("Slow" if speed < 1.0 else ("Fast" if speed > 1.0 else "Normal")), &"textSpeed"],
		["Quest tracker", on_off(Settings.get_value("questTracker")), &"questTracker"],
		["Hotbar", "Top" if Settings.get_value("hotbarOnTop") else "Bottom", &"hotbarOnTop"],
		["Held items", "%d%%" % roundi(float(Settings.get_value("heldItemScale")) * 100.0), &"heldItemScale"],
		["Rarity letters", on_off(Settings.get_value("rarityLetters")), &"rarityLetters"],
		["Autosave", "Off" if save <= 0 else "Every %d min" % save, &"autosave"],
	]

static func on_off(value : Variant) -> String:
	return "On" if value else "Off"

static func percent(key : String) -> String:
	return "%d%%" % roundi(float(Settings.get_value(key)) * 100.0)

func visible_rows() -> int:
	return floori((panel().size.y - 34.0) / ROW)

func change(key : StringName, direction : int) -> void:
	var text : String = key
	if text.begins_with("key:"):
		listening = text.substr(4)
		return
	match key:
		&"resetKeys":
			Settings.reset_keys()
		&"windowMode":
			Settings.set_value("windowMode", cycle(Array(Settings.WINDOW_MODES), Settings.get_value("windowMode"), direction))
		&"fpsCap":
			Settings.set_value("fpsCap", cycle(Array(Settings.FPS_CAPS), Settings.get_value("fpsCap"), direction))
		&"textSpeed":
			Settings.set_value("textSpeed", cycle(Array(Settings.TEXT_SPEEDS), Settings.get_value("textSpeed"), direction))
		&"autosave":
			Settings.set_value("autosave", cycle(Array(Settings.AUTOSAVES), Settings.get_value("autosave"), direction))
		&"uiScale":
			step("uiScale", 0.25, 0.75, 1.25, direction)
		&"heldItemScale":
			step("heldItemScale", 0.25, 0.5, 1.5, direction)
		&"volume", &"musicVolume", &"sfxVolume":
			step(key, 0.1, 0.0, 1.0, direction)
		_:
			Settings.set_value(key, not Settings.get_value(key))
	Settings.apply_global()
	changed.emit()

static func cycle(list : Array, current : Variant, direction : int) -> Variant:
	var index : int = 0
	for i in list.size():
		if is_equal_approx(float(list[i]), float(current)) if not current is String else list[i] == current:
			index = i
	return list[posmod(index + direction, list.size())]

static func step(key : String, amount : float, low : float, high : float, direction : int) -> void:
	var value : float = snappedf(float(Settings.get_value(key)) + amount * direction, amount)
	if value > high + 0.001:
		value = low
	elif value < low - 0.001:
		value = high
	Settings.set_value(key, value)

func _input(event : InputEvent) -> void:
	if listening.is_empty() or not is_visible_in_tree():
		return
	var key : InputEventKey = event as InputEventKey
	var click : InputEventMouseButton = event as InputEventMouseButton
	if key and key.pressed and not key.echo:
		if key.keycode != KEY_ESCAPE:
			Settings.bind(listening, key)
			changed.emit()
		listening = ""
		get_viewport().set_input_as_handled()
	elif click and click.pressed and click.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		Settings.bind(listening, click)
		listening = ""
		changed.emit()
		get_viewport().set_input_as_handled()

func _gui_input(event : InputEvent) -> void:
	if not listening.is_empty():
		accept_event()
		return
	if event is InputEventMouseMotion:
		hovered = -1
		tabHovered = -1
		for i in rects.size():
			if rects[i].has_point(event.position):
				hovered = i
				selected = i + scroll
		for i in tabRects.size():
			if tabRects[i].has_point(event.position):
				tabHovered = i
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var direction : int = 1 if event.button_index == MOUSE_BUTTON_LEFT else -1
				for i in tabRects.size():
					if tabRects[i].has_point(event.position):
						open_tab(i)
				if backRect.has_point(event.position):
					done.emit()
				for i in rects.size():
					if rects[i].has_point(event.position):
						change(rows()[i + scroll][2], direction)
			MOUSE_BUTTON_WHEEL_UP:
				scroll = maxi(scroll - 1, 0)
			MOUSE_BUTTON_WHEEL_DOWN:
				scroll = clampi(scroll + 1, 0, maxi(rows().size() - visible_rows(), 0))
	accept_event()
	queue_redraw()

func open_tab(which : int) -> void:
	tab = posmod(which, TABS.size())
	selected = 0
	scroll = 0

func _unhandled_key_input(event : InputEvent) -> void:
	if not is_visible_in_tree() or not listening.is_empty():
		return
	var count : int = rows().size()
	if event.is_action_pressed("ui_cancel"):
		done.emit()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down"):
		selected = posmod(selected + 1, count)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up"):
		selected = posmod(selected - 1, count)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("left"):
		change(rows()[selected][2], -1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right"):
		change(rows()[selected][2], 1)
	elif event.is_action_pressed("ui_accept"):
		change(rows()[selected][2], 1)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_TAB:
		open_tab(tab + (-1 if (event as InputEventKey).shift_pressed else 1))
	else:
		return
	scroll = clampi(scroll, selected - visible_rows() + 1, selected)
	get_viewport().set_input_as_handled()
	queue_redraw()

func _process(delta : float) -> void:
	time += delta
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if not font:
		return
	var area : Rect2 = panel()
	UiKit.box(self, skin.frame, area)
	UiKit.ribbon(self, font, skin, area.get_center().x, area.position.y - 3.0, "Settings", 5)
	tabRects.clear()
	var tabWidth : float = floorf((area.size.x - 8.0) / TABS.size())
	for i in TABS.size():
		var r : Rect2 = Rect2(area.position.x + 4.0 + i * tabWidth, area.position.y + 9.0, tabWidth - 1.0, 9.0)
		tabRects.append(r)
		UiKit.box(self, skin.tabOn if i == tab else (skin.tabHover if i == tabHovered else skin.tab), r)
		UiKit.label(self, font, Vector2(r.position.x, UiKit.baseline(font, r, 4)), TABS[i], 4, skin.title if i == tab else skin.text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var list : Array[Array] = rows()
	var well : Rect2 = Rect2(area.position.x + 4.0, area.position.y + 20.0, area.size.x - 8.0, visible_rows() * ROW + 2.0)
	UiKit.box(self, skin.well, well)
	rects.clear()
	scroll = clampi(scroll, 0, maxi(list.size() - visible_rows(), 0))
	for i in mini(visible_rows(), list.size() - scroll):
		var index : int = i + scroll
		var r : Rect2 = Rect2(well.position.x + 1.0, well.position.y + 1.0 + i * ROW, well.size.x - 2.0, ROW)
		rects.append(r)
		if index == selected:
			draw_rect(r, skin.hover)
		var y : float = UiKit.baseline(font, r, 4)
		UiKit.label(self, font, Vector2(r.position.x + 3.0, y), list[index][0], 4, skin.text)
		var value : String = list[index][1]
		var waiting : bool = (list[index][2] as String) == "key:" + listening
		UiKit.label(self, font, Vector2(r.position.x, y), ("< %s >" % value) if index == selected and not value.is_empty() and not (list[index][2] as String).begins_with("key:") else value, 4, skin.accent if waiting or index == selected else skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3.0)
	if list.size() > visible_rows():
		var track : Rect2 = Rect2(well.end.x - 2.0, well.position.y + 1.0, 1.0, well.size.y - 2.0)
		draw_rect(track, Color(skin.line, 0.5))
		var knob : float = track.size.y * visible_rows() / list.size()
		draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - knob) * scroll / maxf(list.size() - visible_rows(), 1.0), 1.0, knob), skin.dim)
	backRect = Rect2(area.position.x + area.size.x * 0.5 - 18.0, area.end.y - 12.0, 36.0, 9.0)
	UiKit.button(self, font, skin, backRect, "Back", 4, true, backRect.has_point(get_local_mouse_position()))
	var help : String = "Press the new key (Esc cancels)" if not listening.is_empty() else "Click: change   Arrows: pick   Tab: next page"
	UiKit.label(self, font, Vector2(area.position.x, area.end.y + 5.0), help, 3, Color(1.0, 1.0, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
