extends MenuPanel
class_name QuestLog

# The player's quests, opened with Q (or from Tab). A parchment page with
# tabs along the top (Story, Jobs, Done, and Missed scenes in a multiplayer
# game when there are some), the quests of the open tab down the left, and
# the picked quest on the right: who gave it (with their portrait), its
# description, each goal with a bar, the rewards with their icons, and a
# button to show it on screen. Quests ready to hand in are marked green.
# Keys: up/down pick, left/right switch tabs, Enter tracks, Esc closes.

const GROUP : StringName = &"quest_logs"
enum Tab { STORY, JOBS, DONE, MISSED }
const TAB_NAMES : PackedStringArray = ["Story", "Jobs", "Done", "Missed scenes"]
const ROW : float = 9.0
const LIST_WIDTH : float = 64.0

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var skin : MenuSkin

var tab : int = Tab.STORY
var items : Array = []
var picked : int = 0
var scroll : float = 0.0
var detailScroll : float = 0.0
var detailHeight : float = 0.0
var panel : Rect2
var listRect : Rect2
var cardRect : Rect2
var tabRects : Array[Rect2] = []
var rowRects : Array[Rect2] = []
var buttonRect : Rect2
var mouse : Vector2 = Vector2(-100.0, -100.0)
var time : float = 0.0
#------------------------#


static func find(tree : SceneTree) -> QuestLog:
	return tree.get_first_node_in_group(GROUP) as QuestLog

func _ready() -> void:
	super()
	add_to_group(GROUP)
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/paper.tres") as MenuSkin
	ui.laid_out.connect(fit)
	player.progress.changed.connect(func() -> void:
		if shown:
			refresh())
	set_process(false)
	fit()

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	layout()

func _has_point(point : Vector2) -> bool:
	return shown and panel.has_point(point)

func layout() -> void:
	var top : float = MenuHub.top_of(get_tree(), 3.0) if is_inside_tree() else 3.0
	var width : float = minf(size.x - 10.0, 176.0)
	panel = Rect2(floorf((size.x - width) * 0.5), top, width, size.y - top - 4.0)
	tabRects.clear()
	var x : float = panel.position.x + 4.0
	for i in tabs().size():
		var w : float = UiKit.text_width(ui.font, TAB_NAMES[tabs()[i]], 3) + 8.0
		tabRects.append(Rect2(x, panel.position.y + 4.0, w, 8.0))
		x += w + 1.0
	listRect = Rect2(panel.position.x + 4.0, panel.position.y + 14.0, LIST_WIDTH, panel.size.y - 18.0)
	cardRect = Rect2(listRect.end.x + 3.0, listRect.position.y, panel.end.x - listRect.end.x - 7.0, listRect.size.y)
	buttonRect = Rect2(cardRect.end.x - 46.0, cardRect.end.y - 11.0, 44.0, 9.0)

# The tabs shown: missed scenes only when there are some.
func tabs() -> Array:
	var list : Array = [Tab.STORY, Tab.JOBS, Tab.DONE]
	if player and not player.progress.missedScenes.is_empty():
		list.append(Tab.MISSED)
	return list

#------------------------# Opening

func hub_open() -> void:
	open_log(player)

func hub_close() -> void:
	close()

func hub_shown() -> bool:
	return shown

func hub_news() -> bool:
	for quest in player.progress.active_quests():
		if quest.ready(player):
			return true
	return not player.progress.missedScenes.is_empty()

func open_log(_who : Player = null) -> void:
	if shown:
		return
	# Opens on whichever tab has the tracked quest, or story first.
	var tracked : Quest = player.progress.tracked
	tab = Tab.JOBS if tracked and player.progress.quest_active(tracked) and not tracked.story else Tab.STORY
	refresh()
	if tracked and items.has(tracked):
		picked = items.find(tracked)
	open_menu()
	set_process(true)

func close() -> void:
	if shown:
		close_menu()
		set_process(false)

func refresh() -> void:
	layout()
	var before : Variant = items[picked] if picked < items.size() else null
	items.clear()
	match tab:
		Tab.MISSED:
			items.assign(player.progress.missedScenes)
		_:
			var going : Array = []
			var ready : Array = []
			for quest : Quest in player.progress.quests:
				var finished : bool = player.progress.quest_done(quest)
				if (tab == Tab.DONE) != finished:
					continue
				if tab != Tab.DONE and quest.story != (tab == Tab.STORY):
					continue
				if not finished and quest.ready(player):
					ready.append(quest)
				else:
					going.append(quest)
			items = ready + going
			if tab == Tab.DONE:
				items.reverse()
	picked = clampi(items.find(before) if before != null and items.has(before) else picked, 0, maxi(items.size() - 1, 0))
	queue_redraw()

func switch(to : int) -> void:
	var list : Array = tabs()
	tab = list[posmod(list.find(tab) + to, list.size())] if to != 0 else tab
	picked = 0
	scroll = 0.0
	detailScroll = 0.0
	refresh()

