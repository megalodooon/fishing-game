extends Control
class_name MenuHub

# The strip of tabs across the top of the screen while one of the player's
# own menus is open: bag, tacklebox, journal, recipes, skills, collections,
# quests, calendar, pets and the sea chart. Clicking a tab or pressing its
# key jumps straight to that menu, Tab reopens the last one, and the active
# menu's name and a close button sit at either end. Every menu keeps its own
# look; the strip ties them together and shows where everything is.
#
# A menu in the strip can have hub_open(), hub_close() and hub_shown(); the
# strip falls back on MenuPanel's open_menu(), close_menu() and shown. A menu
# with hub_available() stays out of the strip until it returns true (like the
# charm pouch before the first charm), so a new player isn't met with every
# tab at once.

const GROUP : StringName = &"menu_hubs"
# Room the menus leave free at the top of the screen for the strip.
const HEIGHT : float = 12.0
const COIN : Texture2D = preload("res://world/map/icons/coin.png")

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var menus : Array[Node] = []
@export var titles : PackedStringArray = PackedStringArray()
@export var icons : Array[Texture2D] = []
@export var actions : Array[StringName] = []
# Which tab Tab opens when none has been open yet.
@export var firstTab : int = 2
@export var tabWidth : float = 11.0
@export var tabGap : float = 1.0
@export var skin : MenuSkin

var current : int = -1
var last : int = -1
var hovered : int = -1
var closeHovered : bool = false
var rects : Array[Rect2] = []
var closeRect : Rect2
var mouse : Vector2 = Vector2(-100.0, -100.0)
var appear : float = 0.0
var marker : float = -1.0
var bounce : Array[float] = []
# Tabs with something new to see, like a quest to hand in.
var news : Array[bool] = []
var tick : float = 0.0
var availability : Array[bool] = []
# Dims the world and the HUD behind open menus. It sits in the HUD just
# before the hotbar, so the menus themselves stay bright.
var backdrop : Control
var dim : float = 0.0
@export var dimColor : Color = Color(0.02, 0.04, 0.08, 0.62)
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(PRESET_TOP_LEFT)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	process_mode = PROCESS_MODE_ALWAYS
	if not skin:
		skin = MenuSkin.default_skin()
	bounce.resize(menus.size())
	bounce.fill(0.0)
	news.resize(menus.size())
	news.fill(false)
	backdrop = Control.new()
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.draw.connect(draw_backdrop)
	place_backdrop.call_deferred()
	ui.laid_out.connect(fit)
	fit()

func place_backdrop() -> void:
	get_parent().add_child(backdrop)
	get_parent().move_child(backdrop, ui.get_index())
	fit()

func draw_backdrop() -> void:
	if dim > 0.0:
		backdrop.draw_rect(Rect2(Vector2.ZERO, backdrop.size), Color(dimColor, dimColor.a * dim))

# How much the world behind should be dimmed: fully for the big menus and
# counters, a little for the bag, which is played with.
func dim_goal() -> float:
	if current == 0:
		return 0.35
	if current > 0:
		return 1.0
	var counter : CounterUI = CounterUI.find(get_tree())
	if counter and counter.shown:
		return 1.0
	var pets : PetsUI = PetsUI.find(get_tree())
	return 1.0 if pets and pets.shown else 0.0

static func find(tree : SceneTree) -> MenuHub:
	return tree.get_first_node_in_group(GROUP) as MenuHub if tree else null

# Where a menu's panel should start: under the strip when there is one.
static func top_of(tree : SceneTree, fallback : float) -> float:
	return HEIGHT + 1.0 if find(tree) else fallback

# A menu opened on its own (like a shop's quest board): the other menus in
# the strip close so they don't pile up.
static func menu_opened(tree : SceneTree, menu : Node) -> void:
	var hub : MenuHub = find(tree)
	if hub:
		hub.close_others(menu)

# Whether a key belongs to the strip, so menus that take every key let it by.
static func is_hub_key(tree : SceneTree, event : InputEvent) -> bool:
	var hub : MenuHub = find(tree)
	if not hub or not event is InputEventKey:
		return false
	if event.is_action("hub"):
		return true
	for action in hub.actions:
		if event.is_action(action):
			return true
	return false

