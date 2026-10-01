extends MenuPanel
class_name PetsUI

# The pets screen: a grid of pet cards on the left and the picked pet up
# close on the right, bobbing on a little stand, with its level, how many
# fish until the next one, its buffs now and at the next level, and a button
# to buy it, take it along or send it home. Opened with P or from the pause
# menu for your own pets, and by pet shops to sell theirs.

const GROUP : StringName = &"pets_uis"

#------------------------#
@export var player : Player
@export var ui : InventoryUI
# Every pet in the game, for the own-pets view. Ones not owned yet show as
# silhouettes.
@export var catalog : Array[PetData] = []
@export var coinIcon : Texture2D
@export var menus : Array[Control] = []
@export var skin : MenuSkin

@export_group("Layout")
@export var maxWidth : float = 176.0
@export var cardSize : float = 22.0
@export var columns : int = 3
@export var headerHeight : float = 13.0

@export_group("Colors")
@export var headerColor : Color = Color(0.09, 0.14, 0.22, 1.0)
@export var goodColor : Color = Color(0.56, 0.93, 0.44)
@export var buttonColor : Color = Color(0.22, 0.46, 0.3, 1.0)
@export var buttonHover : Color = Color(0.3, 0.6, 0.38, 1.0)
@export var buttonOff : Color = Color(0.18, 0.22, 0.3, 1.0)
@export var silhouette : Color = Color(0.02, 0.04, 0.08, 0.75)

var shop : PetShop
var pets : Array[PetData] = []
var picked : PetData
var hovered : PetData
var panel : Rect2
var detail : Rect2
var buttonRect : Rect2
var cardRects : Array[Rect2] = []
var mouse : Vector2 = Vector2(-100.0, -100.0)
var time : float = 0.0
var message : String = ""
var messageColor : Color = Color.WHITE
var messageLeft : float = 0.0
#------------------------#


func _ready() -> void:
	super()
	add_to_group(GROUP)
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/wood.tres") as MenuSkin
	ui.laid_out.connect(fit)
	ui.opened.connect(close)
	fit()

static func find(tree : SceneTree) -> PetsUI:
	return tree.get_first_node_in_group(GROUP) as PetsUI

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	var width : float = minf(ui.size.x - 8.0, maxWidth)
	var y : float = MenuHub.top_of(get_tree(), 3.0) if is_inside_tree() else 3.0
	panel = Rect2(floorf((ui.size.x - width) * 0.5), y, width, ui.size.y - y - 18.0)
	var gridWidth : float = columns * (cardSize + 1.0) + 8.0
	detail = Rect2(panel.position.x + gridWidth, panel.position.y + headerHeight + 3.0, panel.size.x - gridWidth - 6.0, panel.size.y - headerHeight - 8.0)
	buttonRect = Rect2(detail.position.x + 3.0, detail.end.y - 12.0, detail.size.x - 6.0, 9.0)
	queue_redraw()

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(1.0).has_point(point)

# Out of the hub strip until there's a pet.
func hub_available() -> bool:
	return player != null and player.progress != null and not player.progress.pets.is_empty()

func hub_open() -> void:
	open_own(player)

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown and shop == null

func open_own(who : Player) -> void:
	shop = null
	pets = catalog.duplicate()
	open_for(who)

func open_shop(which : PetShop, who : Player) -> void:
	shop = which
	pets = which.pets.duplicate()
	open_for(who)

func open_for(who : Player) -> void:
	for menu in menus:
		if menu and menu.has_method("close"):
			menu.call("close")
	player = who
	player.frozen = true
	picked = player.progress.activePet if pets.has(player.progress.activePet) else (pets[0] if not pets.is_empty() else null)
	message = ""
	open_menu()

func close() -> void:
	if not shown:
		return
	close_menu()
	player.frozen = false

func owned(pet : PetData) -> bool:
	return player.progress.pets.has(pet)

func _unhandled_input(event : InputEvent) -> void:
	if shown and (event.is_action_pressed("ui_cancel") or (shop != null and event.is_action_pressed("interact"))):
		get_viewport().set_input_as_handled()
		close()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		hovered = null
		for i in cardRects.size():
			if cardRects[i].has_point(mouse):
				hovered = pets[i]
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for i in cardRects.size():
				if cardRects[i].has_point(event.position):
					picked = pets[i]
					message = ""
			if picked and buttonRect.has_point(event.position):
				act()
	accept_event()

func action() -> Array:
	if not picked:
		return ["", false]
	if player.progress.activePet == picked:
		return ["Send home", true]
	if owned(picked):
		return ["Take along", true]
	if shop:
		return ["Buy for $%d" % picked.price if player.wallet.can_afford(picked.price) else "Not enough coins", player.wallet.can_afford(picked.price)]
	return ["Sold at pet shops", false]