func pick(index : int) -> void:
	if index != picked:
		picked = clampi(index, 0, maxi(items.size() - 1, 0))
		detailScroll = 0.0
		scroll = clampf(scroll, (picked + 1) * ROW - listRect.size.y + 2.0, picked * ROW)
		queue_redraw()

func act() -> void:
	if picked >= items.size():
		return
	var item : Variant = items[picked]
	if item is Quest and player.progress.quest_active(item):
		player.progress.tracked = item
		player.progress.emit_changed()
	elif item is String:
		var story : StoryDirector = StoryDirector.find(get_tree())
		player.progress.missedScenes.erase(item)
		close()
		var hub : MenuHub = MenuHub.find(get_tree())
		if hub:
			hub.close_all()
		if story:
			story.play(item)

#------------------------# Input

func _unhandled_input(event : InputEvent) -> void:
	if not shown:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("down"):
		pick(picked + 1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up"):
		pick(picked - 1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("left"):
		switch(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("right"):
		switch(1)
	elif event.is_action_pressed("ui_accept"):
		act()
	else:
		return
	get_viewport().set_input_as_handled()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				for i in tabRects.size():
					if tabRects[i].has_point(event.position):
						tab = tabs()[i]
						switch(0)
				for i in rowRects.size():
					if rowRects[i].has_point(event.position):
						pick(i)
				if buttonRect.has_point(event.position):
					act()
			MOUSE_BUTTON_RIGHT:
				close()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var step : float = -6.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 6.0
				if cardRect.has_point(event.position):
					detailScroll = clampf(detailScroll + step, 0.0, maxf(detailHeight - cardRect.size.y + 14.0, 0.0))
				else:
					scroll = clampf(scroll + step, 0.0, maxf(items.size() * ROW - listRect.size.y + 2.0, 0.0))
		queue_redraw()
	accept_event()

func _process(delta : float) -> void:
	time += delta
	queue_redraw()

#------------------------# Drawing

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(1.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	var list : Array = tabs()
	for i in tabRects.size():
		var on : bool = list[i] == tab
		var area : Rect2 = tabRects[i]
		UiKit.paper_tab(self, font, area, TAB_NAMES[list[i]], on, area.has_point(mouse), skin.title, skin.dim)
	var going : int = player.progress.active_quests().size()
	UiKit.label(self, font, Vector2(panel.position.x, tabRects[0].position.y + font.get_ascent(3) + 2.0), "%d going" % going, 3, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 5.0)
	draw_list(font)
	draw_card(font)

func draw_list(font : Font) -> void:
	UiKit.box(self, skin.well, listRect)
	rowRects.clear()
	if items.is_empty():
		var empty : String = "Nothing missed" if tab == Tab.MISSED else ("Nothing finished yet" if tab == Tab.DONE else "No quests here yet")
		for line in ui.wrap_lines(empty, listRect.size.x - 6.0, 3):
			UiKit.label(self, font, listRect.position + Vector2(3.0, 4.0 + font.get_ascent(3) + rowRects.size() * 4.0), line, 3, skin.dim)
		return
	for i in items.size():
		var area : Rect2 = Rect2(listRect.position.x + 1.0, listRect.position.y + 1.0 + i * ROW - scroll, listRect.size.x - 2.0, ROW - 1.0)
		rowRects.append(area)
		if area.end.y < listRect.position.y or area.position.y > listRect.end.y - 2.0:
			continue
		var item : Variant = items[i]
		if i == picked:
			draw_rect(area, Color(skin.accent, 0.25))
			draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), skin.accent)
		elif area.has_point(mouse):
			draw_rect(area, skin.hover)
		var label : String = ""
		var dot : Color = skin.dim
		if item is Quest:
			var quest : Quest = item
			label = quest.title
			dot = Color(0.3, 0.7, 0.3) if player.progress.quest_done(quest) or quest.ready(player) else Color(0.85, 0.6, 0.1)
			if player.progress.tracked == quest:
				draw_rect(Rect2(area.end.x - 3.0, area.position.y + 2.0, 2.0, area.size.y - 4.0), skin.accent)
		else:
			label = Dialogue.title_of(item)
			dot = Color(0.55, 0.78, 1.0)
		draw_rect(Rect2(area.position.x + 2.0, area.position.y + 3.0, 2.0, 2.0), dot)
		UiKit.label(self, font, Vector2(area.position.x + 6.0, UiKit.baseline(font, area, 3)), label, 3, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 10.0)

func draw_card(font : Font) -> void:
	UiKit.box(self, skin.well, cardRect)
	if picked >= items.size():
		return
	var item : Variant = items[picked]
	var inner : Rect2 = cardRect.grow(-3.0)
	if item is String:
		UiKit.label(self, font, inner.position + Vector2(0.0, font.get_ascent(4)), Dialogue.title_of(item), 4, skin.title, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
		var y : float = inner.position.y + 8.0
		for line in ui.wrap_lines("This scene played for your friend while you were somewhere else. Watch it now?", inner.size.x, 3):
			UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), line, 3, skin.dim)
			y += 4.0
		UiKit.button(self, font, skin, buttonRect, "Watch", 3, true, buttonRect.has_point(mouse))
		return
	var quest : Quest = item
	var y : float = inner.position.y - detailScroll
	# The giver's portrait, then the title and who it's from.
	var giverId : String = Cast.id_of(quest.giver)
	var face : Texture2D = Cast.portrait(giverId) if not giverId.is_empty() else null
	var textX : float = inner.position.x
	if face and y + 14.0 > inner.position.y:
		var frame : Rect2 = Rect2(inner.position.x, y, 14.0, 14.0)
		UiKit.box(self, skin.card, frame)
		draw_texture_rect(face, Rect2(frame.position + Vector2(1.0, 1.0), Vector2(12.0, 12.0)), false)
		textX = frame.end.x + 3.0
	var titleColor : Color = Color(0.62, 0.36, 0.06) if quest.story else skin.title
	UiKit.label(self, font, Vector2(textX, y + font.get_ascent(4)), quest.title, 4, titleColor, HORIZONTAL_ALIGNMENT_LEFT, inner.end.x - textX)
	var from : String = ("Story, " if quest.story else "") + "from " + (Friendship.short_name(giverId) if not giverId.is_empty() else quest.giver)
	UiKit.label(self, font, Vector2(textX, y + 6.0 + font.get_ascent(3)), from, 3, skin.dim, HORIZONTAL_ALIGNMENT_LEFT, inner.end.x - textX)
	y += 16.0
	for line in ui.wrap_lines(quest.description, inner.size.x, 3):
		if y > inner.position.y - 4.0:
			UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), line, 3, skin.text)
		y += 4.0
	y += 3.0
	# Goals, each with a bar.
	var started : bool = player.progress.quest_started(quest)
	var finished : bool = player.progress.quest_done(quest)
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), "Goals", 3, skin.title)
	y += 5.0
	for i in quest.goals.size():
		var goal : QuestGoal = quest.goals[i]
		var have : int = quest.goal_progress(player, i) if started else 0
		var need : int = goal.needed()
		var met : bool = finished or have >= need
		draw_rect(Rect2(inner.position.x, y + 1.0, 2.0, 2.0), Color(0.3, 0.7, 0.3) if met else skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x + 4.0, y + font.get_ascent(3)), goal.describe(), 3, skin.text if not met else skin.dim, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 22.0)
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), "Done" if met else ("%d/%d" % [mini(have, need), need] if need > 1 else ""), 3, Color(0.3, 0.6, 0.3) if met else skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
		y += 4.0
		if need > 1 and not met:
			UiKit.bar(self, Rect2(inner.position.x + 4.0, y, inner.size.x - 4.0, 1.0), float(have) / need, Color(0.85, 0.6, 0.1), Color(0.5, 0.4, 0.28, 0.5))
			y += 2.0
		y += 1.0
	# Rewards, with icons.
	var rewards : Array = []
	if quest.rewardCoins > 0:
		rewards.append(["$%d" % Quest.shared_coins(quest.rewardCoins), null])
	for i in quest.rewardItems.size():
		var thing : Item = quest.rewardItems[i]
		if thing:
			var amount : int = quest.rewardAmounts[i] if i < quest.rewardAmounts.size() else 1
			rewards.append([thing.displayName + (" x%d" % amount if amount > 1 else ""), thing])
	for place in quest.unlocks:
		if place:
			rewards.append(["Opens " + place.displayName, null])
	if not quest.rewardText.is_empty():
		rewards.append([quest.rewardText, null])
	if not rewards.is_empty():
		y += 2.0
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), "Rewards", 3, skin.title)
		y += 5.0
		for reward in rewards:
			var x : float = inner.position.x
			var thing : Item = reward[1]
			if thing and thing.icon:
				ui.draw_icon(self, thing.icon, Vector2(x + 3.0, y + 1.5), Color.WHITE, ui.outline_color(thing), minf(1.0, 6.0 / maxf(thing.icon.get_width(), thing.icon.get_height())))
				x += 8.0
			UiKit.label(self, font, Vector2(x, y + font.get_ascent(3)), reward[0], 3, Color(0.55, 0.36, 0.08), HORIZONTAL_ALIGNMENT_LEFT, inner.end.x - x)
			y += 5.0
	detailHeight = y + detailScroll - inner.position.y + 4.0
	# Who to bring it back to, and the button.
	if not finished:
		var ready : bool = quest.ready(player)
		draw_rect(Rect2(cardRect.position.x + 1.0, buttonRect.position.y - 2.0, cardRect.size.x - 2.0, cardRect.end.y - buttonRect.position.y + 1.0), skin.shade)
		UiKit.label(self, font, Vector2(inner.position.x, UiKit.baseline(font, buttonRect, 3)), ("Ready! Go back to " if ready else "Hand in to ") + Friendship.short_name(giverId) if not giverId.is_empty() else quest.giver, 3, Color(0.3, 0.6, 0.3) if ready else skin.dim, HORIZONTAL_ALIGNMENT_LEFT, buttonRect.position.x - inner.position.x - 2.0)
		var tracking : bool = player.progress.tracked == quest
		UiKit.button(self, font, skin, buttonRect, "On screen" if tracking else "Track", 3, not tracking, buttonRect.has_point(mouse))
