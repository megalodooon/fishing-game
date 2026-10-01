extends MenuPanel
class_name ProfileUI

# The player's logbook (K). The Skills page is a grid of every skill under
# the Angler Level; click one to open it: its level, XP and perk on the left,
# and its level road on the right, every level with what it unlocks (hover a
# level for all of it, scroll for more). The Angler page shows where the
# Angler XP comes from and what the next levels give. The Tide Tree page
# grows perks with Tide Tokens (see TideTree). Feats lists the achievements
# by group. The Stats page adds up every stat with all its sources, plus the
# running totals.

enum Tab { SKILLS, ANGLER, TREE, FEATS, STATS }
enum Zone { NONE, TAB, CARD, BACK, ROAD, UP, DOWN, NODE, GROUP, FEAT }
const TAB_NAMES : PackedStringArray = ["Skills", "Angler", "Tide Tree", "Feats", "Stats"]
const COUNTERS : Array = [["Fish caught", "fish_caught"], ["Sea creatures beaten", "creatures"], ["Treasure found", "treasure_found"], ["Treasure opened", "treasure_opened"], ["Rare catches", "rare_drops"], ["Crops harvested", "harvests"], ["Things foraged", "forage"], ["Meals eaten", "meals"], ["Things crafted", "crafted"], ["Trips sailed", "trips"], ["Coins from sales", "coins_earned"], ["Orders delivered", "orders"], ["Days", "days"], ["Giant fish", "variant_giant"], ["Shiny fish", "variant_shiny"], ["Golden fish", "variant_golden"]]
const SKILL_ICONS : Dictionary = {
	Skills.FISHING: preload("res://ui/hub/icons/skill_fishing.png"),
	Skills.FARMING: preload("res://ui/hub/icons/skill_farming.png"),
	Skills.COOKING: preload("res://ui/hub/icons/skill_cooking.png"),
	Skills.SAILING: preload("res://ui/hub/icons/skill_sailing.png"),
	Skills.HUNTING: preload("res://ui/hub/icons/skill_hunting.png"),
	Skills.TRADING: preload("res://ui/hub/icons/skill_trading.png"),
	Skills.FORAGING: preload("res://ui/hub/icons/skill_foraging.png"),
	Skills.CRAFTING: preload("res://ui/hub/icons/skill_crafting.png"),
	Skills.ALCHEMY: preload("res://ui/hub/icons/skill_alchemy.png"),
}
const STAR : Texture2D = preload("res://ui/hub/icons/star.png")
const CHECK : Texture2D = preload("res://ui/hub/icons/check.png")
const ANGLER_COLOR : Color = Color(1.0, 0.78, 0.35)
const COLUMNS : int = 3

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var menus : Array[Control] = []
@export var skin : MenuSkin
@export var maxWidth : float = 184.0
@export var sideWidth : float = 70.0
@export var roadRow : float = 7.0

var tab : int = Tab.SKILLS
# The open skill, or empty on the grid.
var skill : StringName = &""
var panel : Rect2
var body : Rect2
var header : Rect2
var side : Rect2
var road : Rect2
var backRect : Rect2
var upRect : Rect2
var downRect : Rect2
var tabRects : Array[Rect2] = []
var cardRects : Array[Rect2] = []
var roadRects : Array[Rect2] = []
var roadFirst : int = 1
var zone : Zone = Zone.NONE
var index : int = -1
var mouse : Vector2 = Vector2(-100.0, -100.0)
var completion : float = 0.0
var time : float = 0.0
var pick : float = 1.0
var nodeRects : Array[Rect2] = []
var treeArea : Rect2
var groupRects : Array[Rect2] = []
var featRects : Array[Rect2] = []
var featGroup : int = 0
var featFirst : int = 0
var feats : Array = []
var sparkles : Sparkles = Sparkles.new()
#------------------------#