func fit() -> void:
	scale = ui.scale
	size = ui.size
	if backdrop:
		backdrop.scale = ui.scale
		backdrop.size = ui.size
	refresh_availability()
	var count : int = availability.count(true)
	var width : float = count * tabWidth + (count - 1) * tabGap
	var x : float = floorf((size.x - width) * 0.5)
	rects.clear()
	for i in menus.size():
		if availability[i]:
			rects.append(Rect2(x, 1.0, tabWidth, HEIGHT - 1.0))
			x += tabWidth + tabGap
		else:
			rects.append(Rect2(-100.0, -100.0, 0.0, 0.0))
	closeRect = Rect2(size.x - 11.0, 2.0, 9.0, 9.0)
	queue_redraw()

# Whether each tab is in the strip. Returns whether anything changed.
func refresh_availability() -> bool:
	var fresh : Array[bool] = []
	for menu in menus:
		fresh.append(menu == null or not menu.has_method("hub_available") or bool(menu.call("hub_available")))
	if fresh == availability:
		return false
	availability = fresh
	return true

func is_open(index : int) -> bool:
	var menu : Node = menus[index] if index >= 0 and index < menus.size() else null
	if not menu:
		return false
	if menu.has_method("hub_shown"):
		return menu.call("hub_shown")
	return menu is MenuPanel and (menu as MenuPanel).shown

func open_tab(index : int) -> void:
	var menu : Node = menus[index]
	if not menu:
		return
	if menu.has_method("hub_open"):
		menu.call("hub_open")
	elif menu is MenuPanel:
		(menu as MenuPanel).open_menu()

func close_tab(index : int) -> void:
	var menu : Node = menus[index]
	if not menu or not is_open(index):
		return
	if menu.has_method("hub_close"):
		menu.call("hub_close")
	elif menu.has_method("close"):
		menu.call("close")

func close_others(keep : Node) -> void:
	for i in menus.size():
		if menus[i] != keep:
			close_tab(i)

func switch_to(index : int) -> void:
	if index < 0 or index >= menus.size() or not usable():
		return
	if index < availability.size() and not availability[index]:
		return
	for i in menus.size():
		if i != index:
			close_tab(i)
	open_tab(index)
	if is_open(index):
		last = index
		bounce[index] = 1.0
		set_process(true)

func close_all() -> void:
	for i in menus.size():
		close_tab(i)

# Menus can't be switched while asleep, fishing a minigame or talking.
func usable() -> bool:
	if not player or player.asleep:
		return false
	if player.minigameScreen and player.minigameScreen.shown:
		return false
	var talk : DialogueUI = DialogueUI.find(get_tree())
	if talk and talk.busy():
		return false
	return not get_tree().paused

func active() -> int:
	for i in menus.size():
		if is_open(i):
			return i
	return -1

func _unhandled_input(event : InputEvent) -> void:
	# Keys, and the actions held items send when used (like the journal).
	if not (event is InputEventKey or event is InputEventAction) or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("hub"):
		get_viewport().set_input_as_handled()
		if current >= 0:
			close_all()
		else:
			switch_to(last if last >= 0 else firstTab)
		return
	for i in actions.size():
		if event.is_action_pressed(actions[i]):
			get_viewport().set_input_as_handled()
			if i == current:
				close_tab(i)
			else:
				switch_to(i)
			return

func _has_point(point : Vector2) -> bool:
	if current < 0:
		return false
	for area in rects:
		if area.has_point(point):
			return true
	return closeRect.has_point(point)

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse = Vector2(-100.0, -100.0)
		hovered = -1
		closeHovered = false
		queue_redraw()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		var was : int = hovered
		hovered = -1
		for i in rects.size():
			if rects[i].has_point(mouse):
				hovered = i
		closeHovered = closeRect.has_point(mouse)
		if hovered != was:
			if hovered >= 0:
				bounce[hovered] = maxf(bounce[hovered], 0.5)
			set_process(true)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if closeHovered:
			close_all()
		elif hovered >= 0 and hovered != current:
			switch_to(hovered)
		accept_event()

func _process(delta : float) -> void:
	var now : int = active()
	if now != current:
		if now >= 0 and current < 0:
			appear = 0.0
		current = now
		if now >= 0:
			last = now
			if marker < 0.0:
				marker = rects[now].position.x
		queue_redraw()
	var goal : float = dim_goal()
	if dim != goal:
		dim = move_toward(dim, goal, delta * 6.0)
		backdrop.queue_redraw()
	tick += delta
	if tick >= 0.5:
		tick = 0.0
		refresh_news()
		if refresh_availability():
			fit()
	if current < 0:
		marker = -1.0
		return
	var moving : bool = false
	appear = minf(appear + delta * 6.0, 1.0)
	var home : float = rects[current].position.x
	marker = lerpf(marker, home, 1.0 - exp(-18.0 * delta))
	if absf(marker - home) < 0.05:
		marker = home
	else:
		moving = true
	for i in bounce.size():
		if bounce[i] > 0.0:
			bounce[i] = maxf(bounce[i] - delta * 3.0, 0.0)
			moving = true
	if moving or appear < 1.0:
		queue_redraw()

