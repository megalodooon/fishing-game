extends MenuPanel
class_name RecipeBookUI

# The recipe book (R, or any crafting station): every recipe in the game, by
# category, on the colored bookmarks down the book's edge. The left page lists
# the open category's recipes, what can be made first; the right page shows
# the picked one: what it makes, where it's made, each ingredient with how
# many are in the bag (hover one to see where to find it), and buttons to make
# it once, five times or as often as the bag allows. Recipes not learned yet
# are silhouettes that say how to learn them. A pin puts the recipe on the HUD.

const GROUP : StringName = &"recipe_books"
# Not standing at any station.
const NOWHERE : StringName = &"nowhere"
const MARK_COLORS : Array[Color] = [Color(0.9, 0.55, 0.3), Color(0.35, 0.65, 0.9), Color(0.6, 0.4, 0.25), Color(0.95, 0.8, 0.3), Color(0.45, 0.7, 0.55), Color(0.65, 0.65, 0.72), Color(0.95, 0.45, 0.45), Color(0.8, 0.6, 0.35), Color(0.6, 0.5, 0.85), Color(0.45, 0.5, 0.9)]

enum Zone { NONE, MARK, RESULT, INGREDIENT, CRAFT, PIN, FILTER, STATION }

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin

@export_group("Layout")
@export var maxSize : Vector2 = Vector2(180, 104)
@export var edge : int = 2
@export var cover : int = 3
@export var padding : int = 3
@export var spine : int = 3
@export var leftWidth : float = 80.0
@export var markWidth : float = 6.0
@export var markHeight : float = 9.0
@export var iconBox : float = 20.0
@export var buttonHeight : float = 9.0
@export var messageTime : float = 2.0

var list : ListMenu
var category : int = 0
var at : StringName = NOWHERE
var recipe : BaitRecipe
var makeOnly : bool = false
# The thing looked up with R: the book lists what makes it and what uses it.
var focus : Resource
var bookRect : Rect2
var leftRect : Rect2
var rightRect : Rect2
var cardRect : Rect2
var filterRect : Rect2
var pinRect : Rect2
var stationRect : Rect2
var markRects : Array[Rect2] = []
var craftRects : Array[Rect2] = []
var ingredientRects : Array[Rect2] = []
var zone : Zone = Zone.NONE
var index : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var holding : int = -1
var time : float = 0.0
var detailAge : float = 1.0
var message : String = ""
var messageGood : bool = true
var messageLeft : float = 0.0
var sparkles : Sparkles = Sparkles.new()
var tipLayer : Control
#------------------------#


func _ready() -> void:
	super()
	add_to_group(GROUP)
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/recipes.tres") as MenuSkin
	list = ListMenu.new()
	list.ui = ui
	list.skin = skin
	list.framed = false
	list.rowHeight = 11
	list.slide = Vector2.ZERO
	add_child(list)
	list.chosen.connect(pick)
	list.pointed.connect(aim)
	tipLayer = Control.new()
	tipLayer.mouse_filter = MOUSE_FILTER_IGNORE
	tipLayer.draw.connect(draw_tip)
	add_child(tipLayer)
	ui.laid_out.connect(fit)
	ui.opened.connect(close)
	player.inventory.changed.connect(refresh)
	player.progress.changed.connect(refresh)
	set_process(false)
	fit()

static func find(tree : SceneTree) -> RecipeBookUI:
	return tree.get_first_node_in_group(GROUP) as RecipeBookUI

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	layout()

func hub_open() -> void:
	if not shown:
		open_at(NOWHERE)

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

# Something new can be made and hasn't been looked at.
func hub_news() -> bool:
	for each in Catalog.recipes():
		if each.unlocked(player.progress) and not seen(each):
			return true
	return false

# Opens the book at a station (or NOWHERE), on the first tab with its recipes.
func open_at(station : StringName, who : Player = null) -> void:
	if who:
		player = who
	at = station
	if station != NOWHERE:
		for each in Catalog.recipes():
			if Recipes.station_of(each) == station:
				category = maxi(Recipes.CATEGORIES.find(Recipes.category_of(each)), 0)
				break
	MenuHub.menu_opened(get_tree(), self)
	ui.close()
	recipe = null
	list.reset_scroll()
	fill()
	open_menu()
	list.open_menu()
	set_process(true)
	player.frozen = true

