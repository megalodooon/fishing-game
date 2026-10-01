extends MenuPanel
class_name CounterUI

# The menu every Counter opens (shops, the vending machine, crafters, the
# aquarium, quest boards): a header with the counter's portrait, title and
# the coins, tabs when the counter has them, its rows in a list on the left
# and the pointed row's card on the right with a button that does the thing.
# Clicking a row does it too. Each counter picks its look (Counter.look):
# shops are wooden counters, quest boards cork, the aquarium glass. F, Esc or
# right click close it, and so does opening the backpack.

const GROUP : StringName = &"counter_uis"

#------------------------#
@export var player : Player
@export var ui : InventoryUI
# Closed when the counter opens.
@export var menus : Array[Control] = []
@export var coinIcon : Texture2D

@export_group("Layout")
@export var maxWidth : int = 180
@export var listWidth : int = 80
@export var padding : int = 4
@export var top : int = 3
# Room left free under the panel for the hotbar.
@export var bottom : int = 17
@export var headerHeight : int = 15
@export var tabHeight : int = 9
@export var buttonHeight : int = 10
@export var iconBox : int = 20
@export var messageTime : float = 2.2
@export var coinSpeed : float = 6.0

var counter : Counter
var skin : MenuSkin
var list : ListMenu
var panelRect : Rect2
var infoRect : Rect2
var buttonRect : Rect2
var tabRects : Array[Rect2] = []
var pointedValue : Variant = null
var details : Dictionary = {}
var message : String = ""
var messageGood : bool = true
var messageLeft : float = 0.0
var mouse : Vector2 = Vector2(-100.0, -100.0)
var pressFlash : float = 0.0
var holding : bool = false
var shownCoins : float = 0.0
var coinBump : float = 0.0
var detailAge : float = 1.0
var sparkles : Sparkles = Sparkles.new()
#------------------------#


func _ready() -> void:
	super()
	add_to_group(GROUP)
	set_anchors_preset(PRESET_TOP_LEFT)
	list = ListMenu.new()
	list.ui = ui
	list.headerHeight = 8
	list.slide = Vector2.ZERO
	add_child(list)
	list.chosen.connect(on_chosen)
	list.pointed.connect(on_pointed)
	ui.laid_out.connect(fit)
	ui.opened.connect(close)
	player.inventory.changed.connect(refresh)
	if player.wallet:
		player.wallet.changed.connect(coins_changed)
		shownCoins = player.wallet.coins
	set_process(false)
	fit()

static func find(tree : SceneTree) -> CounterUI:
	return tree.get_first_node_in_group(GROUP) as CounterUI

func fit() -> void:
	scale = ui.scale
	var width : float = minf(ui.size.x - 6.0, maxWidth)
	var y : float = MenuHub.top_of(get_tree(), top) if is_inside_tree() else float(top)
	panelRect = Rect2(floorf((ui.size.x - width) * 0.5), y, width, ui.size.y - y - bottom)
	place(Rect2(Vector2.ZERO, ui.size))
	layout()

