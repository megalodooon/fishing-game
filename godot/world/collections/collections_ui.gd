extends MenuPanel
class_name CollectionsUI

# The collection case (L): every fish, sea creature and item by category, in
# a glass display case. Found things show their icon and how far their
# collection is, unknown ones stay silhouettes. The picked thing's card lists
# its tiers: how many it takes, what each one pays and which recipes it
# teaches. Collections are how most recipes are learned.

enum Zone { NONE, CATEGORY, CELL, TIER }

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin
@export var maxWidth : float = 184.0
@export var listWidth : float = 44.0
@export var cardWidth : float = 62.0
@export var cell : float = 12.0

var category : int = 0
var things : Array[Resource] = []
var picked : Resource
var panel : Rect2
var listRect : Rect2
var gridRect : Rect2
var cardRect : Rect2
var categoryRects : Array[Rect2] = []
var tierRects : Array[Rect2] = []
var scroll : float = 0.0
var zone : Zone = Zone.NONE
var index : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var time : float = 0.0
# Found and total per category, worked out when the case opens.
var counts : Array[Vector2i] = []
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/glass.tres") as MenuSkin
	ui.laid_out.connect(fit)
	ui.opened.connect(close)
	set_process(false)
	fit()

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	var width : float = minf(ui.size.x - 6.0, maxWidth)
	var top : float = MenuHub.top_of(get_tree(), 3.0) if is_inside_tree() else 3.0
	panel = Rect2(floorf((ui.size.x - width) * 0.5), top, width, ui.size.y - top - 2.0)
	var inner : Rect2 = panel.grow(-4.0)
	listRect = Rect2(inner.position, Vector2(listWidth, inner.size.y))
	cardRect = Rect2(inner.end.x - cardWidth, inner.position.y, cardWidth, inner.size.y)
	gridRect = Rect2(listRect.end.x + 2.0, inner.position.y, cardRect.position.x - listRect.end.x - 4.0, inner.size.y)
	categoryRects.clear()
	var pitch : float = floorf((listRect.size.y - 4.0) / Collections.CATEGORIES.size())
	for i in Collections.CATEGORIES.size():
		categoryRects.append(Rect2(listRect.position.x + 2.0, listRect.position.y + 2.0 + i * pitch, listRect.size.x - 4.0, pitch - 1.0))
	queue_redraw()

func hub_open() -> void:
	if not shown:
		open_case()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

func open_case() -> void:
	MenuHub.menu_opened(get_tree(), self)
	player.frozen = true
	count_all()
	show_category(category)
	open_menu()
	set_process(true)

func close() -> void:
	if not shown:
		return
	close_menu()
	set_process(false)
	player.frozen = false

func count_all() -> void:
	counts.clear()
	for _each in Collections.CATEGORIES.size():
		counts.append(Vector2i.ZERO)
	for thing in Catalog.things():
		var at : int = Collections.CATEGORIES.find(Collections.category(thing))
		if at < 0:
			continue
		counts[at].y += 1
		if Collections.found(player, thing):
			counts[at].x += 1

func show_category(which : int) -> void:
	category = which
	things.clear()
	var wanted : String = Collections.CATEGORIES[category]
	for thing in Catalog.things():
		if Collections.category(thing) == wanted:
			things.append(thing)
	scroll = 0.0
	picked = null
	for thing in things:
		if Collections.found(player, thing):
			picked = thing
			break
	lay_tiers()
	queue_redraw()

func columns() -> int:
	return maxi(floori((gridRect.size.x - 3.0) / cell), 1)

func cell_rect(i : int) -> Rect2:
	var count : int = columns()
	@warning_ignore("integer_division")
	return Rect2(gridRect.position + Vector2(2.0 + (i % count) * cell, 2.0 + (i / count) * cell - scroll), Vector2(cell - 1.0, cell - 1.0))

func max_scroll() -> float:
	return maxf(ceilf(things.size() / float(columns())) * cell + 3.0 - gridRect.size.y, 0.0)

func lay_tiers() -> void:
	tierRects.clear()
	if not picked:
		return
	var y : float = cardRect.position.y + 30.0
	for i in Collections.tiers(picked).size():
		tierRects.append(Rect2(cardRect.position.x + 2.0, y, cardRect.size.x - 4.0, 7.0))
		y += 8.0

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(1.0).has_point(point)