# Tabs get a dot when there's something waiting in them.
func refresh_news() -> void:
	var changed : bool = false
	for i in menus.size():
		var menu : Node = menus[i]
		var has : bool = menu != null and menu.has_method("hub_news") and menu.call("hub_news")
		if has != news[i]:
			news[i] = has
			changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	if current < 0:
		return
	var font : Font = ui.font
	var drop : float = roundf((1.0 - UiKit.pop(appear)) * -HEIGHT)
	draw_set_transform(Vector2(0.0, drop))
	var band : Rect2 = Rect2(0.0, 0.0, size.x, HEIGHT)
	draw_rect(band, Color(0.03, 0.05, 0.09, 0.92))
	draw_rect(Rect2(0.0, HEIGHT - 1.0, size.x, 1.0), Color(0.3, 0.42, 0.57))
	var title : String = titles[current] if current < titles.size() else ""
	UiKit.label(self, font, Vector2(3.0, UiKit.baseline(font, band, ui.statSize)), title.to_upper(), ui.statSize, skin.title, HORIZONTAL_ALIGNMENT_LEFT, rects[0].position.x - 5.0)
	if marker >= 0.0:
		draw_rect(Rect2(marker, HEIGHT - 2.0, tabWidth, 2.0), skin.title)
	for i in rects.size():
		var area : Rect2 = rects[i]
		if area.size.x <= 0.0:
			continue
		var on : bool = i == current
		var hover : bool = i == hovered
		var lift : float = roundf(sin(bounce[i] * PI) * 1.5)
		var shown : Rect2 = Rect2(area.position - Vector2(0.0, lift + (1.0 if on else 0.0)), area.size + Vector2(0.0, 1.0 if on else 0.0))
		UiKit.box(self, skin.tabOn if on else (skin.tabHover if hover else skin.tab), shown)
		var icon : Texture2D = icons[i] if i < icons.size() else null
		if icon:
			var at : Vector2 = (shown.get_center() - icon.get_size() * 0.5 + Vector2(0.0, 0.5)).floor()
			draw_texture(icon, at, Color.WHITE if on or hover else Color(0.8, 0.85, 0.95, 0.8))
		if news[i]:
			draw_rect(Rect2(shown.end.x - 3.0, shown.position.y + 1.0, 2.0, 2.0), UiKit.NEW_COLOR)
	# The player's coins, left of the close button.
	var coins : String = UiKit.coins_text(player.wallet.coins)
	var coinsX : float = closeRect.position.x - 3.0 - UiKit.text_width(font, coins, ui.statSize)
	UiKit.label(self, font, Vector2(coinsX, UiKit.baseline(font, band, ui.statSize)), coins, ui.statSize, ui.selectedColor)
	draw_texture(COIN, Vector2(coinsX - COIN.get_width() - 1.0, floorf((HEIGHT - COIN.get_height()) * 0.5)))
	UiKit.box(self, skin.tabHover if closeHovered else skin.tab, closeRect)
	var cross : Rect2 = closeRect.grow(-2.5)
	draw_line(cross.position, cross.end, skin.text, 1.0)
	draw_line(Vector2(cross.end.x, cross.position.y), Vector2(cross.position.x, cross.end.y), skin.text, 1.0)
	draw_set_transform(Vector2.ZERO)
	if hovered >= 0 and hovered < titles.size():
		var key : String = key_name(actions[hovered]) if hovered < actions.size() else ""
		var lines : PackedStringArray = PackedStringArray(["Key", key]) if not key.is_empty() else PackedStringArray()
		ui.paint_tip(self, rects[hovered].get_center() + Vector2(-4.0, 5.0), titles[hovered], skin.title, lines, ui.tip_size(titles[hovered], lines))
	elif closeHovered:
		var lines : PackedStringArray = PackedStringArray(["Key", "Esc"])
		ui.paint_tip(self, closeRect.get_center() + Vector2(-20.0, 5.0), "Close", skin.text, lines, ui.tip_size("Close", lines))

static func key_name(action : StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code : Key = (event as InputEventKey).physical_keycode
			if code == KEY_NONE:
				code = (event as InputEventKey).keycode
			return OS.get_keycode_string(code)
	return ""