func layout() -> void:
	var bodyTop : float = panelRect.position.y + padding + headerHeight
	tabRects.clear()
	var names : PackedStringArray = counter.tabs(player) if counter else PackedStringArray()
	if not names.is_empty():
		var x : float = panelRect.position.x + padding + 1.0
		for tabName in names:
			var width : float = ui.font.get_string_size(tabName, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 10.0
			tabRects.append(Rect2(x, bodyTop, width, tabHeight))
			x += width + 1.0
		bodyTop += tabHeight - 1.0
	var body : Rect2 = Rect2(panelRect.position.x + padding, bodyTop, panelRect.size.x - padding * 2.0, panelRect.end.y - padding - bodyTop)
	list.searchable = counter != null and counter.searchable()
	list.place(Rect2(body.position, Vector2(listWidth, body.size.y)))
	infoRect = Rect2(body.position.x + listWidth + 2.0, body.position.y, body.size.x - listWidth - 2.0, body.size.y)
	buttonRect = Rect2(infoRect.position.x + 3.0, infoRect.end.y - buttonHeight - 3.0, infoRect.size.x - 6.0, buttonHeight)
	queue_redraw()

func _has_point(point : Vector2) -> bool:
	return shown and panelRect.grow(1.0).has_point(point)

func open_counter(which : Counter, who : Player) -> void:
	for menu in menus:
		if menu and menu.has_method("close"):
			menu.call("close")
	counter = which
	player = who
	skin = counter.look()
	list.skin = skin
	player.frozen = true
	message = ""
	pointedValue = null
	shownCoins = float(player.wallet.coins) if player.wallet else 0.0
	counter.opened(player)
	list.reset_scroll()
	fit()
	refresh()
	list.open_menu()
	open_menu()
	MenuHub.menu_opened(get_tree(), counter)

func close() -> void:
	if not shown:
		return
	close_menu()
	list.close_menu()
	player.frozen = false
	counter = null

func refresh() -> void:
	if not counter:
		return
	var rows : Array[Dictionary] = counter.rows(player)
	var pinned : Array[Dictionary] = counter.pinned_rows(player)
	list.set_rows(rows, pinned)
	if pointedValue == null or not has_row(rows + pinned, pointedValue):
		pointedValue = first_value(pinned) if rows.is_empty() else first_value(rows)
	details = counter.info(player, pointedValue)
	queue_redraw()

func first_value(rows : Array[Dictionary]) -> Variant:
	for row in rows:
		if not row.get("header", false):
			return row.value
	return null

func has_row(rows : Array[Dictionary], value : Variant) -> bool:
	for row in rows:
		if row.has("value") and typeof(row.value) == typeof(value) and row.value == value:
			return true
	return false

func on_pointed(value : Variant) -> void:
	if value != null and not is_same(value, pointedValue):
		pointedValue = value
		detailAge = 0.0
		set_process(true)
	details = counter.info(player, pointedValue) if counter and pointedValue != null else {}
	queue_redraw()

func on_chosen(value : Variant) -> void:
	if not counter:
		return
	var from : Counter = counter
	var said : String = counter.choose(player, value)
	# Choosing can close this menu, like a handed-in quest starting its scene.
	if counter != from:
		return
	if not said.is_empty():
		say(said, counter.lastGood)
		if counter.lastGood:
			sparkles.burst(buttonRect.get_center(), skin.accent, 14)
		else:
			list.flash(value)
	pointedValue = value
	pressFlash = 0.15
	set_process(true)
	refresh()

func switch_tab(index : int) -> void:
	if not counter or index == counter.tab:
		return
	counter.tab = index
	pointedValue = null
	list.reset_scroll()
	refresh()

func say(text : String, good : bool) -> void:
	message = text
	messageGood = good
	messageLeft = messageTime
	set_process(true)
	queue_redraw()

func coins_changed() -> void:
	coinBump = 1.0
	set_process(true)

func _unhandled_input(event : InputEvent) -> void:
	if not shown:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("hub") or event.is_action_pressed("backpack"):
		get_viewport().set_input_as_handled()
		close()
	elif not tabRects.is_empty() and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		switch_tab(posmod(counter.tab + (1 if event.is_action_pressed("ui_right") else -1), tabRects.size()))

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		holding = false
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in tabRects.size():
				if tabRects[i].has_point(event.position):
					switch_tab(i)
			if buttonRect.has_point(event.position) and button_live():
				holding = true
				on_chosen(pointedValue)
		accept_event()

func button_live() -> bool:
	return pointedValue != null and details.get("enabled", true) and not String(details.get("action", "")).is_empty()

func _process(delta : float) -> void:
	messageLeft = maxf(messageLeft - delta, 0.0)
	pressFlash = maxf(pressFlash - delta, 0.0)
	coinBump = maxf(coinBump - delta * 3.0, 0.0)
	detailAge = minf(detailAge + delta * 7.0, 1.0)
	var goal : float = float(player.wallet.coins) if player.wallet else 0.0
	shownCoins = lerpf(shownCoins, goal, 1.0 - exp(-coinSpeed * delta))
	if absf(shownCoins - goal) < 0.5:
		shownCoins = goal
	var sparkling : bool = sparkles.update(delta)
	queue_redraw()
	if messageLeft <= 0.0 and pressFlash <= 0.0 and coinBump <= 0.0 and detailAge >= 1.0 and shownCoins == goal and not sparkling:
		set_process(false)

func _draw() -> void:
	if not counter:
		return
	var font : Font = ui.font
	draw_rect(Rect2(panelRect.position + Vector2(2.0, 2.0), panelRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panelRect)
	var textX : float = panelRect.position.x + padding + 1.0
	var headTop : float = panelRect.position.y + padding - 1.0
	if counter.portrait:
		var box : Rect2 = Rect2(Vector2(textX, headTop), Vector2(headerHeight - 1.0, headerHeight - 1.0))
		UiKit.box(self, skin.well, box)
		ui.draw_icon(self, counter.portrait, box.get_center(), Color.WHITE, Color(0.0, 0.0, 0.0, 0.0), minf(1.0, (box.size.y - 2.0) / maxf(counter.portrait.get_width(), counter.portrait.get_height())))
		textX = box.end.x + 3.0
	var right : float = draw_coins(font, headTop) if player.wallet and counter.shows_coins() else panelRect.end.x - padding
	UiKit.label(self, font, Vector2(textX, headTop + 1.0 + font.get_ascent(ui.titleSize)), counter.title, ui.titleSize, skin.title, HORIZONTAL_ALIGNMENT_LEFT, right - textX - 2.0, skin.outline)
	var sub : String = counter.subtitle(player)
	if not sub.is_empty():
		UiKit.label(self, font, Vector2(textX, headTop + ui.titleSize + 3.0 + font.get_ascent(ui.statSize)), sub, ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, right - textX - 2.0)
	draw_tabs(font)
	draw_info(font)
	sparkles.draw(self)

# The coin pill in the header's right corner, counting toward the wallet.
# Returns where it starts.
func draw_coins(font : Font, y : float) -> float:
	var coins : String = UiKit.coins_text(roundi(shownCoins))
	var width : float = UiKit.text_width(font, coins, ui.statSize + 1)
	var pill : Rect2 = Rect2(panelRect.end.x - padding - width - 12.0, y + 1.0, width + 11.0, 9.0)
	UiKit.box(self, skin.well, pill)
	if coinIcon:
		var bounce : float = roundf(sin(coinBump * PI) * 1.5)
		draw_texture(coinIcon, Vector2(pill.position.x + 2.0, pill.position.y + floorf((pill.size.y - coinIcon.get_height()) * 0.5) - bounce))
	var color : Color = skin.accent.lerp(Color.WHITE, coinBump * 0.6)
	UiKit.label(self, font, Vector2(pill.end.x - width - 2.0, UiKit.baseline(font, pill, ui.statSize + 1)), coins, ui.statSize + 1, color)
	return pill.position.x

func draw_tabs(font : Font) -> void:
	var names : PackedStringArray = counter.tabs(player)
	for i in mini(tabRects.size(), names.size()):
		var area : Rect2 = tabRects[i]
		var active : bool = i == counter.tab
		var hover : bool = area.has_point(mouse)
		var shown_area : Rect2 = area if active else area.grow_individual(0.0, -1.0, 0.0, 0.0)
		UiKit.box(self, skin.tabOn if active else (skin.tabHover if hover else skin.tab), shown_area)
		UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, shown_area, ui.statSize)), names[i], ui.statSize, Color(0.94, 0.97, 1.0) if active else Color(0.72, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, area.size.x)