func _unhandled_input(event : InputEvent) -> void:
	if shown and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func zone_at(point : Vector2) -> Vector2i:
	for i in categoryRects.size():
		if categoryRects[i].has_point(point):
			return Vector2i(Zone.CATEGORY, i)
	if gridRect.has_point(point):
		for i in things.size():
			if cell_rect(i).has_point(point):
				return Vector2i(Zone.CELL, i)
	for i in tierRects.size():
		if tierRects[i].has_point(point):
			return Vector2i(Zone.TIER, i)
	return Vector2i(Zone.NONE, -1)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		var found : Vector2i = zone_at(mouse)
		zone = found.x as Zone
		index = found.y
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				close()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				scroll = clampf(scroll + cell * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 0.0, max_scroll())
			MOUSE_BUTTON_LEFT:
				var found : Vector2i = zone_at(event.position)
				if found.x == Zone.CATEGORY:
					show_category(found.y)
				elif found.x == Zone.CELL:
					picked = things[found.y]
					lay_tiers()
		queue_redraw()
	accept_event()

func _process(delta : float) -> void:
	time += delta
	if zone == Zone.CELL or picked:
		queue_redraw()

func _draw() -> void:
	if not player:
		return
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	UiKit.box(self, skin.well, listRect)
	UiKit.box(self, skin.well, gridRect)
	UiKit.box(self, skin.well, cardRect)
	for i in categoryRects.size():
		var area : Rect2 = categoryRects[i]
		var active : bool = i == category
		if active:
			draw_rect(area, Color(skin.title, 0.18))
			draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), skin.title)
		elif zone == Zone.CATEGORY and index == i:
			draw_rect(area, skin.hover)
		var baseline : float = UiKit.baseline(font, area, ui.statSize)
		UiKit.label(self, font, Vector2(area.position.x + 2.0, baseline), Collections.CATEGORIES[i], ui.statSize, skin.text if active else skin.dim, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 4.0)
		if i < counts.size() and counts[i].y > 0 and counts[i].x >= counts[i].y:
			draw_rect(Rect2(area.end.x - 3.0, area.get_center().y - 1.0, 2.0, 2.0), skin.good)
	draw_grid(font)
	draw_card(font)
	draw_tip()

func draw_grid(font : Font) -> void:
	var clipTop : float = gridRect.position.y + 1.0
	var clipBottom : float = gridRect.end.y - 1.0
	for i in things.size():
		var area : Rect2 = cell_rect(i)
		if area.position.y < clipTop or area.end.y > clipBottom:
			continue
		var thing : Resource = things[i]
		var have : int = Collections.count(player, thing)
		var level : int = Collections.tier(player, thing)
		var maxed : bool = level >= Collections.tiers(thing).size()
		draw_rect(area, Collections.TIER_COLOR if maxed else skin.line)
		draw_rect(area.grow(-1.0), Color(0.04, 0.1, 0.16, 0.9))
		var icon : Texture2D = Collections.icon_of(thing)
		if icon:
			var zoom : float = minf(1.0, (cell - 3.0) / maxf(icon.get_width(), icon.get_height()))
			if have > 0:
				var rarity : Rarity = Collections.rarity_of(thing)
				ui.draw_icon(self, icon, area.get_center(), Color.WHITE, rarity.color if rarity else ui.outlineColor, zoom)
			else:
				ui.draw_silhouette(self, icon, area.get_center(), Color(0.3, 0.5, 0.62, 0.55), zoom)
		if level > 0:
			draw_rect(Rect2(area.position.x + 1.0, area.end.y - 2.0, (area.size.x - 2.0) * level / float(Collections.tiers(thing).size()), 1.0), Collections.TIER_COLOR)
		if thing == picked:
			UiKit.brackets(self, area, skin.title, time)
		elif zone == Zone.CELL and index == i:
			UiKit.outline(self, area, skin.dim)
	var found : Vector2i = counts[category] if category < counts.size() else Vector2i.ZERO
	var label : String = "%d/%d found" % [found.x, found.y]
	var most : float = max_scroll()
	if most > 0.0:
		var track : Rect2 = Rect2(gridRect.end.x - 2.0, gridRect.position.y + 2.0, 1.0, gridRect.size.y - 4.0)
		var length : float = maxf(track.size.y * track.size.y / (track.size.y + most), 4.0)
		draw_rect(track, skin.line)
		draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - length) * scroll / most, 1.0, length), skin.dim)
	UiKit.label(self, font, Vector2(listRect.position.x, listRect.end.y - 2.0), label, ui.statSize, skin.good if found.x >= found.y and found.y > 0 else skin.dim, HORIZONTAL_ALIGNMENT_CENTER, listRect.size.x)