func _ready() -> void:
	super()
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/leather_blue.tres") as MenuSkin
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
	body = Rect2(panel.position.x + 4.0, panel.position.y + 14.0, panel.size.x - 8.0, panel.size.y - 18.0)
	tabRects.clear()
	var x : float = panel.position.x + 5.0
	for label in TAB_NAMES:
		var tabWidth : float = UiKit.text_width(ui.font, label, ui.statSize) + 10.0
		tabRects.append(Rect2(x, panel.position.y + 5.0, tabWidth, 9.0))
		x += tabWidth + 1.0
	# The grid: the Angler Level strip, then three columns of skill cards.
	header = Rect2(body.position + Vector2(0.0, 1.0), Vector2(body.size.x, 14.0))
	cardRects.clear()
	var grid : Rect2 = Rect2(body.position.x, header.end.y + 2.0, body.size.x, body.end.y - header.end.y - 2.0)
	var rows : int = ceili(Skills.LIST.size() / float(COLUMNS))
	var cardSize : Vector2 = Vector2(floorf((grid.size.x - (COLUMNS - 1) * 2.0) / COLUMNS), floorf((grid.size.y - (rows - 1) * 2.0) / rows))
	for i in Skills.LIST.size():
		@warning_ignore("integer_division")
		cardRects.append(Rect2(grid.position + Vector2((i % COLUMNS) * (cardSize.x + 2.0), (i / COLUMNS) * (cardSize.y + 2.0)), cardSize))
	# An open skill: facts on the left, the level road on the right.
	side = Rect2(body.position, Vector2(sideWidth, body.size.y))
	road = Rect2(side.end.x + 2.0, body.position.y, body.end.x - side.end.x - 2.0, body.size.y)
	backRect = Rect2(side.position.x + 3.0, side.end.y - 11.0, side.size.x - 6.0, 8.0)
	upRect = Rect2(road.end.x - 11.0, road.position.y + 2.0, 8.0, 6.0)
	downRect = Rect2(road.end.x - 11.0, road.end.y - 8.0, 8.0, 6.0)
	layout_road()
	layout_tree()
	layout_feats()
	queue_redraw()

func layout_tree() -> void:
	nodeRects.clear()
	treeArea = Rect2(body.position.x, body.position.y + 10.0, body.size.x, body.size.y - 10.0)
	var step : Vector2 = Vector2(treeArea.size.x / 7.0, treeArea.size.y / 5.0)
	for each in TideTree.NODES:
		var place_at : Vector2i = each[7]
		var center : Vector2 = Vector2(treeArea.position.x + (place_at.x + 0.5) * step.x, treeArea.end.y - (place_at.y + 0.5) * step.y).round()
		nodeRects.append(Rect2(center - Vector2(5.0, 5.0), Vector2(10.0, 10.0)))

func layout_feats() -> void:
	groupRects.clear()
	var groups : PackedStringArray = Achievements.groups()
	var rowHeight : float = floorf((body.size.y - 4.0) / maxf(groups.size(), 1.0))
	for i in groups.size():
		groupRects.append(Rect2(body.position.x + 2.0, body.position.y + 2.0 + i * rowHeight, 56.0, rowHeight - 1.0))
	feats.clear()
	featRects.clear()
	if groups.is_empty():
		return
	var wanted : String = groups[clampi(featGroup, 0, groups.size() - 1)]
	var all_here : Array = []
	for each in Achievements.LIST:
		if each[3] == wanted:
			all_here.append(each)
	var fits : int = floori((body.size.y - 4.0) / 10.0)
	featFirst = clampi(featFirst, 0, maxi(all_here.size() - fits, 0))
	var y : float = body.position.y + 2.0
	for i in range(featFirst, mini(featFirst + fits, all_here.size())):
		feats.append(all_here[i])
		featRects.append(Rect2(body.position.x + 62.0, y, body.size.x - 64.0, 9.0))
		y += 10.0

func hub_open() -> void:
	if not shown:
		open_profile()

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(1.0).has_point(point)

func open_profile() -> void:
	for menu in menus:
		if menu and menu.has_method("close"):
			menu.call("close")
	player.frozen = true
	completion = Collections.completion(player)
	AnglerLevel.forget()
	open_menu()
	set_process(true)

func close() -> void:
	if not shown:
		return
	close_menu()
	set_process(false)
	player.frozen = false

func _unhandled_input(event : InputEvent) -> void:
	if not shown:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not skill.is_empty() and tab == Tab.SKILLS:
			open_skill(&"")
		else:
			close()
	elif tab == Tab.SKILLS and not skill.is_empty():
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			scroll_road(-1 if event.is_action_pressed("ui_up") else 1)
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			var at : int = Skills.LIST.find(skill)
			open_skill(Skills.LIST[posmod(at + (1 if event.is_action_pressed("ui_right") else -1), Skills.LIST.size())])

func open_skill(which : StringName) -> void:
	skill = which
	pick = 0.0
	zone = Zone.NONE
	if not skill.is_empty():
		roadFirst = maxi(Skills.level(player, skill) - 1, 1)
		layout_road()
	queue_redraw()