func act() -> void:
	if not action()[1]:
		return
	if player.progress.activePet == picked:
		player.progress.set_active_pet(null)
		say("%s went home" % picked.displayName, ui.textColor)
	elif owned(picked):
		player.progress.set_active_pet(picked)
		say("%s is with you!" % picked.displayName, goodColor)
	elif shop and player.wallet.spend(picked.price):
		player.progress.pets.append(picked)
		player.progress.set_active_pet(picked)
		say("%s is yours!" % picked.displayName, goodColor)

func say(text : String, color : Color) -> void:
	message = text
	messageColor = color
	messageLeft = 2.2

func _process(delta : float) -> void:
	if shown:
		time += delta
		messageLeft = maxf(messageLeft - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	if not player:
		return
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.35))
	UiKit.box(self, skin.frame, panel)
	var band : Rect2 = Rect2(panel.position + Vector2(4.0, 3.0), Vector2(panel.size.x - 8.0, headerHeight - 2.0))
	draw_string(font, Vector2(band.position.x + 1.0, band.position.y + 1.0 + font.get_ascent(ui.titleSize)), shop.title if shop else "Pets", HORIZONTAL_ALIGNMENT_LEFT, -1, ui.titleSize, skin.title)
	var sub : String = "Pets grow with every fish caught while they're out" if not shop else "Pick a pet to see what it does"
	draw_string(font, Vector2(band.position.x + 3.0, band.position.y + ui.titleSize + 4.0 + font.get_ascent(ui.statSize) - 1.0), sub, HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 40.0, ui.statSize - 1, skin.dim)
	var coins : String = "%d" % player.wallet.coins
	var coinsWidth : float = font.get_string_size(coins, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize + 1).x
	draw_string(font, Vector2(band.end.x - coinsWidth - 3.0, band.position.y + 3.0 + font.get_ascent(ui.statSize + 1)), coins, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize + 1, ui.selectedColor)
	if coinIcon:
		draw_texture(coinIcon, Vector2(band.end.x - coinsWidth - 5.0 - coinIcon.get_width(), band.position.y + 3.0))
	draw_cards(font)
	draw_detail(font)

func draw_cards(font : Font) -> void:
	cardRects.clear()
	var start : Vector2 = Vector2(panel.position.x + 6.0, panel.position.y + headerHeight + 3.0)
	# Shrink the cards when there are more rows than fit the panel.
	var rows : int = ceili(float(pets.size()) / columns)
	var card : float = minf(cardSize, floorf((panel.end.y - 5.0 - start.y) / maxf(rows, 1) - 1.0))
	for i in pets.size():
		var pet : PetData = pets[i]
		@warning_ignore("integer_division")
		var area : Rect2 = Rect2(start + Vector2((i % columns) * (card + 1.0), (i / columns) * (card + 1.0)), Vector2(card, card))
		cardRects.append(area)
		var isOut : bool = player.progress.activePet == pet
		var known : bool = owned(pet) or shop != null
		UiKit.box(self, skin.card, area)
		if isOut or pet == picked or pet == hovered:
			UiKit.outline(self, area, goodColor if isOut else (skin.title if pet == picked else skin.dim))
		if pet and pet.sprite:
			var bob : float = sin(time * 6.0) * 0.7 if pet == hovered or pet == picked else 0.0
			var zoom : float = minf(1.0, (cardSize - 6.0) / maxf(pet.sprite.get_width(), pet.sprite.get_height()))
			var at : Vector2 = area.get_center() + Vector2(0.0, -1.0 + bob)
			if known:
				ui.draw_icon(self, pet.sprite, at, Color.WHITE, ui.outlineColor, zoom)
			else:
				ui.draw_silhouette(self, pet.sprite, at, Color(0.1, 0.06, 0.04, 0.8), zoom)
		if owned(pet):
			var level : String = "%d" % player.progress.pet_level(pet)
			draw_string(font, Vector2(area.end.x - 5.0, area.end.y - 2.0), level, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.selectedColor)
		elif shop:
			draw_string(font, Vector2(area.position.x, area.end.y - 2.0), "$%d" % pet.price, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, ui.statSize - 1, Color(1.0, 0.9, 0.4) if player.wallet.can_afford(pet.price) else ui.blockedColor)