func draw_card(font : Font) -> void:
	var inner : Rect2 = cardRect.grow(-2.0)
	if not picked:
		UiKit.label(self, font, Vector2(inner.position.x, inner.get_center().y), "Nothing yet", ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x)
		return
	var have : int = Collections.count(player, picked)
	var known : bool = have > 0
	var icon : Texture2D = Collections.icon_of(picked)
	var y : float = inner.position.y
	if icon:
		var zoom : float = minf(1.0, 14.0 / maxf(icon.get_width(), icon.get_height()))
		if known:
			ui.draw_icon(self, icon, Vector2(inner.position.x + 8.0, y + 8.0), Color.WHITE, Collections.rarity_of(picked).color if Collections.rarity_of(picked) else ui.outlineColor, zoom)
		else:
			ui.draw_silhouette(self, icon, Vector2(inner.position.x + 8.0, y + 8.0), Color(0.3, 0.5, 0.62, 0.6), zoom)
	var rarity : Rarity = Collections.rarity_of(picked)
	var lines : PackedStringArray = ui.wrap_lines(Collections.name_of(picked) if known else "???", inner.size.x - 18.0, ui.statSize)
	for i in mini(lines.size(), 2):
		UiKit.label(self, font, Vector2(inner.position.x + 18.0, y + 1.0 + font.get_ascent(ui.statSize)), lines[i], ui.statSize, rarity.color if rarity and known else skin.text)
		y += ui.statSize + 1.0
	y = inner.position.y + 17.0
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), "Collected", ui.statSize, skin.dim)
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), UiKit.coins_text(have), ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	var needs : Array = Collections.tiers(picked)
	var level : int = Collections.tier(player, picked)
	for i in tierRects.size():
		var area : Rect2 = tierRects[i]
		var done : bool = i < level
		var current : bool = i == level
		if zone == Zone.TIER and index == i:
			draw_rect(area, skin.hover)
		var baseline : float = UiKit.baseline(font, area, ui.statSize)
		UiKit.label(self, font, Vector2(area.position.x + 1.0, baseline), Collections.ROMAN[i], ui.statSize, Collections.TIER_COLOR if done else skin.dim)
		var right : String = "Done" if done else "%d/%d" % [mini(have, needs[i]), needs[i]]
		UiKit.label(self, font, Vector2(area.position.x, baseline), right, ui.statSize, skin.good if done else (skin.text if current else skin.dim), HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 1.0)
		if current and not done:
			UiKit.bar(self, Rect2(area.position.x + 10.0, area.get_center().y - 1.0, area.size.x - 36.0, 2.0), float(have) / needs[i], Collections.TIER_COLOR, Color(0.02, 0.06, 0.1))
		if not recipes_at(i + 1).is_empty():
			draw_texture(SkillRewards.RECIPE, Vector2(area.position.x + 7.0 if not current else area.end.x - 30.0, area.position.y + 0.5))

# Recipes learned at a tier of the picked thing's collection.
func recipes_at(level : int) -> PackedStringArray:
	var names : PackedStringArray = PackedStringArray()
	if not picked:
		return names
	var flag : String = Collections.flag(picked, level)
	for recipe in Catalog.recipes():
		if recipe.requiredFlag == flag and recipe.result():
			names.append(recipe.result().displayName)
	return names

func draw_tip() -> void:
	var title : String = ""
	var color : Color = ui.textColor
	var lines : PackedStringArray = PackedStringArray()
	match zone:
		Zone.CATEGORY:
			title = Collections.CATEGORIES[index]
			var found : Vector2i = counts[index] if index < counts.size() else Vector2i.ZERO
			lines = PackedStringArray(["Found", "%d/%d" % [found.x, found.y]])
		Zone.CELL:
			var thing : Resource = things[index]
			if Collections.found(player, thing):
				title = Collections.name_of(thing)
				var rarity : Rarity = Collections.rarity_of(thing)
				color = rarity.color if rarity else color
				lines = PackedStringArray(["Collected", "%d" % Collections.count(player, thing), "Tier", Collections.ROMAN[Collections.tier(player, thing) - 1] if Collections.tier(player, thing) > 0 else "-"])
			else:
				title = "???"
				color = ui.dimColor
				lines = PackedStringArray(["Not found yet", ""])
		Zone.TIER:
			var level : int = index + 1
			title = "Tier %s" % Collections.ROMAN[index]
			var rarity : Rarity = Collections.rarity_of(picked)
			var worth : float = Collections.WORTH.get(rarity.displayName if rarity else "Common", 1.0)
			lines = PackedStringArray(["Needs", "%d" % Collections.tiers(picked)[index], "Coins", "$%d" % roundi(Collections.TIER_COINS[mini(index, Collections.TIER_COINS.size() - 1)] * worth), "XP", "%d" % roundi(Collections.TIER_XP[mini(index, Collections.TIER_XP.size() - 1)] * worth)])
			for recipe in recipes_at(level):
				lines.append_array(["Recipe", recipe])
	if title.is_empty():
		return
	ui.paint_tip(self, mouse, title, color, lines, ui.tip_size(title, lines))