# The rows of the level road that fit, starting at roadFirst.
func layout_road() -> void:
	roadRects.clear()
	var count : int = floori((road.size.y - 4.0) / roadRow)
	roadFirst = clampi(roadFirst, 1, maxi(Skills.MAX_LEVEL - count + 1, 1))
	for i in count:
		if roadFirst + i > Skills.MAX_LEVEL:
			break
		roadRects.append(Rect2(road.position.x + 2.0, road.position.y + 2.0 + i * roadRow, road.size.x - 15.0, roadRow - 1.0))

func scroll_road(by : int) -> void:
	roadFirst += by
	layout_road()
	queue_redraw()

func zone_at(point : Vector2) -> Vector2i:
	for i in tabRects.size():
		if tabRects[i].has_point(point):
			return Vector2i(Zone.TAB, i)
	if tab == Tab.TREE:
		for i in nodeRects.size():
			if nodeRects[i].grow(1.0).has_point(point):
				return Vector2i(Zone.NODE, i)
		return Vector2i(Zone.NONE, -1)
	if tab == Tab.FEATS:
		for i in groupRects.size():
			if groupRects[i].has_point(point):
				return Vector2i(Zone.GROUP, i)
		for i in featRects.size():
			if featRects[i].has_point(point):
				return Vector2i(Zone.FEAT, i)
		return Vector2i(Zone.NONE, -1)
	if tab != Tab.SKILLS:
		return Vector2i(Zone.NONE, -1)
	if skill.is_empty():
		for i in cardRects.size():
			if cardRects[i].has_point(point):
				return Vector2i(Zone.CARD, i)
		return Vector2i(Zone.NONE, -1)
	if backRect.has_point(point):
		return Vector2i(Zone.BACK, 0)
	if upRect.grow(1.0).has_point(point):
		return Vector2i(Zone.UP, 0)
	if downRect.grow(1.0).has_point(point):
		return Vector2i(Zone.DOWN, 0)
	for i in roadRects.size():
		if roadRects[i].has_point(point):
			return Vector2i(Zone.ROAD, i)
	return Vector2i(Zone.NONE, -1)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		var found : Vector2i = zone_at(mouse)
		var changed : bool = found.x != zone or found.y != index
		zone = found.x as Zone
		index = found.y
		if changed or zone != Zone.NONE:
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if not skill.is_empty() and tab == Tab.SKILLS:
					open_skill(&"")
				else:
					close()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if tab == Tab.SKILLS and not skill.is_empty():
					scroll_road(-2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2)
				elif tab == Tab.FEATS:
					featFirst += -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
					layout_feats()
					queue_redraw()
			MOUSE_BUTTON_LEFT:
				var found : Vector2i = zone_at(event.position)
				match found.x:
					Zone.TAB:
						tab = found.y
						if tab == Tab.TREE:
							Features.introduce(player, "tide_tree")
					Zone.CARD:
						open_skill(Skills.LIST[found.y])
					Zone.BACK:
						open_skill(&"")
					Zone.UP:
						scroll_road(-3)
					Zone.DOWN:
						scroll_road(3)
					Zone.NODE:
						var id : String = TideTree.NODES[found.y][0]
						if TideTree.grow(player, id):
							sparkles.burst(nodeRects[found.y].get_center(), TideTree.TOKEN_COLOR, 12)
							AnglerLevel.forget()
					Zone.GROUP:
						featGroup = found.y
						featFirst = 0
						layout_feats()
				zone = Zone.NONE
				queue_redraw()
	accept_event()

func _process(delta : float) -> void:
	time += delta
	if sparkles.update(delta) or pick < 1.0 or zone in [Zone.CARD, Zone.ROAD, Zone.BACK, Zone.NODE]:
		pick = minf(pick + delta * 6.0, 1.0)
		queue_redraw()

func line_at(y : float) -> float:
	return y + ui.font.get_ascent(ui.statSize)

func _draw() -> void:
	if not player:
		return
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	for i in tabRects.size():
		var area : Rect2 = tabRects[i]
		var active : bool = i == tab
		UiKit.box(self, skin.tabOn if active else (skin.tabHover if zone == Zone.TAB and index == i else skin.tab), area if active else area.grow_individual(0.0, -1.0, 0.0, 0.0))
		UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, area, ui.statSize)), TAB_NAMES[i], ui.statSize, skin.text if active else skin.dim, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	match tab:
		Tab.SKILLS:
			if skill.is_empty():
				draw_grid(font)
			else:
				draw_skill(font)
		Tab.ANGLER:
			draw_angler(font)
		Tab.TREE:
			draw_tree(font)
		Tab.FEATS:
			draw_feats(font)
		Tab.STATS:
			draw_stats(font)
	sparkles.draw(self)
	var shown_tip : Array = tip()
	if not shown_tip.is_empty():
		ui.paint_tip(self, mouse, shown_tip[0], shown_tip[2] if shown_tip.size() > 2 else ui.textColor, shown_tip[1], ui.tip_size(shown_tip[0], shown_tip[1]))