func close() -> void:
	if not shown:
		return
	close_menu()
	list.close_menu()
	set_process(false)
	player.frozen = false
	at = NOWHERE
	focus = null

# R over an ingredient or the result looks that thing up. Taken before the tab
# strip, which would close the book.
func _input(event : InputEvent) -> void:
	if not shown or not event.is_action_pressed("recipes") or event.is_echo():
		return
	var thing : Resource = null
	if zone == Zone.INGREDIENT and recipe and index < recipe.ingredients.size():
		thing = recipe.ingredients[index]
	elif zone == Zone.RESULT and recipe:
		thing = recipe.result()
	if thing:
		get_viewport().set_input_as_handled()
		show_uses(thing)

func _unhandled_input(event : InputEvent) -> void:
	if shown and (event.is_action_pressed("ui_cancel") or (at != NOWHERE and event.is_action_pressed("interact"))):
		get_viewport().set_input_as_handled()
		close()

func _has_point(point : Vector2) -> bool:
	if not shown:
		return false
	if bookRect.has_point(point):
		return true
	for area in markRects:
		if area.has_point(point):
			return true
	return false

func layout() -> void:
	var top : float = MenuHub.top_of(get_tree(), edge) if is_inside_tree() else float(edge)
	var book : Vector2 = Vector2(minf(size.x - edge * 2.0 - markWidth - 2.0, maxSize.x), minf(size.y - top - edge, maxSize.y)).floor()
	bookRect = Rect2(Vector2(floorf((size.x - book.x - markWidth) * 0.5), top), book)
	var inner : Rect2 = bookRect.grow(-cover)
	leftRect = Rect2(inner.position, Vector2(leftWidth, inner.size.y))
	rightRect = Rect2(leftRect.end.x + spine, inner.position.y, inner.end.x - leftRect.end.x - spine, inner.size.y)
	var headBottom : float = leftRect.position.y + padding + ui.titleSize + 3.0
	filterRect = Rect2(leftRect.end.x - padding - 26.0, leftRect.position.y + padding - 1.0, 26.0, 7.0)
	list.place(Rect2(Vector2(leftRect.position.x + 2.0, headBottom), Vector2(leftRect.size.x - 4.0, leftRect.end.y - headBottom - 2.0)))
	cardRect = rightRect.grow(-padding)
	var buttonsTop : float = cardRect.end.y - buttonHeight
	craftRects = [Rect2(cardRect.position.x, buttonsTop, 30.0, buttonHeight), Rect2(cardRect.position.x + 31.0, buttonsTop, 16.0, buttonHeight), Rect2(cardRect.position.x + 48.0, buttonsTop, 18.0, buttonHeight)]
	pinRect = Rect2(cardRect.end.x - 9.0, buttonsTop, 9.0, buttonHeight)
	markRects.clear()
	var y : float = bookRect.position.y + 4.0
	var count : int = Recipes.CATEGORIES.size()
	var tall : float = minf(markHeight, floorf((bookRect.size.y - 8.0) / count) - 1.0)
	for i in count:
		markRects.append(Rect2(bookRect.end.x - 1.0, y, markWidth + 1.0, tall))
		y += tall + 1.0
	tipLayer.size = size
	queue_redraw()

# Recipes known from the start never count as new.
func seen(each : BaitRecipe) -> bool:
	if each.requiredFlag.is_empty() and each.requiredLevel <= 1:
		return true
	return player.progress.has_flag("seen_recipe/" + each.resource_path.get_file().get_basename())

func see(each : BaitRecipe) -> void:
	if each and each.unlocked(player.progress) and not seen(each):
		player.progress.flags["seen_recipe/" + each.resource_path.get_file().get_basename()] = true