func draw_info(font : Font) -> void:
	UiKit.box(self, skin.well, infoRect)
	var inner : Rect2 = infoRect.grow(-padding + 1.0)
	var shift : float = (1.0 - UiKit.pop(detailAge)) * 3.0
	var y : float = inner.position.y + shift
	if details.is_empty():
		UiKit.label(self, font, Vector2(inner.position.x, inner.get_center().y), "Nothing here", ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x)
	else:
		var icon : Texture2D = details.get("icon")
		var textX : float = inner.position.x
		var titleColor : Color = skin.readable(details.get("color", skin.text))
		if icon:
			var box : Rect2 = Rect2(Vector2(inner.position.x, y), Vector2(iconBox, iconBox))
			UiKit.box(self, skin.card, box)
			draw_rect(Rect2(box.position.x + 1.0, box.end.y - 4.0, box.size.x - 2.0, 3.0), Color(details.get("color", skin.text), 0.25))
			var zoom : float = minf(2.0, floorf((iconBox - 4.0) / maxf(icon.get_width(), icon.get_height()) * 2.0) * 0.5)
			ui.draw_icon(self, icon, box.get_center(), details.get("tint", Color.WHITE), details.get("outline", ui.outlineColor), maxf(zoom, 0.5))
			textX += iconBox + 3.0
		var title : String = details.get("title", "")
		for line in ui.wrap_lines(title, inner.end.x - textX, ui.titleSize):
			UiKit.label(self, font, Vector2(textX, y + font.get_ascent(ui.titleSize)), line, ui.titleSize, titleColor)
			y += ui.titleSize + 1.0
		var tag : String = details.get("tag", "")
		if not tag.is_empty():
			UiKit.label(self, font, Vector2(textX, y + font.get_ascent(ui.statSize)), tag, ui.statSize, Color(titleColor, 0.8), HORIZONTAL_ALIGNMENT_LEFT, inner.end.x - textX)
			y += ui.statSize + 1.0
		y = maxf(y, inner.position.y + shift + (float(iconBox) if icon else 0.0)) + 2.0
		var rows : Array = details.get("lines", [])
		var rowParts : Array[PackedStringArray] = []
		var rowsHeight : float = 2.0 if not rows.is_empty() else 0.0
		for row in rows:
			rowParts.append(row_parts(font, row, inner.size.x))
			rowsHeight += rowParts.back().size() * (ui.statSize + 1.0)
		var textEnd : float = buttonRect.position.y - 2.0 if not String(details.get("action", "")).is_empty() else inner.end.y
		var text : String = details.get("text", "")
		if not text.is_empty():
			# The rows (prices, stats, what's needed) come first: when both
			# don't fit, the description gives up its last lines.
			var wrapped : PackedStringArray = ui.wrap_lines(text, inner.size.x, ui.statSize)
			var room : int = maxi(floori((textEnd - y - rowsHeight - 1.0) / (ui.statSize + 1.0)), 1)
			for i in mini(wrapped.size(), room):
				var line : String = wrapped[i]
				if i == room - 1 and wrapped.size() > room and line.contains(" "):
					line = line.substr(0, line.rfind(" ")).rstrip(".,;:") + "..."
				UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), line, ui.statSize, skin.dim)
				y += ui.statSize + 1.0
			y += 1.0
		if not rows.is_empty():
			draw_rect(Rect2(inner.position.x, y, inner.size.x, 1.0), skin.line)
			y += 2.0
		var shade : bool = false
		for r in rows.size():
			if y + ui.statSize > textEnd:
				break
			var row : Array = rows[r]
			var parts : PackedStringArray = rowParts[r]
			if shade:
				draw_rect(Rect2(inner.position.x - 1.0, y - 0.5, inner.size.x + 2.0, parts.size() * (ui.statSize + 1.0)), skin.shade)
			shade = not shade
			var color : Color = skin.readable(row[2]) if row.size() > 2 else skin.text
			UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), row[0], ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
			for part in parts:
				if y + ui.statSize > textEnd:
					break
				UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), part, ui.statSize, color, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
				y += ui.statSize + 1.0
		draw_button(font)
	if messageLeft > 0.0:
		var fade : float = clampf(messageLeft / 0.4, 0.0, 1.0)
		var rise : float = (1.0 - UiKit.pop(clampf((messageTime - messageLeft) / 0.25, 0.0, 1.0))) * 3.0
		var at : float = buttonRect.position.y - ui.statSize - 5.0 + rise
		var width : float = minf(UiKit.text_width(font, message, ui.statSize) + 8.0, inner.size.x + 2.0)
		var toast : Rect2 = Rect2(roundf(inner.get_center().x - width * 0.5), at - 1.0, width, ui.statSize + 3.0)
		draw_rect(toast, Color(0.03, 0.05, 0.09, 0.9 * fade))
		draw_rect(Rect2(toast.position.x, toast.end.y - 1.0, toast.size.x, 1.0), Color(skin.good if messageGood else skin.bad, fade))
		UiKit.label(self, font, Vector2(toast.position.x, UiKit.baseline(font, toast, ui.statSize)), message, ui.statSize, Color(Color(0.56, 0.93, 0.44) if messageGood else Color(0.95, 0.45, 0.4), fade), HORIZONTAL_ALIGNMENT_CENTER, toast.size.x)

# A row's value, or the value wrapped under its label when both don't fit on
# one line.
func row_parts(font : Font, row : Array, width : float) -> PackedStringArray:
	var labelWidth : float = font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x
	if labelWidth + font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x + 3.0 <= width:
		return PackedStringArray([row[1]])
	var parts : PackedStringArray = ui.wrap_lines(row[1], width - 4.0, ui.statSize)
	parts.insert(0, "")
	return parts

func draw_button(font : Font) -> void:
	var action : String = details.get("action", "")
	if action.is_empty():
		return
	var enabled : bool = details.get("enabled", true)
	UiKit.button(self, font, skin, buttonRect, action, ui.statSize, enabled, buttonRect.has_point(mouse), (holding or pressFlash > 0.0) and enabled)