# ---------------------------------------------------------------- the grid

func draw_grid(font : Font) -> void:
	UiKit.box(self, skin.well, header)
	var inner : Rect2 = header.grow(-2.0)
	var level : int = AnglerLevel.level(player)
	draw_texture(STAR, Vector2(inner.position.x + 1.0, inner.position.y + 1.0))
	UiKit.label(self, font, Vector2(inner.position.x + 8.0, line_at(inner.position.y + 1.0)), "Angler Level", ui.statSize, skin.text)
	UiKit.label(self, font, Vector2(inner.position.x + 8.0, inner.position.y + 1.0 + font.get_ascent(ui.titleSize)), "%d" % level, ui.titleSize, ANGLER_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, 60.0)
	UiKit.bar(self, Rect2(inner.position.x + 8.0, inner.end.y - 2.0, 60.0, 2.0), AnglerLevel.progress_in_level(player), ANGLER_COLOR)
	var total : float = 0.0
	for each in Skills.LIST:
		total += Skills.level(player, each)
	UiKit.label(self, font, Vector2(inner.position.x, line_at(inner.position.y)), "Skill average %.1f" % (total / Skills.LIST.size()), ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	UiKit.label(self, font, Vector2(inner.position.x, line_at(inner.position.y + ui.statSize + 2.0)), "Completion %.1f%%" % completion, ui.statSize, skin.good, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	for i in Skills.LIST.size():
		draw_card(font, i)

func draw_card(font : Font, i : int) -> void:
	var which : StringName = Skills.LIST[i]
	var area : Rect2 = cardRects[i]
	var hover : bool = zone == Zone.CARD and index == i
	var color : Color = Skills.COLORS[which]
	var xp : float = Skills.xp(player, which)
	var level : int = Skills.level_of(which, xp)
	UiKit.box(self, skin.well, area)
	if hover:
		draw_rect(area.grow(-1.0), Color(color, 0.16))
		UiKit.brackets(self, area, skin.title, time)
	var inner : Rect2 = area.grow(-2.0)
	var icon : Texture2D = SKILL_ICONS.get(which)
	if icon:
		draw_texture(icon, Vector2(inner.position.x + 1.0, inner.position.y + 1.0))
	var levelText : String = "%d" % level
	var levelWidth : float = UiKit.text_width(font, levelText, ui.titleSize)
	UiKit.label(self, font, Vector2(inner.position.x, inner.position.y + 1.0 + font.get_ascent(ui.titleSize)), levelText, ui.titleSize, color if level < Skills.MAX_LEVEL else ANGLER_COLOR, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	UiKit.label(self, font, Vector2(inner.position.x + 11.0, line_at(inner.position.y + 2.0)), Skills.NAMES[which], ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 13.0 - levelWidth)
	UiKit.bar(self, Rect2(inner.position.x + 1.0, inner.end.y - 2.0, inner.size.x - 2.0, 2.0), Skills.level_progress(which, xp), color)
	var next : Array = next_unlock(which, level)
	if not next.is_empty() and inner.size.y >= 15.0:
		var y : float = inner.position.y + 10.0
		UiKit.label(self, font, Vector2(inner.position.x + 1.0, line_at(y)), "%d:" % next[0], ui.statSize, skin.dim)
		var x : float = inner.position.x + 2.0 + UiKit.text_width(font, "%d:" % next[0], ui.statSize)
		var icon_next : Texture2D = next[1][0]
		if icon_next:
			draw_texture(icon_next, Vector2(x, y), Color(1.0, 1.0, 1.0, 0.8))
			x += icon_next.get_width() + 1.0
		UiKit.label(self, font, Vector2(x, line_at(y)), String(next[1][1]).get_slice(": ", 1) if String(next[1][1]).contains(": ") else next[1][1], ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, inner.end.x - x)

# The next level with something to unlock and its first reward, or [].
func next_unlock(which : StringName, level : int) -> Array:
	for at in SkillRewards.milestones(which):
		if at > level:
			return [at, SkillRewards.at(which, at)[0]]
	return []

# ---------------------------------------------------------------- one skill

func draw_skill(font : Font) -> void:
	var color : Color = Skills.COLORS[skill]
	var xp : float = Skills.xp(player, skill)
	var level : int = Skills.level_of(skill, xp)
	UiKit.box(self, skin.well, side)
	var inner : Rect2 = side.grow(-3.0)
	var shift : float = roundf((1.0 - UiKit.pop(pick)) * 3.0)
	var y : float = inner.position.y + shift
	var icon : Texture2D = SKILL_ICONS.get(skill)
	if icon:
		draw_texture(icon, Vector2(inner.position.x, y))
	UiKit.label(self, font, Vector2(inner.position.x + 10.0, y + font.get_ascent(ui.titleSize)), String(Skills.NAMES[skill]).to_upper(), ui.titleSize, color)
	y += ui.titleSize + 4.0
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "Level", ui.statSize, skin.dim)
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "%d / %d" % [level, Skills.MAX_LEVEL], ui.statSize, skin.title, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	y += ui.statSize + 2.0
	UiKit.bar(self, Rect2(inner.position.x, y, inner.size.x, 3.0), Skills.level_progress(skill, xp), color)
	y += 5.0
	var into : String = "MAX" if level >= Skills.MAX_LEVEL else "%s / %s XP" % [UiKit.coins_text(roundi(xp - Skills.total_for(skill, level))), UiKit.coins_text(roundi(Skills.step(skill, level)))]
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), into, ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	y += ui.statSize + 4.0
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "Perk", ui.statSize, skin.title)
	y += ui.statSize + 1.0
	for line in ui.wrap_lines(Skills.perk_text(skill), inner.size.x, ui.statSize):
		if y + ui.statSize > backRect.position.y - 2.0:
			break
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), line, ui.statSize, skin.good)
		y += ui.statSize + 1.0
	y += 3.0
	var total : int = 0
	var got : int = 0
	for at in SkillRewards.milestones(skill):
		var count : int = SkillRewards.at(skill, at).size()
		total += count
		if at <= level:
			got += count
	var next : Array = next_unlock(skill, level)
	var facts : Array = [["Unlocked", "%d/%d" % [got, total]], ["Next unlock", "Lv %d" % next[0] if not next.is_empty() else "-"], ["Total XP", UiKit.coins_text(roundi(xp))]]
	for fact in facts:
		if y + ui.statSize > backRect.position.y - 2.0:
			break
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), fact[0], ui.statSize, skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), fact[1], ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
		y += ui.statSize + 1.0
	UiKit.button(self, font, skin, backRect, "All skills", ui.statSize, true, zone == Zone.BACK)
	draw_road(font, level, color)