func usable_here(each : BaitRecipe) -> bool:
	return Recipes.can_use(player, Recipes.station_of(each), at)

# The open category's recipes: makeable ones first, then learned, then locked.
# With an item looked up (see show_uses), what makes it and what it goes into.
func fill() -> void:
	if focus:
		fill_uses()
		return
	var wanted : String = Recipes.CATEGORIES[category]
	var rows : Array[Dictionary] = []
	var order : int = 0
	for each in Catalog.recipes():
		if not each.result() or Recipes.category_of(each) != wanted:
			continue
		order += 1
		var row : Dictionary = recipe_row(each, order)
		if not row.is_empty():
			rows.append(row)
	rows.sort_custom(func(a : Dictionary, b : Dictionary) -> bool: return a.rank < b.rank if a.rank != b.rank else a.order < b.order)
	list.set_rows(rows)
	if not recipe or Recipes.category_of(recipe) != wanted:
		recipe = rows[0].value if not rows.is_empty() else null
		see(recipe)
	ingredient_rects()
	redraw()

func recipe_row(each : BaitRecipe, order : int) -> Dictionary:
	var made : Item = each.result()
	var learned : bool = each.unlocked(player.progress)
	var batches : int = Recipes.batches(player, each) if learned else 0
	var here : bool = usable_here(each)
	if makeOnly and (batches <= 0 or not here):
		return {}
	var rank : int = 0 if learned and batches > 0 and here else (1 if learned else 2)
	if not learned:
		return {"value": each, "icon": made.icon, "tint": Color(0.36, 0.26, 0.17, 0.85), "text": "???", "search": "", "detail": "", "dim": true, "rank": rank, "order": order}
	var detail : String = "x%d" % batches if batches > 0 and here else ""
	return {"value": each, "icon": made.icon, "tint": BaitCrafter.tint_of(made), "outline": ui.outline_color(made), "text": made.displayName, "detail": detail, "detailIcon": null if here else Recipes.station_icon(Recipes.station_of(each)), "detailColor": skin.good if batches > 0 and here else skin.dim, "dim": batches <= 0 or not here, "badge": "" if seen(each) else "NEW", "rank": rank, "order": order, "marked": each == player.progress.pinnedRecipe, "markColor": skin.accent}

# Opens the book on everything to do with one thing: the recipes that make it
# and the ones that use it. A fish looks up its species.
func show_uses(thing : Resource) -> void:
	if thing is Fish:
		thing = (thing as Fish).species
	elif thing is Item:
		thing = (thing as Item).original()
	if not thing:
		return
	focus = thing
	recipe = null
	list.reset_scroll()
	if not shown:
		var hub : MenuHub = MenuHub.find(get_tree())
		if hub:
			hub.switch_to(hub.menus.find(self))
		else:
			open_at(NOWHERE)
	fill()

func uses(each : BaitRecipe, thing : Resource) -> bool:
	for ingredient in each.ingredients:
		if ingredient == thing:
			return true
		if ingredient is Rarity and thing is FishData and (thing as FishData).rarity == ingredient:
			return true
	return false

func fill_uses() -> void:
	var made : Array[Dictionary] = []
	var used : Array[Dictionary] = []
	var order : int = 0
	for each in Catalog.recipes():
		order += 1
		var result : Item = each.result()
		if result and result.original() == focus:
			var row : Dictionary = recipe_row(each, order)
			if not row.is_empty():
				made.append(row)
		if uses(each, focus):
			var row : Dictionary = recipe_row(each, order)
			if not row.is_empty():
				used.append(row)
	var rows : Array[Dictionary] = []
	if not made.is_empty():
		rows.append({"header": true, "text": "Made by"})
		rows.append_array(made)
	rows.append({"header": true, "text": "Used in %d" % used.size() if not used.is_empty() else "Not used in recipes"})
	rows.append_array(used)
	list.set_rows(rows)
	if not recipe:
		for row in rows:
			if not row.get("header", false):
				recipe = row.value
				break
	ingredient_rects()
	redraw()

func refresh() -> void:
	if shown:
		fill()

