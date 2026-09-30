extends MenuPanel
class_name DialogueUI

# The talking box at the bottom of the screen. It plays scenes (the speaker's
# portrait and name, the text typing itself out, choices at the end) and
# holds conversations with villagers (converse): their portrait card with
# the friendship hearts, a line from them, and a menu beside the box to talk,
# see their jobs, open their shop or service, give a gift or say goodbye.
# Jobs open a board of cards (what they want, the goals, the rewards) to take
# or hand in; gifts open a picker of what's in the bag. Click, F, Space or
# Enter to go on, Esc to go back or skip ahead. The game pauses while it's
# open. Also shows the full screen chapter cards.

const GROUP : StringName = &"dialogue_uis"
enum Mode { LINES, MENU, JOBS, GIFT }
enum Zone { NONE, OPTION, MENU, JOB, BUTTON, SLOT }
const ICONS : Dictionary = {
	"talk": preload("res://ui/dialogue/icons/talk.png"),
	"jobs": preload("res://ui/dialogue/icons/jobs.png"),
	"shop": preload("res://ui/dialogue/icons/shop.png"),
	"service": preload("res://ui/dialogue/icons/service.png"),
	"gift": preload("res://ui/dialogue/icons/gift.png"),
	"bye": preload("res://ui/dialogue/icons/bye.png"),
}
const REACTIONS : Dictionary = {
	"loved": "Oh! I love this! How did you know?",
	"liked": "Thank you, this is lovely.",
	"neutral": "Thanks, that's kind of you.",
	"disliked": "Oh... thanks, I suppose.",
	"hated": "Ugh. Why would you give me this?",
}
const REACTION_COLORS : Dictionary = {"loved": Color(1.0, 0.45, 0.6), "liked": Color(0.56, 0.93, 0.44), "neutral": Color(0.82, 0.86, 0.92), "disliked": Color(0.95, 0.7, 0.4), "hated": Color(0.95, 0.38, 0.34)}
const HEART_SHAPE : Array[Vector2i] = [Vector2i(1, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]
const GIFT_COLUMNS : int = 10

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var charsPerSecond : float = 55.0
@export var boxHeight : float = 38.0
@export var textSize : int = 4
@export var cardTime : float = 3.2
@export var dimColor : Color = Color(0.0, 0.02, 0.05, 0.3)
@export var nameColor : Color = Color(0.09, 0.14, 0.22, 1.0)
# Parchment by default: dark ink on paper.
@export var skin : MenuSkin

var mode : Mode = Mode.LINES
var queue : Array = []
var index : int = 0
var typed : float = 0.0
var options : PackedStringArray = PackedStringArray()
var picked : int = 0
var done : Callable = Callable()
var box : Rect2
var optionRects : Array[Rect2] = []
var mouse : Vector2 = Vector2(-100.0, -100.0)
var cardTitle : String = ""
var cardSub : String = ""
var cardAge : float = -1.0
var wrapped : PackedStringArray = PackedStringArray()
var time : float = 0.0
var pausedBefore : bool = false
var zone : Zone = Zone.NONE
var hoverIndex : int = -1
# The conversation.
var npc : Npc
var menuItems : Array = []
var menuRect : Rect2
var menuRects : Array[Rect2] = []
var menuPick : int = 0
var jobs : Array[Quest] = []
var jobPick : int = 0
var boardRect : Rect2
var jobRects : Array[Rect2] = []
var buttonRects : Array[Rect2] = []
var slotRects : Array[Rect2] = []
var slotItems : Array[int] = []
var giftPick : int = 0
var heartPop : float = -1.0
var heartGain : int = 0
#------------------------#


func _ready() -> void:
	super()
	add_to_group(GROUP)
	process_mode = PROCESS_MODE_ALWAYS
	slide = Vector2(0.0, 6.0)
	set_anchors_preset(PRESET_TOP_LEFT)
	if not skin:
		skin = load("res://ui/skins/themes/paper.tres") as MenuSkin
	ui.laid_out.connect(fit)
	fit()

static func find(tree : SceneTree) -> DialogueUI:
	return tree.get_first_node_in_group(GROUP) as DialogueUI

func fit() -> void:
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	box = Rect2(4.0, size.y - boxHeight - 3.0, size.x - 8.0, boxHeight)
	layout_menu()
	rewrap()

func _has_point(_point : Vector2) -> bool:
	return shown

func busy() -> bool:
	return shown or cardAge >= 0.0

# ---------------------------------------------------------------- scenes

# Plays a scene from the dialogue file, then calls done with the choice
# picked (or -1 when there were none).
func play(id : String, callback : Callable = Callable()) -> void:
	var lines : Array = Dialogue.lines(id)
	if lines.is_empty():
		if callback.is_valid():
			callback.call(-1)
		return
	start(lines, Dialogue.choices(id), callback)

# A single line, with choices.
func say(who : String, text : String, choices : PackedStringArray, callback : Callable = Callable()) -> void:
	start([[who, text]], choices, callback)

func start(lines : Array, choices : PackedStringArray, callback : Callable) -> void:
	mode = Mode.LINES
	npc = null
	queue = lines
	index = 0
	typed = 0.0
	options = choices
	picked = 0
	done = callback
	begin()

func begin() -> void:
	var counter : CounterUI = CounterUI.find(get_tree())
	if counter and counter.shown:
		counter.close()
	if not shown:
		pausedBefore = get_tree().paused
		get_tree().paused = true
		if player:
			player.frozen = true
	rewrap()
	open_menu()

func speaker() -> String:
	return queue[index][0] if index < queue.size() else ""

func rewrap() -> void:
	if queue.is_empty() or index >= queue.size() or not ui:
		wrapped = PackedStringArray()
		return
	var width : float = box.size.x - (40.0 if portrait_of(speaker()) else 8.0)
	wrapped = ui.wrap_lines(queue[index][1], width, textSize)

func portrait_of(who : String) -> Texture2D:
	return null if who == "narrator" or who.is_empty() else Cast.portrait(who)

func line_length() -> int:
	return queue[index][1].length() if index < queue.size() else 0

func at_end() -> bool:
	return index >= queue.size() - 1 and typed >= line_length()

func advance() -> void:
	if typed < line_length():
		typed = line_length()
		return
	if index < queue.size() - 1:
		index += 1
		typed = 0.0
		rewrap()
		return
	if mode == Mode.LINES and options.is_empty():
		finish(-1)

func finish(choice : int) -> void:
	close_menu()
	get_tree().paused = pausedBefore
	if player:
		player.frozen = false
	var callback : Callable = done
	done = Callable()
	queue = []
	npc = null
	mode = Mode.LINES
	if callback.is_valid():
		callback.call(choice)

func card(title : String, subtitle : String) -> void:
	cardTitle = title
	cardSub = subtitle
	cardAge = 0.0
	visible = true
	modulate.a = 1.0

# ---------------------------------------------------------------- conversations

func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

# Opens a conversation with a villager: a greeting, then the menu.
func converse(who : Npc, with_player : Player) -> void:
	player = with_player if with_player else player
	npc = who
	mode = Mode.MENU
	queue = [[who.id, greeting_line()]]
	index = 0
	typed = 0.0
	options = PackedStringArray()
	done = Callable()
	build_menu()
	menuPick = 0
	begin()

func greeting_line() -> String:
	var day : int = today()
	if Friendship.is_birthday(npc.id, day):
		return "It's my birthday today! Did you remember?"
	var line : Array = Dialogue.random_line(npc.id + "_hello")
	if not line.is_empty():
		return line[1]
	return npc.greeting

func build_menu() -> void:
	menuItems.clear()
	var talked : bool = Friendship.talked_today(player.progress, npc.id, today())
	menuItems.append(["talk", "Talk", "" if talked else "+"])
	var waiting : Array[Quest] = npc.jobs(player)
	if not waiting.is_empty():
		var ready_count : int = 0
		var fresh : int = 0
		for quest in waiting:
			if quest.ready(player):
				ready_count += 1
			elif quest.available(player):
				fresh += 1
		menuItems.append(["jobs", "Jobs", "?" if ready_count > 0 else ("!" if fresh > 0 else "")])
	if npc.shop:
		menuItems.append(["shop", npc.shopLabel, ""])
	if npc.service:
		menuItems.append(["service", npc.serviceLabel, ""])
	if Friendship.TASTES.has(npc.id):
		menuItems.append(["gift", "Gift", ""])
	menuItems.append(["bye", "Bye", ""])
	layout_menu()

func layout_menu() -> void:
	menuRects.clear()
	var width : float = 50.0
	var height : float = menuItems.size() * 9.0 + 4.0
	menuRect = Rect2(box.end.x - width - 2.0, box.position.y - height - 2.0, width, height)
	for i in menuItems.size():
		menuRects.append(Rect2(menuRect.position.x + 2.0, menuRect.position.y + 2.0 + i * 9.0, menuRect.size.x - 4.0, 8.0))

func choose_menu(i : int) -> void:
	if i < 0 or i >= menuItems.size():
		return
	match menuItems[i][0]:
		"talk":
			talk()
		"jobs":
			open_jobs()
		"shop", "service":
			var counter : Counter = npc.shop if menuItems[i][0] == "shop" else npc.service
			var who : Player = player
			finish(-1)
			counter.interact(who)
		"gift":
			open_gift()
		"bye":
			finish(-1)

func show_line(text : String) -> void:
	queue = [[npc.id, text]]
	index = 0
	typed = 0.0
	rewrap()

func talk() -> void:
	var hearts : int = Friendship.hearts(player.progress, npc.id)
	var pools : PackedStringArray = PackedStringArray([npc.id + "_chat"])
	if hearts >= 4:
		pools.append(npc.id + "_chat_friend")
	if hearts >= 8:
		pools.append(npc.id + "_chat_close")
	pools.append("%s_chat_%s" % [npc.id, Calendar.season_name(today()).to_lower()])
	var lines : Array = []
	for pool in pools:
		lines.append_array(Dialogue.lines(pool))
	var line : Array = lines.pick_random() if not lines.is_empty() else [npc.id, npc.greeting]
	show_line(line[1])
	if Friendship.talk(player, npc.id, today()):
		pop_hearts(Friendship.TALK_POINTS)
	build_menu()

func pop_hearts(amount : int) -> void:
	heartGain = amount
	heartPop = 0.0

# ---------------------------------------------------------------- jobs

func open_jobs() -> void:
	jobs = npc.jobs(player)
	if jobs.is_empty():
		show_line("Nothing I need right now. Thanks for asking.")
		build_menu()
		return
	mode = Mode.JOBS
	jobPick = 0
	for i in jobs.size():
		if jobs[i].ready(player):
			jobPick = i
			break
	layout_jobs()
	pitch_job()

func layout_jobs() -> void:
	var top : float = MenuHub.top_of(get_tree(), 4.0) if is_inside_tree() else 4.0
	boardRect = Rect2(6.0, top, size.x - 12.0, box.position.y - top - 11.0)
	jobRects.clear()
	var list : Rect2 = Rect2(boardRect.position + Vector2(3.0, 11.0), Vector2(58.0, boardRect.size.y - 14.0))
	for i in jobs.size():
		jobRects.append(Rect2(list.position.x, list.position.y + i * 9.0, list.size.x, 8.0))
	buttonRects = [Rect2(boardRect.end.x - 66.0, boardRect.end.y - 11.0, 38.0, 8.0), Rect2(boardRect.end.x - 26.0, boardRect.end.y - 11.0, 22.0, 8.0)]

func pitch_job() -> void:
	var quest : Quest = jobs[jobPick]
	if quest.ready(player):
		show_line("You did it? Let me see!")
	elif player.progress.quest_active(quest):
		show_line("How's it going with %s?" % quest.title.to_lower())
	else:
		var pitch : Array = Dialogue.lines(quest.startScene)
		show_line(pitch[0][1] if not pitch.is_empty() and pitch[0][0] == npc.id else quest.description)

func job_action_text(quest : Quest) -> String:
	if quest.ready(player):
		return "Hand in"
	if player.progress.quest_active(quest):
		return "Not yet"
	return "Accept"

func job_action(quest : Quest) -> void:
	if quest.ready(player):
		if not quest.turn_in(player):
			show_line("Your bag's too full for what I owe you. Make some room!")
			return
		var names : PackedStringArray = QuestBoard.reward_names(quest)
		var board : NoticeBoard = NoticeBoard.find(get_tree())
		if board:
			board.post("Quest complete!", quest.title + (": " + ", ".join(names) if not names.is_empty() else ""), Color(0.56, 0.93, 0.44))
		Friendship.add(player, npc.id, 30)
		finish(-1)
	elif quest.available(player):
		player.progress.start_quest(quest)
		player.progress.tracked = quest
		finish(-1)

# ---------------------------------------------------------------- gifts

func open_gift() -> void:
	var why : String = Friendship.gift_blocked(player.progress, npc.id, today())
	if not why.is_empty():
		show_line(why + ". Come back another day!" if why.begins_with("Already") else "You've given me so much this week already!")
		build_menu()
		return
	mode = Mode.GIFT
	slotItems.clear()
	for slot in player.inventory.trashSlot:
		var item : Item = player.inventory.get_item(slot)
		if item and item.discardable and item.category != "Key Item":
			slotItems.append(slot)
	giftPick = 0
	layout_gifts()
	show_line("For me? What is it?" if not slotItems.is_empty() else "Your bag's empty! Bring me something next time.")

func layout_gifts() -> void:
	slotRects.clear()
	var cell : float = 13.0
	var rows : int = maxi(ceili(slotItems.size() / float(GIFT_COLUMNS)), 1)
	var width : float = GIFT_COLUMNS * cell + 6.0
	var height : float = rows * cell + 16.0
	boardRect = Rect2(floorf((size.x - width) * 0.5), box.position.y - height - 11.0, width, height)
	for i in slotItems.size():
		@warning_ignore("integer_division")
		slotRects.append(Rect2(boardRect.position + Vector2(3.0 + (i % GIFT_COLUMNS) * cell, 12.0 + (i / GIFT_COLUMNS) * cell), Vector2(cell - 1.0, cell - 1.0)))

func give(i : int) -> void:
	if i < 0 or i >= slotItems.size():
		return
	var item : Item = player.inventory.get_item(slotItems[i])
	if not item:
		return
	var before : int = Friendship.points(player.progress, npc.id)
	var reaction : String = Friendship.give(player, npc.id, slotItems[i], today())
	player.progress.set_flag("taste/%s/%s" % [npc.id, item.original().resource_path.get_file().get_basename()], reaction)
	var own : Array = Dialogue.random_line("%s_gift_%s" % [npc.id, reaction])
	var text : String = own[1] if not own.is_empty() else REACTIONS[reaction]
	if Friendship.is_birthday(npc.id, today()) and reaction != "hated" and reaction != "disliked":
		text = "For my birthday? " + text
	mode = Mode.MENU
	show_line(text)
	pop_hearts(Friendship.points(player.progress, npc.id) - before)
	build_menu()

func known_taste(item : Item) -> String:
	return String(player.progress.get_flag("taste/%s/%s" % [npc.id, item.original().resource_path.get_file().get_basename()], ""))

# ---------------------------------------------------------------- input

func _input(event : InputEvent) -> void:
	if cardAge >= 0.0:
		if event is InputEventMouseButton or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			cardAge = maxf(cardAge, cardTime - 0.5)
			get_viewport().set_input_as_handled()
		return
	if not shown:
		return
	if event is InputEventMouseMotion:
		mouse = (make_input_local(event) as InputEventMouse).position
		hover(mouse)
		return
	var click : bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var accept : bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	var back : bool = event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
	var up : bool = event.is_action_pressed("ui_up") or event.is_action_pressed("up")
	var down : bool = event.is_action_pressed("ui_down") or event.is_action_pressed("down")
	var left : bool = event.is_action_pressed("ui_left") or event.is_action_pressed("left")
	var right : bool = event.is_action_pressed("ui_right") or event.is_action_pressed("right")
	if click:
		hover((make_input_local(event) as InputEventMouse).position)
	match mode:
		Mode.LINES:
			input_lines(click, accept, back, up or left, down or right)
		Mode.MENU:
			if typed < line_length() and (click or accept):
				typed = line_length()
			elif click and zone == Zone.MENU:
				choose_menu(hoverIndex)
			elif accept:
				choose_menu(menuPick)
			elif back:
				finish(-1)
			elif up or down:
				menuPick = posmod(menuPick + (1 if down else -1), menuItems.size())
		Mode.JOBS:
			if click and zone == Zone.JOB:
				jobPick = hoverIndex
				pitch_job()
			elif (click and zone == Zone.BUTTON and hoverIndex == 0) or accept:
				job_action(jobs[jobPick])
			elif (click and zone == Zone.BUTTON and hoverIndex == 1) or back:
				mode = Mode.MENU
				show_line("Anything else?")
				build_menu()
			elif up or down:
				jobPick = posmod(jobPick + (1 if down else -1), jobs.size())
				pitch_job()
		Mode.GIFT:
			if click and zone == Zone.SLOT:
				give(hoverIndex)
			elif accept and not slotItems.is_empty():
				give(giftPick)
			elif back:
				mode = Mode.MENU
				show_line("Maybe another time, then.")
				build_menu()
			elif left or right:
				giftPick = clampi(giftPick + (1 if right else -1), 0, maxi(slotItems.size() - 1, 0))
			elif up or down:
				giftPick = clampi(giftPick + (GIFT_COLUMNS if down else -GIFT_COLUMNS), 0, maxi(slotItems.size() - 1, 0))
	get_viewport().set_input_as_handled()
	queue_redraw()

func input_lines(click : bool, accept : bool, back : bool, previous : bool, next : bool) -> void:
	if at_end() and not options.is_empty():
		if next:
			picked = posmod(picked + 1, options.size())
		elif previous:
			picked = posmod(picked - 1, options.size())
		elif click and zone == Zone.OPTION:
			finish(hoverIndex)
		elif accept:
			finish(picked)
		elif back:
			finish(options.size() - 1)
	elif click or accept:
		advance()
	elif back:
		index = queue.size() - 1
		typed = line_length()
		rewrap()

func hover(point : Vector2) -> void:
	zone = Zone.NONE
	hoverIndex = -1
	var groups : Array = [[Zone.OPTION, optionRects if mode == Mode.LINES else []], [Zone.MENU, menuRects if mode == Mode.MENU and typed >= line_length() else []], [Zone.JOB, jobRects if mode == Mode.JOBS else []], [Zone.BUTTON, buttonRects if mode == Mode.JOBS else []], [Zone.SLOT, slotRects if mode == Mode.GIFT else []]]
	for group in groups:
		var rects : Array = group[1]
		for i in rects.size():
			if (rects[i] as Rect2).has_point(point):
				zone = group[0]
				hoverIndex = i
				match zone:
					Zone.OPTION:
						picked = i
					Zone.MENU:
						menuPick = i
					Zone.SLOT:
						giftPick = i
				return

func _process(delta : float) -> void:
	time += delta
	if cardAge >= 0.0:
		if cardAge == 0.0:
			pausedBefore = get_tree().paused
			get_tree().paused = true
		cardAge += delta
		if cardAge >= cardTime:
			cardAge = -1.0
			get_tree().paused = pausedBefore
			if not shown:
				visible = false
		queue_redraw()
		return
	if heartPop >= 0.0:
		heartPop += delta
		if heartPop > 1.2:
			heartPop = -1.0
	if shown and index < queue.size():
		typed = minf(typed + charsPerSecond * delta, line_length())
		queue_redraw()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font : Font = ui.font
	if cardAge >= 0.0:
		var fade : float = clampf(minf(cardAge / 0.5, (cardTime - cardAge) / 0.5), 0.0, 1.0)
		draw_rect(Rect2(-position, size + Vector2(20.0, 20.0)), Color(0.01, 0.02, 0.05, fade))
		draw_string(font, Vector2(0.0, size.y * 0.42), cardSub, HORIZONTAL_ALIGNMENT_CENTER, size.x, textSize, Color(ui.dimColor, fade))
		draw_string(font, Vector2(0.0, size.y * 0.42 + 12.0), cardTitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(ui.selectedColor, fade))
		return
	if queue.is_empty() or index >= queue.size():
		return
	draw_rect(Rect2(-position, size + Vector2(20.0, 20.0)), dimColor)
	draw_box(font)
	match mode:
		Mode.LINES:
			draw_options(font)
		Mode.MENU:
			if typed >= line_length():
				draw_menu(font)
		Mode.JOBS:
			draw_jobs(font)
		Mode.GIFT:
			draw_gifts(font)

func draw_box(font : Font) -> void:
	var who : String = speaker()
	var face : Texture2D = portrait_of(who)
	draw_rect(Rect2(box.position + Vector2(2.0, 2.0), box.size), Color(0.0, 0.0, 0.0, 0.35))
	UiKit.box(self, skin.frame, box)
	var textX : float = box.position.x + 5.0
	if face:
		var frame : Rect2 = Rect2(box.position + Vector2(3.0, 3.0), Vector2(32.0, 32.0))
		UiKit.box(self, skin.card, frame)
		var talking : bool = typed < line_length() and fmod(time, 0.24) < 0.12
		var zoom : float = floorf(28.0 / maxf(face.get_width(), face.get_height()) * 2.0) * 0.5
		var drawn : Vector2 = face.get_size() * zoom
		draw_texture_rect(face, Rect2((frame.get_center() - drawn * 0.5 + Vector2(0.0, -1.0 if talking else 0.0)).round(), drawn), false)
		textX = frame.end.x + 4.0
	if who != "narrator" and not who.is_empty():
		var label : String = Cast.name_of(who)
		var width : float = UiKit.text_width(font, label, ui.statSize) + 8.0
		var tag : Rect2 = Rect2(box.position.x + 2.0, box.position.y - 7.0, width, 8.0)
		var tint : Color = Cast.color_of(who)
		draw_rect(tag, Color(0.12, 0.08, 0.05))
		draw_rect(tag.grow(-1.0), tint.darkened(0.55))
		draw_rect(Rect2(tag.position.x + 1.0, tag.position.y + 1.0, tag.size.x - 2.0, 1.0), tint.darkened(0.3))
		UiKit.label(self, font, Vector2(tag.position.x + 4.0, tag.position.y + 2.0 + font.get_ascent(ui.statSize)), label, ui.statSize, tint.lightened(0.35))
		if Friendship.TASTES.has(who) and player:
			draw_hearts(Vector2(tag.end.x + 3.0, tag.position.y + 2.0), who)
	var left : int = int(typed)
	var y : float = box.position.y + 4.0
	var color : Color = skin.text if who != "narrator" else skin.dim
	for line in wrapped:
		if left <= 0:
			break
		var part : String = line.substr(0, left)
		left -= line.length() + 1
		draw_string(font, Vector2(textX, y + font.get_ascent(textSize)), part, HORIZONTAL_ALIGNMENT_LEFT, -1, textSize, color)
		y += textSize + 2.0
	if typed >= line_length() and (mode == Mode.LINES and (index < queue.size() - 1 or options.is_empty())) and fmod(time, 0.8) < 0.5:
		var tip : Vector2 = Vector2(box.end.x - 6.0, box.end.y - 5.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-1.5, -1.0), tip + Vector2(1.5, -1.0), tip + Vector2(0.0, 0.8)]), skin.title)