# Every level as a row: a dot, the number, what it unlocks. Reached levels
# are ticked, the next one glows.
func draw_road(font : Font, level : int, color : Color) -> void:
	UiKit.box(self, skin.well, road)
	if roadRects.is_empty():
		return
	var spine : float = roadRects[0].position.x + 3.5
	draw_rect(Rect2(spine - 0.5, roadRects[0].position.y + 3.0, 1.0, roadRects.back().end.y - roadRects[0].position.y - 5.0), skin.line)
	for i in roadRects.size():
		var at : int = roadFirst + i
		var area : Rect2 = roadRects[i]
		var reached : bool = at <= level
		var next : bool = at == level + 1
		if next:
			draw_rect(area, Color(color, 0.16))
		if zone == Zone.ROAD and index == i:
			draw_rect(area, skin.hover)
		var dot : Rect2 = Rect2(Vector2(spine - 2.5, area.get_center().y - 2.5), Vector2(5.0, 5.0))
		draw_rect(dot, skin.line)
		draw_rect(dot.grow(-1.0), color if reached else (color.darkened(0.4) if next else Color(0.12, 0.16, 0.22)))
		var x : float = area.position.x + 8.0
		UiKit.label(self, font, Vector2(x, line_at(area.position.y + 1.0)), "%d" % at, ui.statSize, color if reached else (skin.title if next else skin.dim), HORIZONTAL_ALIGNMENT_RIGHT, 9.0)
		x += 12.0
		var rewards : Array = SkillRewards.at(skill, at)
		var text : String = "+$%d, perk" % (SkillRewards.COINS_PER_LEVEL * at)
		if not rewards.is_empty():
			var reward_icon : Texture2D = rewards[0][0]
			if reward_icon:
				draw_texture(reward_icon, Vector2(x, area.position.y), Color.WHITE if reached or next else Color(1.0, 1.0, 1.0, 0.6))
			x += 8.0
			text = rewards[0][1] if rewards.size() == 1 else "%s +%d" % [rewards[0][1], rewards.size() - 1]
		var room : float = area.end.x - x - (CHECK.get_width() + 1.0 if reached else 0.0)
		UiKit.label(self, font, Vector2(x, line_at(area.position.y + 1.0)), text, ui.statSize, skin.text if next else (skin.dim if reached else skin.text), HORIZONTAL_ALIGNMENT_LEFT, room)
		if reached:
			draw_texture(CHECK, Vector2(area.end.x - CHECK.get_width(), area.position.y), Color(1.0, 1.0, 1.0, 0.7))
	var canUp : bool = roadFirst > 1
	var canDown : bool = roadFirst + roadRects.size() <= Skills.MAX_LEVEL
	draw_arrow(upRect, true, canUp, zone == Zone.UP)
	draw_arrow(downRect, false, canDown, zone == Zone.DOWN)
	# Where the list sits along all levels.
	var track : Rect2 = Rect2(upRect.get_center().x - 0.5, upRect.end.y + 2.0, 1.0, downRect.position.y - upRect.end.y - 4.0)
	draw_rect(track, skin.line)
	var share : float = roadRects.size() / float(Skills.MAX_LEVEL)
	var from : float = (roadFirst - 1) / float(Skills.MAX_LEVEL)
	draw_rect(Rect2(track.position.x - 0.5, track.position.y + track.size.y * from, 2.0, maxf(track.size.y * share, 2.0)), color)