func redraw() -> void:
	queue_redraw()
	tipLayer.queue_redraw()

func aim(value : Variant) -> void:
	var each : BaitRecipe = value as BaitRecipe
	if each and each != recipe:
		recipe = each
		detailAge = 0.0
		see(recipe)
		ingredient_rects()
		redraw()

func pick(value : Variant) -> void:
	aim(value)

func switch_category(which : int) -> void:
	if which == category and not focus:
		return
	focus = null
	category = which
	recipe = null
	list.reset_scroll()
	fill()

# Where each ingredient row sits on the right page.
func ingredient_rects() -> void:
	ingredientRects.clear()
	if not recipe:
		return
	var y : float = cardRect.position.y + iconBox + 13.0
	for i in recipe.ingredients.size():
		ingredientRects.append(Rect2(cardRect.position.x, y, cardRect.size.x, 7.0))
		y += 7.0
	stationRect = Rect2(cardRect.position.x, cardRect.position.y + iconBox + 3.0, cardRect.size.x, 7.0)

func zone_at(point : Vector2) -> Vector2i:
	for i in markRects.size():
		if markRects[i].grow_individual(0.0, 0.0, 2.0, 0.0).has_point(point):
			return Vector2i(Zone.MARK, i)
	if filterRect.has_point(point):
		return Vector2i(Zone.FILTER, 0)
	if not recipe:
		return Vector2i(Zone.NONE, -1)
	if Rect2(cardRect.position, Vector2(iconBox, iconBox)).has_point(point):
		return Vector2i(Zone.RESULT, 0)
	if recipe.unlocked(player.progress):
		for i in craftRects.size():
			if craftRects[i].has_point(point):
				return Vector2i(Zone.CRAFT, i)
		if pinRect.has_point(point):
			return Vector2i(Zone.PIN, 0)
		if stationRect.has_point(point):
			return Vector2i(Zone.STATION, 0)
		for i in ingredientRects.size():
			if ingredientRects[i].has_point(point):
				return Vector2i(Zone.INGREDIENT, i)
	return Vector2i(Zone.NONE, -1)

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse = Vector2(-100.0, -100.0)
		zone = Zone.NONE
		redraw()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		var found : Vector2i = zone_at(mouse)
		zone = found.x as Zone
		index = found.y
		redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			holding = -1
			redraw()
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			close()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var found : Vector2i = zone_at(event.position)
			match found.x:
				Zone.MARK:
					switch_category(found.y)
				Zone.FILTER:
					makeOnly = not makeOnly
					fill()
				Zone.CRAFT:
					holding = found.y
					craft([1, 5, Recipes.MAX_BATCH][found.y])
				Zone.PIN:
					player.progress.pinnedRecipe = null if player.progress.pinnedRecipe == recipe else recipe
					player.progress.emit_changed()
					say("Pinned to the HUD" if player.progress.pinnedRecipe else "Unpinned", true)
		accept_event()

func craft(times : int) -> void:
	if not recipe or not recipe.unlocked(player.progress):
		return
	if not usable_here(recipe):
		var tool : Item = Recipes.kit(Recipes.station_of(recipe))
		say("Make it at the %s%s" % [Recipes.station_name(Recipes.station_of(recipe)).to_lower(), " or carry a %s" % tool.displayName if tool else ""], false)
		return
	if Recipes.batches(player, recipe) <= 0:
		say("Missing ingredients", false)
		return
	var made : int = Recipes.craft(player, recipe, mini(times, Recipes.batches(player, recipe)))
	if made <= 0:
		say("No room in the bag", false)
		return
	say("Made %d %s!" % [recipe.amount * made, recipe.result().displayName], true)
	sparkles.burst(Rect2(cardRect.position, Vector2(iconBox, iconBox)).get_center(), Color(1.0, 0.85, 0.4), 16)

func say(text : String, good : bool) -> void:
	message = text
	messageGood = good
	messageLeft = messageTime
	redraw()

