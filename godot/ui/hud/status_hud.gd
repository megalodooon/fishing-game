extends Control
class_name StatusHud

# Small HUD extras: the weather icon beside the clock (hover for its effect
# and tomorrow's forecast), the tracked quest's next goal under the date
# (only shown, so clicks there still cast) and the food buffs running, as icons left of
# the energy bar with a bar for the time they have left. Skill XP pops up in the
# bottom left as it's earned, and a banner shows each level up.

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var weather : Weather
@export var cycle : DayNightCycle
@export var weatherAt : Vector2 = Vector2(45.0, 1.0)
@export var trackerAt : Vector2 = Vector2(3.0, 18.0)
@export var trackerWidth : float = 100.0
@export var outline : Color = Color(0.04, 0.1, 0.16, 1.0)
@export var questColor : Color = Color(1.0, 0.9, 0.4)
@export var buffSize : float = 9.0
# Room right of the buffs, for the energy bar.
@export var buffRight : float = 13.0
@export var showTracker : bool = true:
	set(value):
		showTracker = value
		queue_redraw()

var weatherRect : Rect2
var eventRects : Array[Rect2] = []
var buffRects : Array[Rect2] = []
var buffList : Array[Array] = []
var mouse : Vector2 = Vector2(-100.0, -100.0)
var tick : float = 0.0
# Recent XP: skill, amount, age.
var gains : Array[Array] = []
# Level up banners waiting: skill, level, age.
var banners : Array[Array] = []
#------------------------#


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	set_anchors_preset(PRESET_TOP_LEFT)
	ui.laid_out.connect(fit)
	if weather:
		weather.changed.connect(queue_redraw.unbind(1))
	player.progress.changed.connect(queue_redraw)
	player.inventory.changed.connect(queue_redraw)
	player.xp_gained.connect(on_xp)
	player.skill_up.connect(func(skill : StringName, level : int) -> void: banners.append([skill, level, 0.0]))
	fit()

func on_xp(skill : StringName, amount : float) -> void:
	for gain in gains:
		if gain[0] == skill and gain[2] < 1.5:
			gain[1] += amount
			gain[2] = 0.0
			return
	gains.append([skill, amount, 0.0])
	if gains.size() > 4:
		gains.pop_front()

func fit() -> void:
	scale = ui.scale
	size = ui.size
	queue_redraw()

func _has_point(point : Vector2) -> bool:
	if weatherRect.has_point(point):
		return true
	for area in eventRects:
		if area.has_point(point):
			return true
	for area in buffRects:
		if area.has_point(point):
			return true
	return false

func _notification(what : int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse = Vector2(-100.0, -100.0)
		queue_redraw()

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		queue_redraw()

func _process(delta : float) -> void:
	for gain in gains:
		gain[2] += delta
	gains = gains.filter(func(gain : Array) -> bool: return gain[2] < 2.6)
	if not banners.is_empty():
		banners[0][2] += delta
		if banners[0][2] > 3.2:
			banners.pop_front()
	if not gains.is_empty() or not banners.is_empty():
		queue_redraw()
	tick += delta
	if tick >= 1.0:
		tick = 0.0
		queue_redraw()
	# The treasure compass follows the camera every frame while a trail is on.
	if Digging.active_here(player):
		queue_redraw()

# An arrow to the next treasure spot: over it when it's on screen, at the
# screen's edge pointing the way when it isn't.
func draw_compass() -> void:
	var goal : Vector2 = Digging.target(player)
	if goal == Vector2.INF:
		return
	var at : Vector2 = (get_viewport().get_canvas_transform() * goal) / maxf(ui.scale.x, 0.01)
	var view : Rect2 = Rect2(Vector2.ZERO, size).grow(-10.0)
	var dig : Dictionary = Digging.trail(player.progress)
	var label : String = "%d/%d" % [int(dig.index) + 1, (dig.points as Array).size()]
	var bob : float = roundf(sin(Time.get_ticks_msec() * 0.006) * 1.5)
	if view.has_point(at):
		var tip : Vector2 = at + Vector2(0.0, -7.0 + bob)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-2.5, -3.0), tip + Vector2(2.5, -3.0), tip]), Digging.COLOR)
		return
	var center : Vector2 = size * 0.5
	var direction : Vector2 = (at - center).normalized()
	var edge : Vector2 = Vector2(clampf(at.x, view.position.x, view.end.x), clampf(at.y, view.position.y, view.end.y))
	var side : Vector2 = direction.orthogonal()
	var point : Vector2 = edge + direction * bob
	draw_colored_polygon(PackedVector2Array([point + direction * 4.0, point - direction * 2.0 + side * 3.0, point - direction * 2.0 - side * 3.0]), Digging.COLOR)
	UiKit.label(self, ui.font, point - direction * 9.0 + Vector2(-6.0, 1.0), label, ui.statSize, Digging.COLOR, HORIZONTAL_ALIGNMENT_CENTER, 12.0, outline)