func draw_arrow(area : Rect2, up : bool, enabled : bool, hover : bool) -> void:
	var tint : Color = skin.title if hover and enabled else (skin.text if enabled else Color(skin.dim, 0.4))
	var center : Vector2 = area.get_center()
	var points : PackedVector2Array = PackedVector2Array([center + Vector2(-3.0, 1.5), center + Vector2(3.0, 1.5), center + Vector2(0.0, -1.5)]) if up else PackedVector2Array([center + Vector2(-3.0, -1.5), center + Vector2(3.0, -1.5), center + Vector2(0.0, 1.5)])
	draw_colored_polygon(points, tint)

# ---------------------------------------------------------------- angler

func draw_angler(font : Font) -> void:
	var level : int = AnglerLevel.level(player)
	var found : Dictionary = AnglerLevel.counts(player)
	UiKit.box(self, skin.well, side)
	var inner : Rect2 = side.grow(-3.0)
	var y : float = inner.position.y
	draw_texture(STAR, Vector2(inner.position.x, y))
	UiKit.label(self, font, Vector2(inner.position.x + 7.0, y + font.get_ascent(ui.titleSize)), "ANGLER", ui.titleSize, ANGLER_COLOR)
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.titleSize)), "%d" % level, ui.titleSize, skin.title, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
	y += ui.titleSize + 4.0
	UiKit.bar(self, Rect2(inner.position.x, y, inner.size.x, 3.0), AnglerLevel.progress_in_level(player), ANGLER_COLOR)
	y += 5.0
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "%d / %d XP" % [AnglerLevel.xp(player) % AnglerLevel.XP_PER_LEVEL, AnglerLevel.XP_PER_LEVEL], ui.statSize, skin.dim)
	y += ui.statSize + 4.0
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "Level %d gives" % (level + 1), ui.statSize, skin.title)
	y += ui.statSize + 1.0
	for line in AnglerLevel.rewards(level + 1):
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), line, ui.statSize, skin.good, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
		y += ui.statSize + 1.0
	y += 2.0
	var rows : Array = [["Max energy", "+%d" % roundi(AnglerLevel.bonus(player, &"energyMax"))], ["Pouch slots", "+%d" % AnglerLevel.pouch_bonus(player)], ["Crew slots", "+%d" % AnglerLevel.crew_bonus(player)]]
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "So far", ui.statSize, skin.title)
	y += ui.statSize + 1.0
	for row in rows:
		if y + ui.statSize > inner.end.y:
			break
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), row[0], ui.statSize, skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), row[1], ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
		y += ui.statSize + 1.0
	UiKit.box(self, skin.well, road)
	var list : Rect2 = road.grow(-3.0)
	y = list.position.y
	UiKit.label(self, font, Vector2(list.position.x, line_at(y)), "Where Angler XP comes from", ui.statSize, skin.title)
	UiKit.label(self, font, Vector2(list.position.x, line_at(y)), "XP", ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, list.size.x)
	y += ui.statSize + 2.0
	for source in AnglerLevel.SOURCES:
		if y + ui.statSize > list.end.y:
			break
		var count : int = found.get(source[2], 0)
		UiKit.label(self, font, Vector2(list.position.x, line_at(y)), source[0], ui.statSize, skin.text if count > 0 else skin.dim)
		UiKit.label(self, font, Vector2(list.position.x, line_at(y)), "%d x%d" % [count, source[1]], ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, list.size.x - 20.0)
		UiKit.label(self, font, Vector2(list.position.x, line_at(y)), "%d" % (count * source[1]), ui.statSize, ANGLER_COLOR if count > 0 else skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, list.size.x)
		y += ui.statSize + 1.0