# The friendship hearts beside the name tag, the one being filled partly.
func draw_hearts(at : Vector2, who : String) -> void:
	var hearts : int = Friendship.hearts(player.progress, who)
	var part : float = Friendship.heart_progress(player.progress, who)
	var backing : Rect2 = Rect2(at + Vector2(-2.0, -2.0), Vector2(Friendship.MAX_HEARTS * 6.0 + 3.0, 8.0))
	draw_rect(backing, Color(0.12, 0.08, 0.05, 0.85))
	for i in Friendship.MAX_HEARTS:
		var origin : Vector2 = at + Vector2(i * 6.0, 0.0)
		var fill : float = 1.0 if i < hearts else (part if i == hearts else 0.0)
		for cell in HEART_SHAPE:
			var lit : bool = cell.x < 5.0 * fill
			draw_rect(Rect2(origin + Vector2(cell), Vector2.ONE), Friendship.HEART_COLOR if lit else Color(0.35, 0.3, 0.32))
	if heartPop >= 0.0 and heartGain != 0 and npc and who == npc.id:
		var rise : float = heartPop * 8.0
		var fade : float = clampf(1.2 - heartPop, 0.0, 1.0)
		var text : String = ("+%d" if heartGain > 0 else "%d") % heartGain
		UiKit.label(self, ui.font, Vector2(backing.end.x + 2.0, at.y + 3.0 - rise + ui.font.get_ascent(ui.statSize) * 0.5), text, ui.statSize, Color(Friendship.HEART_COLOR if heartGain > 0 else Color(0.95, 0.5, 0.4), fade))