# Only redraws while something moves: the card sliding in, a message, sparkles
# or a bookmark wiggling under the pointer.
func _process(delta : float) -> void:
	time += delta
	var moving : bool = detailAge < 1.0 or messageLeft > 0.0 or sparkles.active() or zone == Zone.MARK
	detailAge = minf(detailAge + delta * 7.0, 1.0)
	messageLeft = maxf(messageLeft - delta, 0.0)
	sparkles.update(delta)
	if moving:
		queue_redraw()

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(bookRect.position + Vector2(2.0, 2.0), bookRect.size), Color(0.0, 0.0, 0.0, 0.3))
	for i in markRects.size():
		draw_mark(i)
	UiKit.box(self, skin.frame, bookRect)
	UiKit.box(self, skin.well, leftRect)
	UiKit.box(self, skin.well, rightRect)
	var middle : float = floorf(leftRect.end.x + spine * 0.5)
	draw_rect(Rect2(middle - 1.0, bookRect.position.y + 1.0, 3.0, bookRect.size.y - 2.0), Color(0.16, 0.09, 0.04))
	var title : String = Recipes.CATEGORIES[category] if not focus else Collections.name_of(focus)
	UiKit.label(self, font, Vector2(leftRect.position.x + padding, leftRect.position.y + padding - 1.0 + font.get_ascent(ui.titleSize)), title, ui.titleSize, skin.title)
	draw_filter(font)
	draw_card(font)
	if messageLeft > 0.0:
		draw_message(font)
	sparkles.draw(self)

func draw_mark(i : int) -> void:
	var area : Rect2 = markRects[i]
	var open : bool = i == category and not focus
	var hover : bool = zone == Zone.MARK and index == i
	var out : float = 2.0 if open else (1.0 + roundf(0.5 + 0.5 * sin(time * 8.0)) if hover else 0.0)
	var shown_area : Rect2 = Rect2(area.position, area.size + Vector2(out, 0.0))
	var color : Color = MARK_COLORS[i % MARK_COLORS.size()]
	draw_rect(shown_area.grow(1.0), Color(0.12, 0.06, 0.02))
	draw_rect(shown_area, color)
	draw_rect(Rect2(shown_area.position, Vector2(shown_area.size.x, 1.0)), color.lightened(0.35))
	draw_rect(Rect2(shown_area.end.x - 1.0, shown_area.position.y, 1.0, shown_area.size.y), color.darkened(0.3))

func draw_filter(font : Font) -> void:
	var hover : bool = zone == Zone.FILTER
	var box : Rect2 = Rect2(filterRect.position + Vector2(0.0, 1.0), Vector2(5.0, 5.0))
	draw_rect(box, skin.line)
	draw_rect(box.grow(-1.0), skin.good if makeOnly else Color(1.0, 1.0, 1.0, 0.35))
	UiKit.label(self, font, Vector2(box.end.x + 1.0, UiKit.baseline(font, filterRect, ui.statSize)), "Ready", ui.statSize, skin.text if hover or makeOnly else skin.dim)