func tracked_quest() -> Quest:
	var quest : Quest = player.progress.tracked
	if quest and player.progress.quest_active(quest):
		return quest
	var going : Array[Quest] = player.progress.active_quests()
	return going[0] if not going.is_empty() else null

func _draw() -> void:
	var font : Font = ui.font
	var tip : Array = []
	draw_compass()
	if weather:
		var icon : Texture2D = weather.icon(weather.state)
		weatherRect = Rect2(weatherAt, icon.get_size() if icon else Vector2(8.0, 8.0))
		if icon:
			draw_texture(icon, weatherAt)
		if weatherRect.has_point(mouse):
			var ahead : int = weather.forecast()
			tip = [Weather.NAMES[weather.state], PackedStringArray(["Effect", weather.effect_text(weather.state), "Tomorrow", Weather.NAMES[ahead]])]
	eventRects.clear()
	var badgeX : float = weatherRect.end.x + 2.0 if weather else weatherAt.x
	for event in EventDirector.active(get_tree()):
		var area : Rect2 = Rect2(badgeX, weatherAt.y + 1.0, 12.0, 12.0)
		eventRects.append(area)
		draw_rect(area, Color(0.03, 0.06, 0.11, 0.55))
		draw_rect(Rect2(area.position.x, area.end.y - 1.0, area.size.x, 1.0), event.color)
		if event.icon:
			draw_texture_rect(event.icon, Rect2(area.position + Vector2(0.0, -1.0), Vector2(12.0, 12.0)), false)
		if area.has_point(mouse):
			var cycle_day : int = cycle.day if cycle else 1
			var left : int = event.days_left(cycle_day) - 1
			var lines : PackedStringArray = PackedStringArray(["Festival fish", "biting now"]) if event.page else PackedStringArray()
			for key in event.stats:
				lines.append_array([Stats.name_of(key), Stats.bonus_text(key, event.stats[key])])
			lines.append_array(["Ends", "today" if left <= 0 else "in %d day%s" % [left, "" if left == 1 else "s"], "Hours", event.hours_text()])
			tip = [event.displayName, lines]
		badgeX += 13.0
	var quest : Quest = tracked_quest() if showTracker else null
	if quest:
		var goal : int = quest.next_goal(player)
		var line : String = "Hand in to %s" % quest.giver if goal < 0 else quest.goals[goal].describe()
		if goal >= 0 and quest.goals[goal].needed() > 1:
			line += " %d/%d" % [quest.goal_progress(player, goal), quest.goals[goal].needed()]
		var titleY : float = trackerAt.y + font.get_ascent(ui.statSize + 1)
		draw_rect(Rect2(trackerAt.x, trackerAt.y + 1.0, 2.0, 2.0), questColor)
		draw_string_outline(font, Vector2(trackerAt.x + 4.0, titleY), quest.title, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize + 1, 2, outline)
		draw_string(font, Vector2(trackerAt.x + 4.0, titleY), quest.title, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize + 1, questColor)
		var lineY : float = trackerAt.y + ui.statSize + 3.0 + font.get_ascent(ui.statSize)
		var lineColor : Color = Color(0.56, 0.93, 0.44) if goal < 0 else ui.textColor
		draw_string_outline(font, Vector2(trackerAt.x + 4.0, lineY), line, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize, 2, outline)
		draw_string(font, Vector2(trackerAt.x + 4.0, lineY), line, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize, lineColor)
	draw_pinned(font, 18.0 + (ui.statSize * 2.0 + 5.0 if quest else 0.0))
	buffRects.clear()
	buffList = player.progress.active_buffs(Progress.clock(get_tree()))
	var x : float = size.x - buffRight - buffSize
	for buff in buffList:
		var area : Rect2 = Rect2(x, size.y - 2.0 - buffSize, buffSize, buffSize)
		buffRects.append(area)
		draw_rect(area, ui.frameColor)
		draw_rect(area.grow(-1.0), ui.slotColor)
		var icon : Texture2D = buff[3]
		if icon:
			ui.draw_icon(self, icon, area.get_center() - Vector2(0.0, 0.5), Color.WHITE, ui.outlineColor, minf(1.0, (buffSize - 3.0) / maxf(icon.get_width(), icon.get_height())))
		var left : float = clampf(buff[2] / 6.0, 0.0, 1.0)
		draw_rect(Rect2(area.position.x + 1.0, area.end.y - 2.0, (area.size.x - 2.0) * left, 1.0), Color(0.56, 0.93, 0.44))
		if area.has_point(mouse):
			tip = [Snack.BUFF_NAMES.get(buff[0], String(buff[0])), PackedStringArray(["Boost", "x%.2f" % buff[1], "Time left", "%dh%02d" % [floori(buff[2]), floori(fmod(buff[2], 1.0) * 60.0)]])]
		x -= buffSize + 1.0
	draw_gains(font)
	draw_banner(font)
	if not tip.is_empty():
		ui.paint_tip(self, mouse, tip[0], ui.textColor, tip[1], ui.tip_size(tip[0], tip[1]))