func draw_options(font : Font) -> void:
	optionRects.clear()
	if not at_end() or options.is_empty():
		return
	var x : float = box.end.x - 3.0
	for i in range(options.size() - 1, -1, -1):
		var width : float = UiKit.text_width(font, options[i], ui.statSize) + 8.0
		x -= width
		var area : Rect2 = Rect2(x, box.end.y - 10.0, width, 8.0)
		optionRects.push_front(area)
		UiKit.button(self, font, skin, area, options[i], ui.statSize, true, i == picked)
		x -= 2.0

func draw_menu(font : Font) -> void:
	draw_rect(Rect2(menuRect.position + Vector2(2.0, 2.0), menuRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, menuRect)
	for i in menuItems.size():
		var area : Rect2 = menuRects[i]
		var active : bool = i == menuPick
		if active:
			draw_rect(area, Color(skin.accent, 0.25))
			draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), skin.accent)
		var icon : Texture2D = ICONS.get(menuItems[i][0])
		if icon:
			draw_texture(icon, Vector2(area.position.x + 2.0, area.position.y), Color.WHITE if active else Color(1.0, 1.0, 1.0, 0.8))
		UiKit.label(self, font, Vector2(area.position.x + 12.0, UiKit.baseline(font, area, ui.statSize)), menuItems[i][1], ui.statSize, skin.title if active else skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 18.0)
		var badge : String = menuItems[i][2]
		if not badge.is_empty():
			var color : Color = Friendship.HEART_COLOR if badge == "+" else (Color(0.3, 0.7, 0.3) if badge == "?" else Color(0.85, 0.6, 0.1))
			UiKit.label(self, font, Vector2(area.position.x, UiKit.baseline(font, area, ui.statSize)), badge, ui.statSize, color, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 2.0)