func draw_card(font : Font) -> void:
	if not recipe or not recipe.result():
		UiKit.label(self, font, Vector2(cardRect.position.x, cardRect.get_center().y), "Nothing here yet", ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_CENTER, cardRect.size.x)
		return
	var made : Item = recipe.result()
	var learned : bool = recipe.unlocked(player.progress)
	var shift : float = roundf((1.0 - UiKit.pop(detailAge)) * 3.0)
	var box : Rect2 = Rect2(cardRect.position + Vector2(0.0, shift), Vector2(iconBox, iconBox))
	UiKit.box(self, skin.card, box)
	var zoom : float = minf(1.0, (iconBox - 4.0) / maxf(made.icon.get_width(), made.icon.get_height())) if made.icon else 1.0
	if made.icon:
		if learned:
			ui.draw_icon(self, made.icon, box.get_center(), BaitCrafter.tint_of(made), ui.outline_color(made), zoom)
		else:
			ui.draw_silhouette(self, made.icon, box.get_center(), Color(0.36, 0.26, 0.17, 0.9), zoom)
	var x : float = box.end.x + 3.0
	var width : float = cardRect.end.x - x
	var y : float = box.position.y
	UiKit.label(self, font, Vector2(x, y + font.get_ascent(ui.titleSize)), made.displayName if learned else "???", ui.titleSize, skin.readable(made.title_color()) if learned else skin.text, HORIZONTAL_ALIGNMENT_LEFT, width)
	y += ui.titleSize + 1.0
	UiKit.label(self, font, Vector2(x, y + font.get_ascent(ui.statSize)), made.tag(), ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, width)
	y += ui.statSize + 1.0
	var owned : int = Counter.count_owned(player, made)
	var makes : String = "Makes %d" % recipe.amount + (" (have %d)" % owned if owned > 0 else "")
	UiKit.label(self, font, Vector2(x, y + font.get_ascent(ui.statSize)), makes, ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, width)
	if not learned:
		var lines : PackedStringArray = ui.wrap_lines(Recipes.unlock_text(recipe, player.progress), cardRect.size.x, ui.statSize)
		var ty : float = cardRect.position.y + iconBox + 5.0
		UiKit.label(self, font, Vector2(cardRect.position.x, ty + font.get_ascent(ui.statSize)), "How to learn it", ui.statSize, skin.title)
		ty += ui.statSize + 2.0
		for line in lines:
			UiKit.label(self, font, Vector2(cardRect.position.x, ty + font.get_ascent(ui.statSize)), line, ui.statSize, skin.text)
			ty += ui.statSize + 1.0
		return
	draw_station(font)
	for i in recipe.ingredients.size():
		draw_ingredient(font, i)
	draw_buttons(font)

func draw_station(font : Font) -> void:
	var station : StringName = Recipes.station_of(recipe)
	var here : bool = usable_here(recipe)
	var icon : Texture2D = Recipes.station_icon(station)
	var x : float = stationRect.position.x
	if icon:
		draw_texture(icon, Vector2(x, stationRect.position.y - 1.0))
		x += icon.get_width() + 2.0
	var text : String = Recipes.station_name(station) if here else "At the %s" % Recipes.station_name(station).to_lower()
	UiKit.label(self, font, Vector2(x, UiKit.baseline(font, stationRect, ui.statSize)), text, ui.statSize, skin.good if here else skin.bad, HORIZONTAL_ALIGNMENT_LEFT, stationRect.end.x - x)
	draw_rect(Rect2(stationRect.position.x, stationRect.end.y + 0.5, stationRect.size.x, 1.0), skin.line)

func draw_ingredient(font : Font, i : int) -> void:
	var area : Rect2 = ingredientRects[i]
	if zone == Zone.INGREDIENT and index == i:
		draw_rect(area, skin.hover)
	var ingredient : Resource = recipe.ingredients[i]
	var icon : Texture2D = BaitRecipe.ingredient_icon(ingredient)
	var x : float = area.position.x
	if icon:
		var shrink : float = 1.0
		while maxf(icon.get_width(), icon.get_height()) * shrink > 6.0:
			shrink *= 0.5
		var drawn : Vector2 = icon.get_size() * shrink
		draw_texture_rect(icon, Rect2(Vector2(x + 3.0, area.get_center().y) - drawn * 0.5, drawn).abs(), false)
	x += 8.0
	var have : int = recipe.have(i, player.inventory)
	var need : int = recipe.needed(i)
	var count : String = "%d/%d" % [mini(have, need), need]
	var countWidth : float = UiKit.text_width(font, count, ui.statSize)
	var baseline : float = UiKit.baseline(font, area, ui.statSize)
	UiKit.label(self, font, Vector2(x, baseline), BaitRecipe.ingredient_name(ingredient), ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.end.x - x - countWidth - 2.0)
	UiKit.label(self, font, Vector2(area.end.x - countWidth, baseline), count, ui.statSize, skin.good if have >= need else skin.bad)