# The pinned recipe under the quest, with each ingredient counted.
func draw_pinned(font : Font, y : float) -> void:
	var recipe : BaitRecipe = player.progress.pinnedRecipe
	if not recipe or not recipe.result() or not showTracker:
		return
	var made : Item = recipe.result()
	var x : float = trackerAt.x + 4.0
	var titleY : float = y + font.get_ascent(ui.statSize)
	var makeable : bool = recipe.can_craft(player.inventory)
	draw_rect(Rect2(trackerAt.x, y + 1.0, 2.0, 2.0), Color(0.56, 0.93, 0.44) if makeable else Color(0.75, 0.62, 0.45))
	draw_string_outline(font, Vector2(x, titleY), made.displayName, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize, 2, outline)
	draw_string(font, Vector2(x, titleY), made.displayName, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize, Color(0.56, 0.93, 0.44) if makeable else Color(0.95, 0.85, 0.65))
	y += ui.statSize + 2.0
	for i in mini(recipe.ingredients.size(), 3):
		var have : int = recipe.have(i, player.inventory)
		var need : int = recipe.needed(i)
		var line : String = "%s %d/%d" % [BaitRecipe.ingredient_name(recipe.ingredients[i]), mini(have, need), need]
		var lineY : float = y + font.get_ascent(ui.statSize)
		draw_string_outline(font, Vector2(x + 2.0, lineY), line, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize, 2, outline)
		draw_string(font, Vector2(x + 2.0, lineY), line, HORIZONTAL_ALIGNMENT_LEFT, trackerWidth, ui.statSize, Color(0.56, 0.93, 0.44) if have >= need else ui.textColor)
		y += ui.statSize + 1.0

func draw_gains(font : Font) -> void:
	var y : float = size.y - 20.0
	for i in range(gains.size() - 1, -1, -1):
		var gain : Array = gains[i]
		var alpha : float = clampf((2.6 - gain[2]) / 0.6, 0.0, 1.0)
		var text : String = "+%s %s XP" % [String.num(gain[1], 0) if gain[1] >= 10.0 else String.num(gain[1], 1), Skills.NAMES[gain[0]]]
		var color : Color = Color(Skills.COLORS[gain[0]], alpha)
		draw_string_outline(font, Vector2(3.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, 2, Color(outline, alpha))
		draw_string(font, Vector2(3.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.statSize, color)
		y -= ui.statSize + 2.0

func draw_banner(font : Font) -> void:
	if banners.is_empty():
		return
	var banner : Array = banners[0]
	var age : float = banner[2]
	var pop : float = clampf(age / 0.25, 0.0, 1.0)
	var alpha : float = clampf((3.2 - age) / 0.5, 0.0, 1.0) * pop
	var color : Color = Skills.COLORS[banner[0]]
	var box : Rect2 = Rect2(floorf(size.x * 0.5 - 50.0), 20.0 - (1.0 - pop) * 4.0, 100.0, 17.0)
	draw_rect(box, Color(ui.frameColor, 0.92 * alpha))
	draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 1.0), Color(color, alpha))
	draw_rect(Rect2(box.position.x, box.end.y - 1.0, box.size.x, 1.0), Color(color, alpha))
	var title : String = "%s LEVEL %d" % [String(Skills.NAMES[banner[0]]).to_upper(), banner[1]]
	draw_string(font, Vector2(box.position.x, box.position.y + 2.0 + font.get_ascent(ui.titleSize)), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, ui.titleSize, Color(color, alpha))
	draw_string(font, Vector2(box.position.x, box.position.y + ui.titleSize + 4.0 + font.get_ascent(ui.statSize)), Skills.perk_text(banner[0]), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, ui.statSize, Color(ui.textColor, alpha))