func draw_jobs(font : Font) -> void:
	draw_rect(Rect2(boardRect.position + Vector2(2.0, 2.0), boardRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, boardRect)
	UiKit.label(self, font, Vector2(boardRect.position.x + 4.0, boardRect.position.y + 3.0 + font.get_ascent(ui.statSize)), "%s's jobs" % Friendship.short_name(npc.id), ui.statSize, skin.title)
	for i in jobs.size():
		var quest : Quest = jobs[i]
		var area : Rect2 = jobRects[i]
		if i == jobPick:
			draw_rect(area, Color(skin.accent, 0.25))
		elif zone == Zone.JOB and hoverIndex == i:
			draw_rect(area, skin.hover)
		var status : Color = Color(0.3, 0.7, 0.3) if quest.ready(player) else (Color(0.5, 0.55, 0.6) if player.progress.quest_active(quest) else Color(0.85, 0.6, 0.1))
		draw_rect(Rect2(area.position.x + 1.0, area.position.y + 3.0, 2.0, 2.0), status)
		UiKit.label(self, font, Vector2(area.position.x + 5.0, UiKit.baseline(font, area, ui.statSize)), quest.title, ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6.0)
	# The picked job's card.
	var quest_now : Quest = jobs[jobPick]
	var cardRect : Rect2 = Rect2(jobRects[0].end.x + 4.0 if not jobRects.is_empty() else boardRect.position.x + 4.0, boardRect.position.y + 3.0, 0.0, boardRect.size.y - 17.0)
	cardRect.size.x = boardRect.end.x - cardRect.position.x - 3.0
	UiKit.box(self, skin.well, cardRect)
	var inner : Rect2 = cardRect.grow(-3.0)
	var y : float = inner.position.y
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), quest_now.title, ui.statSize, Color(0.7, 0.45, 0.1) if quest_now.story else skin.title, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	y += ui.statSize + 2.0
	for line in ui.wrap_lines(quest_now.description, inner.size.x, ui.statSize).slice(0, 3):
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), line, ui.statSize, skin.dim)
		y += ui.statSize + 1.0
	y += 1.0
	var started : bool = player.progress.quest_started(quest_now)
	for i in quest_now.goals.size():
		if y + ui.statSize > inner.end.y:
			break
		var goal : QuestGoal = quest_now.goals[i]
		var have : int = quest_now.goal_progress(player, i) if started else 0
		var finished : bool = have >= goal.needed()
		draw_rect(Rect2(inner.position.x, y + 1.0, 2.0, 2.0), Color(0.3, 0.7, 0.3) if finished else skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x + 4.0, y + font.get_ascent(ui.statSize)), goal.describe(), ui.statSize, skin.text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 26.0)
		if started:
			UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(ui.statSize)), "%d/%d" % [mini(have, goal.needed()), goal.needed()], ui.statSize, Color(0.3, 0.6, 0.3) if finished else skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
		y += ui.statSize + 1.0
	var rewards : PackedStringArray = QuestBoard.reward_names(quest_now)
	if not rewards.is_empty() and y + ui.statSize <= inner.end.y:
		UiKit.label(self, font, Vector2(inner.position.x, y + 1.0 + font.get_ascent(ui.statSize)), "Reward: " + ", ".join(rewards), ui.statSize, Color(0.7, 0.5, 0.1), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	var action : String = job_action_text(quest_now)
	UiKit.button(self, font, skin, buttonRects[0], action, ui.statSize, action != "Not yet", zone == Zone.BUTTON and hoverIndex == 0)
	UiKit.button(self, font, skin, buttonRects[1], "Back", ui.statSize, true, zone == Zone.BUTTON and hoverIndex == 1)

func draw_gifts(font : Font) -> void:
	draw_rect(Rect2(boardRect.position + Vector2(2.0, 2.0), boardRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, boardRect)
	var left : int = Friendship.GIFTS_PER_WEEK - Friendship.gifts_this_week(player.progress, npc.id, today())
	UiKit.label(self, font, Vector2(boardRect.position.x + 4.0, boardRect.position.y + 3.0 + font.get_ascent(ui.statSize)), "Give a gift", ui.statSize, skin.title)
	UiKit.label(self, font, Vector2(boardRect.position.x, boardRect.position.y + 3.0 + font.get_ascent(ui.statSize)), "Birthday! x8" if Friendship.is_birthday(npc.id, today()) else "%d left this week" % maxi(left, 0), ui.statSize, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, boardRect.size.x - 4.0)
	for i in slotRects.size():
		var area : Rect2 = slotRects[i]
		var item : Item = player.inventory.get_item(slotItems[i])
		draw_rect(area, Color(0.2, 0.15, 0.1, 0.35))
		if i == giftPick:
			UiKit.brackets(self, area.grow(1.0), skin.title, time)
		if item:
			ui.draw_icon(self, item.icon, area.get_center(), Color.WHITE, ui.outline_color(item), minf(1.0, (area.size.x - 2.0) / maxf(item.icon.get_width(), item.icon.get_height())))
			var taste : String = known_taste(item)
			if not taste.is_empty():
				draw_rect(Rect2(area.end.x - 3.0, area.position.y + 1.0, 2.0, 2.0), REACTION_COLORS[taste])
	if giftPick >= 0 and giftPick < slotItems.size():
		var item : Item = player.inventory.get_item(slotItems[giftPick])
		if item:
			var taste : String = known_taste(item)
			var lines : PackedStringArray = PackedStringArray(["They %s it" % taste if not taste.is_empty() else "Not given before", ""])
			var anchor : Vector2 = slotRects[giftPick].end + Vector2(2.0, -4.0)
			ui.paint_tip(self, anchor if zone != Zone.SLOT else mouse, item.displayName, item.title_color(), lines, ui.tip_size(item.displayName, lines))