# ---------------------------------------------------------------- tide tree

func draw_tree(font : Font) -> void:
	UiKit.box(self, skin.well, body)
	var tokens : int = TideTree.tokens(player)
	UiKit.label(self, font, Vector2(body.position.x + 3.0, line_at(body.position.y + 2.0)), "Tide Tokens: %d" % tokens, ui.statSize, TideTree.TOKEN_COLOR if tokens > 0 else skin.dim)
	UiKit.label(self, font, Vector2(body.position.x, line_at(body.position.y + 2.0)), "1 per Angler Level", ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, body.size.x - 3.0)
	# Branches first, under the nodes.
	for i in TideTree.NODES.size():
		for parent in TideTree.NODES[i][6]:
			for j in TideTree.NODES.size():
				if TideTree.NODES[j][0] == parent:
					var grown : bool = TideTree.level(player.progress, parent) > 0
					draw_line(nodeRects[i].get_center(), nodeRects[j].get_center(), Color(TideTree.TOKEN_COLOR, 0.8) if grown else Color(skin.line, 0.6), 1.0)
	for i in TideTree.NODES.size():
		var each : Array = TideTree.NODES[i]
		var area : Rect2 = nodeRects[i]
		var at : int = TideTree.level(player.progress, each[0])
		var full : bool = at >= int(each[4])
		var open : bool = TideTree.reachable(player.progress, each[0])
		var fill : Color = Color(1.0, 0.82, 0.3) if full else (TideTree.TOKEN_COLOR if at > 0 else (Color(0.2, 0.3, 0.4) if open else Color(0.1, 0.12, 0.16)))
		draw_rect(area, Color(0.03, 0.05, 0.1))
		draw_rect(area.grow(-1.0), fill)
		if at > 0 and not full:
			draw_rect(Rect2(area.position.x + 1.0, area.end.y - 2.0, (area.size.x - 2.0) * at / float(each[4]), 1.0), Color(1.0, 1.0, 1.0, 0.8))
		if open and TideTree.blocked(player, each[0]).is_empty():
			UiKit.brackets(self, area.grow(1.0), TideTree.TOKEN_COLOR, time)
		if zone == Zone.NODE and index == i:
			UiKit.outline(self, area.grow(1.0), skin.title)
		var glyph : String = "%d" % at if at > 0 else String(each[1]).left(1)
		UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, area, ui.statSize)), glyph, ui.statSize, Color(0.05, 0.08, 0.12) if at > 0 else Color(0.5, 0.62, 0.72, 0.9 if open else 0.4), HORIZONTAL_ALIGNMENT_CENTER, area.size.x)

# ---------------------------------------------------------------- feats

func draw_feats(font : Font) -> void:
	UiKit.box(self, skin.well, body)
	var groups : PackedStringArray = Achievements.groups()
	draw_rect(Rect2(body.position.x + 59.0, body.position.y + 2.0, 1.0, body.size.y - 4.0), skin.line)
	for i in groupRects.size():
		var area : Rect2 = groupRects[i]
		var done : int = 0
		var count : int = 0
		for each in Achievements.LIST:
			if each[3] == groups[i]:
				count += 1
				if Achievements.unlocked(player.progress, each[0]):
					done += 1
		if i == featGroup:
			draw_rect(area, Color(skin.accent, 0.25))
			draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), skin.accent)
		elif zone == Zone.GROUP and index == i:
			draw_rect(area, skin.hover)
		UiKit.label(self, font, Vector2(area.position.x + 2.0, UiKit.baseline(font, area, ui.statSize)), groups[i], ui.statSize, skin.text if i == featGroup else skin.dim, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 14.0)
		UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, area, ui.statSize)), "%d/%d" % [done, count], ui.statSize, skin.good if done == count else skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 1.0)
	for i in feats.size():
		var each : Array = feats[i]
		var area : Rect2 = featRects[i]
		if area.end.y > body.end.y:
			break
		var have : bool = Achievements.unlocked(player.progress, each[0])
		if zone == Zone.FEAT and index == i:
			draw_rect(area, skin.hover)
		var icon : Texture2D = Achievements.ICONS[each[4]] if have else Achievements.LOCKED_ICON
		draw_texture(icon, Vector2(area.position.x, area.position.y - 1.0))
		var secret : bool = each[5] and not have
		UiKit.label(self, font, Vector2(area.position.x + 14.0, line_at(area.position.y + 1.0)), "???" if secret else each[1], ui.statSize, Achievements.TIER_COLORS[each[4]] if have else skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 14.0)