func draw_detail(font : Font) -> void:
	UiKit.box(self, skin.well, detail)
	if not picked:
		draw_string(font, Vector2(detail.position.x, detail.get_center().y), "No pets yet", HORIZONTAL_ALIGNMENT_CENTER, detail.size.x, ui.statSize, ui.dimColor)
		return
	var known : bool = owned(picked) or shop != null
	var stand : Vector2 = Vector2(detail.position.x + 20.0, detail.position.y + 22.0)
	draw_set_transform(stand + Vector2(0.0, 7.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var hover : float = (sin(time * 3.0) * 1.5 - 3.0) if picked.flies else absf(sin(time * 4.0)) * -1.5
	if picked.glows and known:
		draw_circle(stand + Vector2(0.0, hover), 10.0, Color(picked.glowColor, 0.12 + 0.05 * sin(time * 2.0)))
	var zoom : float = minf(2.0, 26.0 / maxf(picked.sprite.get_width(), picked.sprite.get_height()))
	if known:
		ui.draw_icon(self, picked.sprite, stand + Vector2(0.0, hover), Color.WHITE, ui.outlineColor, zoom)
	else:
		ui.draw_silhouette(self, picked.sprite, stand + Vector2(0.0, hover), Color(0.1, 0.06, 0.04, 0.8), zoom)
	var textX : float = detail.position.x + 40.0
	var y : float = detail.position.y + 3.0
	var isOut : bool = player.progress.activePet == picked
	draw_string(font, Vector2(textX, y + font.get_ascent(ui.titleSize)), picked.displayName if known else "???", HORIZONTAL_ALIGNMENT_LEFT, detail.end.x - textX - 2.0, ui.titleSize, goodColor if isOut else ui.textColor)
	y += ui.titleSize + 2.0
	var level : int = player.progress.pet_level(picked) if owned(picked) else 1
	for i in picked.max_level():
		draw_rect(Rect2(textX + i * 5.0, y, 4.0, 4.0), ui.frameColor)
		draw_rect(Rect2(textX + i * 5.0 + 1.0, y + 1.0, 2.0, 2.0), ui.selectedColor if i < level and owned(picked) else ui.panelColor)
	draw_string(font, Vector2(textX + picked.max_level() * 5.0 + 2.0, y + font.get_ascent(ui.statSize)), "Out with you" if isOut else ("Flies" if picked.flies else "Walks"), HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, goodColor if isOut else ui.dimColor)
	y += 6.0
	if owned(picked) and level < picked.max_level():
		var catches : int = player.progress.pet_catches(picked)
		var from : int = picked.levelCatches[level - 2] if level >= 2 else 0
		var to : int = picked.levelCatches[level - 1]
		var bar : Rect2 = Rect2(textX, y, detail.end.x - textX - 4.0, 3.0)
		draw_rect(bar, ui.frameColor)
		draw_rect(Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2.0) * clampf(float(catches - from) / maxf(to - from, 1.0), 0.0, 1.0), 1.0)), goodColor)
		draw_string(font, Vector2(textX, y + 4.0 + font.get_ascent(ui.statSize)), "%d/%d fish to Lv%d" % [catches, to, level + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
	elif owned(picked):
		draw_string(font, Vector2(textX, y + font.get_ascent(ui.statSize)), "Max level!", HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.selectedColor)
	y = detail.position.y + 36.0
	var left : float = detail.position.x + 3.0
	var width : float = detail.size.x - 6.0
	var now : Array = picked.buff_lines(level)
	var next : Array = picked.buff_lines(level + 1) if owned(picked) and level < picked.max_level() else []
	for i in now.size():
		var value : String = now[i][1] if known else "?"
		draw_string(font, Vector2(left, y + font.get_ascent(ui.statSize)), now[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
		var shownValue : String = value + (" > " + next[i][1] if i < next.size() else "")
		draw_string(font, Vector2(left, y + font.get_ascent(ui.statSize)), shownValue, HORIZONTAL_ALIGNMENT_RIGHT, width, ui.statSize, ui.textColor)
		if i < next.size():
			var nextWidth : float = font.get_string_size(next[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize).x
			draw_string(font, Vector2(left + width - nextWidth, y + font.get_ascent(ui.statSize)), next[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, goodColor)
		y += ui.statSize + 1.0
	y += 1.0
	var text : String = picked.description if known else "Not found yet. Pet shops around the islands sell pets."
	for wrapped in ui.wrap_lines(text, width, ui.statSize):
		if y + ui.statSize > buttonRect.position.y - 2.0:
			break
		draw_string(font, Vector2(left, y + font.get_ascent(ui.statSize)), wrapped, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, ui.dimColor)
		y += ui.statSize + 1.0
	var state : Array = action()
	var enabled : bool = state[1]
	UiKit.button(self, font, skin, buttonRect, state[0], ui.statSize, enabled, buttonRect.has_point(mouse))
	if messageLeft > 0.0:
		var fade : float = clampf(messageLeft / 0.4, 0.0, 1.0)
		draw_string(font, Vector2(detail.position.x, buttonRect.position.y - 2.0), message, HORIZONTAL_ALIGNMENT_CENTER, detail.size.x, ui.statSize, Color(messageColor, fade))