func draw_buttons(font : Font) -> void:
	var batches : int = Recipes.batches(player, recipe)
	var here : bool = usable_here(recipe)
	var labels : PackedStringArray = ["Craft", "x5", "All"]
	var needs : Array[int] = [1, 5, 2]
	for i in craftRects.size():
		var enabled : bool = here and batches >= needs[i]
		UiKit.button(self, font, skin, craftRects[i], labels[i], ui.statSize, enabled, zone == Zone.CRAFT and index == i, holding == i)
	var pinned : bool = player.progress.pinnedRecipe == recipe
	UiKit.box(self, skin.tabHover if zone == Zone.PIN else skin.tab, pinRect)
	var pin : Texture2D = preload("res://ui/hub/icons/pin.png")
	draw_texture(pin, (pinRect.get_center() - pin.get_size() * 0.5).floor(), Color.WHITE if pinned else Color(1.0, 1.0, 1.0, 0.45))

func draw_message(font : Font) -> void:
	var fade : float = clampf(messageLeft / 0.4, 0.0, 1.0)
	var width : float = minf(UiKit.text_width(font, message, ui.statSize) + 8.0, rightRect.size.x)
	var toast : Rect2 = Rect2(roundf(rightRect.get_center().x - width * 0.5), craftRects[0].position.y - ui.statSize - 5.0, width, ui.statSize + 3.0)
	draw_rect(toast, Color(0.03, 0.05, 0.09, 0.9 * fade))
	draw_rect(Rect2(toast.position.x, toast.end.y - 1.0, toast.size.x, 1.0), Color(Color(0.56, 0.93, 0.44) if messageGood else Color(0.95, 0.45, 0.4), fade))
	UiKit.label(self, font, Vector2(toast.position.x, UiKit.baseline(font, toast, ui.statSize)), message, ui.statSize, Color(Color(0.56, 0.93, 0.44) if messageGood else Color(0.95, 0.45, 0.4), fade), HORIZONTAL_ALIGNMENT_CENTER, toast.size.x)

func draw_tip() -> void:
	var title : String = ""
	var color : Color = ui.textColor
	var lines : PackedStringArray = PackedStringArray()
	match zone:
		Zone.MARK:
			title = Recipes.CATEGORIES[index]
			var learned : int = 0
			var total : int = 0
			for each in Catalog.recipes():
				if Recipes.category_of(each) == title:
					total += 1
					if each.unlocked(player.progress):
						learned += 1
			lines = PackedStringArray(["Learned", "%d/%d" % [learned, total]])
		Zone.FILTER:
			title = "Ready to make"
			lines = PackedStringArray(["Only show what you", "", "can make right here", ""])
		Zone.RESULT:
			if recipe and recipe.unlocked(player.progress):
				var made : Item = recipe.result()
				title = made.displayName
				color = made.title_color()
				lines = made.details()
				if not made.description.is_empty():
					for line in ui.wrap_lines(made.description, 70.0, ui.statSize):
						lines.append_array([line, ""])
				lines.append_array(["R", "what it's used in"])
		Zone.INGREDIENT:
			var ingredient : Resource = recipe.ingredients[index]
			title = BaitRecipe.ingredient_name(ingredient)
			var found : PackedStringArray = Sources.of(ingredient) if ingredient is Item else Sources.fish_text(ingredient, player.journal)
			if found.is_empty():
				found = PackedStringArray(["Nowhere known yet"])
			for i in mini(found.size(), 5):
				lines.append_array([found[i], ""])
			lines.append_array(["R", "what it's used in"])
		Zone.STATION:
			var station : StringName = Recipes.station_of(recipe)
			title = Recipes.station_name(station)
			lines = PackedStringArray(["Where", Recipes.station_place(station)])
			var tool : Item = Recipes.kit(station)
			if tool:
				lines.append_array(["Or carry a %s" % tool.displayName, ""])
		Zone.PIN:
			title = "Pin to HUD"
			lines = PackedStringArray(["Track the ingredients", "", "while you gather them", ""])
		Zone.CRAFT:
			title = ["Make one", "Make five", "Make as many as you can"][index]
	if title.is_empty():
		return
	ui.paint_tip(tipLayer, mouse, title, color, lines, ui.tip_size(title, lines))