# ---------------------------------------------------------------- stats

func draw_stats(font : Font) -> void:
	UiKit.box(self, skin.well, body)
	var inner : Rect2 = body.grow(-3.0)
	var half : float = floorf(inner.size.x * 0.5) - 2.0
	var y : float = inner.position.y
	UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), "Stats", ui.statSize, skin.title)
	y += ui.statSize + 2.0
	for row in Stats.summary(player):
		if y + ui.statSize > inner.end.y:
			break
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), row[0], ui.statSize, skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x, line_at(y)), row[1], ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, half)
		y += ui.statSize + 1.0
	var left : float = inner.position.x + half + 4.0
	y = inner.position.y
	UiKit.label(self, font, Vector2(left, line_at(y)), "Totals", ui.statSize, skin.title)
	y += ui.statSize + 2.0
	var hours : int = floori(player.progress.playtime / 3600.0)
	var minutes : int = floori(fmod(player.progress.playtime, 3600.0) / 60.0)
	var rows : Array = [["Played", "%dh %02dm" % [hours, minutes]], ["Pearls", "%d/%d" % [Pearls.found(player.progress), Pearls.TOTAL]], ["Tickets", "%d" % player.progress.tickets]]
	for pair in COUNTERS:
		rows.append([pair[0], "%d" % player.progress.counter(pair[1])])
	for row in rows:
		if y + ui.statSize > inner.end.y:
			break
		UiKit.label(self, font, Vector2(left, line_at(y)), row[0], ui.statSize, skin.dim)
		UiKit.label(self, font, Vector2(left, line_at(y)), row[1], ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, half)
		y += ui.statSize + 1.0

# ---------------------------------------------------------------- tips

# [title, lines, title color] for what's under the pointer, or [].
func tip() -> Array:
	match zone:
		Zone.NODE:
			if index >= 0 and index < TideTree.NODES.size():
				var each : Array = TideTree.NODES[index]
				var at : int = TideTree.level(player.progress, each[0])
				var lines : PackedStringArray = PackedStringArray([each[8], "", "Level", "%d/%d" % [at, each[4]], "Now", Stats.bonus_text(each[2], float(each[3]) * at) if at > 0 else "-"])
				if at < int(each[4]):
					lines.append_array(["Next", Stats.bonus_text(each[2], float(each[3]) * (at + 1)), "Costs", "%d token%s" % [each[5], "" if int(each[5]) == 1 else "s"]])
				var why : String = TideTree.blocked(player, each[0])
				lines.append_array([why if not why.is_empty() else "Click to grow", ""])
				return [each[1], lines, TideTree.TOKEN_COLOR]
		Zone.FEAT:
			if index >= 0 and index < feats.size():
				var each : Array = feats[index]
				var have : bool = Achievements.unlocked(player.progress, each[0])
				var secret : bool = each[5] and not have
				var lines : PackedStringArray = PackedStringArray(["A secret." if secret else each[2], "", Achievements.TIER_NAMES[each[4]], "Unlocked on day %d" % int(player.progress.get_flag(Achievements.key(each[0]))) if have else "Locked"])
				return ["???" if secret else each[1], lines, Achievements.TIER_COLORS[each[4]]]
		Zone.ROAD:
			if index >= 0 and index < roadRects.size():
				var at : int = roadFirst + index
				var lines : PackedStringArray = PackedStringArray()
				for line in SkillRewards.lines(skill, at):
					lines.append_array([line, ""])
				return ["%s level %d" % [Skills.NAMES[skill], at], lines, Skills.COLORS[skill]]
		Zone.CARD:
			if index >= 0 and index < Skills.LIST.size():
				var which : StringName = Skills.LIST[index]
				var lines : PackedStringArray = PackedStringArray([Skills.perk_text(which), "", "Total XP", UiKit.coins_text(roundi(Skills.xp(player, which)))])
				var next : Array = next_unlock(which, Skills.level(player, which))
				if not next.is_empty():
					lines.append_array(["Next at %d" % next[0], "", next[1][1], ""])
				lines.append_array(["Click", "level road"])
				return [Skills.NAMES[which], lines, Skills.COLORS[which]]
	return []

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		zone = Zone.NONE
		queue_redraw()
