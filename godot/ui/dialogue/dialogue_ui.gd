extends MenuPanel
class_name DialogueUI

# The talking box at the bottom of the screen. It plays scenes (the speaker's
# portrait on their side, their name tag, the text typing itself out, choices
# as buttons above the box) and holds conversations with villagers: a line
# from them, then a row of buttons above the box to talk, see their jobs,
# open their shop or service, give a gift or say goodbye, with their
# friendship hearts on the name tag. Jobs open a board (the list on the left,
# the picked job's card on the right) and gifts a picker of the bag beside
# what the villager is known to love, like, dislike and hate.
#
# Click, F, Space or Enter to go on; Esc to go back or skip ahead; Tab or E
# close a conversation. Lines can say {name} for the player's name. ask_name()
# asks for the player's name in the box. The game pauses while it's open
# (alone). Also shows the full screen chapter cards.

const GROUP : StringName = &"dialogue_uis"
enum Mode { LINES, MENU, JOBS, GIFT, NAME }
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
const GIFT_COLUMNS : int = 8
const PORTRAIT : float = 26.0
const BUTTON_HEIGHT : float = 9.0
const NAME_LENGTH : int = 14

#------------------------#
@export var player : Player
@export var ui : InventoryUI
@export var charsPerSecond : float = 55.0
@export var boxHeight : float = 31.0
@export var textSize : int = 3
@export var cardTime : float = 3.2
@export var dimColor : Color = Color(0.0, 0.02, 0.05, 0.25)
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
# The name being typed (Mode.NAME).
var typing : String = ""
#------------------------#


func _ready() -> void:
	super()
	add_to_group(GROUP)
	process_mode = PROCESS_MODE_ALWAYS
	slide = Vector2(0.0, 4.0)
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
	box = Rect2(6.0, size.y - boxHeight - 4.0, size.x - 12.0, boxHeight)
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

# Someone asks the player's name; the callback gets it once it's typed.
func ask_name(who : String, question : String, callback : Callable) -> void:
	start([[who, question]], PackedStringArray(), callback)
	mode = Mode.NAME
	typing = player.progress.playerName if player else ""

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
		get_tree().paused = not Net.has_company()
		if player:
			player.frozen = true
	rewrap()
	open_menu()

func speaker() -> String:
	return queue[index][0] if index < queue.size() else ""

# The line with {name} filled in.
func line_text(i : int) -> String:
	if i >= queue.size():
		return ""
	var text : String = queue[i][1]
	if text.contains("{name}"):
		text = text.replace("{name}", player_name())
	return text

func player_name() -> String:
	var name_now : String = player.progress.playerName if player else ""
	return name_now if not name_now.is_empty() else "friend"

func rewrap() -> void:
	if queue.is_empty() or index >= queue.size() or not ui:
		wrapped = PackedStringArray()
		return
	var width : float = box.size.x - 10.0 - (PORTRAIT + 4.0 if portrait_of(speaker()) else 0.0)
	wrapped = ui.wrap_lines(line_text(index), width, textSize)

func portrait_of(who : String) -> Texture2D:
	return null if who == "narrator" or who.is_empty() else Cast.portrait(who)

func line_length() -> int:
	return line_text(index).length()

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

func finish(choice : Variant) -> void:
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

# Opens a conversation with a villager: a greeting, then the buttons.
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

# The buttons sit in a row on the box's top edge, on the right.
func layout_menu() -> void:
	menuRects.clear()
	if not ui:
		return
	var x : float = box.end.x
	for i in range(menuItems.size() - 1, -1, -1):
		var width : float = UiKit.text_width(ui.font, menuItems[i][1], 3) + 14.0
		x -= width
		menuRects.push_front(Rect2(x, box.position.y - BUTTON_HEIGHT - 1.0, width, BUTTON_HEIGHT))
		x -= 1.0

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
	boardRect = Rect2(10.0, top, size.x - 20.0, box.position.y - top - 6.0)
	jobRects.clear()
	var list : Rect2 = Rect2(boardRect.position + Vector2(4.0, 12.0), Vector2(56.0, boardRect.size.y - 16.0))
	for i in jobs.size():
		jobRects.append(Rect2(list.position.x, list.position.y + i * 9.0, list.size.x, 8.0))
	buttonRects = [Rect2(boardRect.end.x - 64.0, boardRect.end.y - 12.0, 36.0, BUTTON_HEIGHT), Rect2(boardRect.end.x - 26.0, boardRect.end.y - 12.0, 22.0, BUTTON_HEIGHT)]

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
			board.banner("Quest complete!", quest.title + (": " + ", ".join(names) if not names.is_empty() else ""), Color(0.56, 0.93, 0.44))
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
	var cell : float = 12.0
	var rows : int = maxi(ceili(slotItems.size() / float(GIFT_COLUMNS)), 1)
	var width : float = GIFT_COLUMNS * cell + 6.0 + 70.0
	var height : float = maxf(rows * cell + 15.0, 48.0)
	var top : float = MenuHub.top_of(get_tree(), 4.0) if is_inside_tree() else 4.0
	boardRect = Rect2(floorf((size.x - width) * 0.5), maxf(box.position.y - height - 6.0, top), width, minf(height, box.position.y - top - 6.0))
	for i in slotItems.size():
		@warning_ignore("integer_division")
		slotRects.append(Rect2(boardRect.position + Vector2(3.0 + (i % GIFT_COLUMNS) * cell, 11.0 + (i / GIFT_COLUMNS) * cell), Vector2(cell - 1.0, cell - 1.0)))

func give(i : int) -> void:
	if i < 0 or i >= slotItems.size():
		return
	var item : Item = player.inventory.get_item(slotItems[i])
	if not item:
		return
	var before : int = Friendship.points(player.progress, npc.id)
	var reaction : String = Friendship.give(player, npc.id, slotItems[i], today())
	Friendship.learn_taste(player.progress, npc.id, item, reaction)
	var own : Array = Dialogue.random_line("%s_gift_%s" % [npc.id, reaction])
	var text : String = own[1] if not own.is_empty() else REACTIONS[reaction]
	if Friendship.is_birthday(npc.id, today()) and reaction != "hated" and reaction != "disliked":
		text = "For my birthday? " + text
	mode = Mode.MENU
	show_line(text)
	pop_hearts(Friendship.points(player.progress, npc.id) - before)
	build_menu()

func known_taste(item : Item) -> String:
	return Friendship.known_taste(player.progress, npc.id, item)

# ---------------------------------------------------------------- input

func _input(event : InputEvent) -> void:
	if cardAge >= 0.0:
		if event is InputEventMouseButton or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			cardAge = maxf(cardAge, cardTime - 0.5)
			get_viewport().set_input_as_handled()
		return
	if not shown:
		return
	if mode == Mode.NAME:
		input_name(event)
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if event is InputEventMouseMotion:
		mouse = (make_input_local(event) as InputEventMouse).position
		hover(mouse)
		return
	# Tab and E close a conversation (and skip a scene without choices).
	if event.is_action_pressed("hub") or event.is_action_pressed("backpack"):
		if mode != Mode.LINES:
			finish(-1)
		elif options.is_empty():
			index = queue.size() - 1
			finish(-1)
		get_viewport().set_input_as_handled()
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
			elif left or right or up or down:
				menuPick = posmod(menuPick + (1 if right or down else -1), menuItems.size())
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

# Typing a name: letters, digits, spaces and a few marks; Enter takes it.
func input_name(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if not key or not key.pressed:
		return
	if typed < line_length():
		typed = line_length()
		return
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var chosen : String = typing.strip_edges()
		if not chosen.is_empty():
			if player:
				player.progress.playerName = chosen
				player.progress.emit_changed()
			finish(chosen)
	elif key.keycode == KEY_BACKSPACE:
		typing = typing.left(typing.length() - 1)
	elif key.unicode >= 32 and key.unicode < 127 and typing.length() < NAME_LENGTH:
		var letter : String = char(key.unicode)
		if letter.is_valid_identifier() or letter in [" ", "-", "'", "."] or letter.is_valid_int():
			typing += letter

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
			get_tree().paused = not Net.has_company()
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
		var speed : float = charsPerSecond * float(Settings.get_value("textSpeed"))
		typed = minf(typed + speed * delta, line_length())
		queue_redraw()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font : Font = ui.font
	if cardAge >= 0.0:
		var fade : float = clampf(minf(cardAge / 0.5, (cardTime - cardAge) / 0.5), 0.0, 1.0)
		draw_rect(Rect2(-position, size + Vector2(20.0, 20.0)), Color(0.01, 0.02, 0.05, fade))
		draw_string(font, Vector2(0.0, size.y * 0.42), cardSub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 4, Color(ui.dimColor, fade))
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
		Mode.NAME:
			draw_name_field(font)

func draw_box(font : Font) -> void:
	var who : String = speaker()
	var face : Texture2D = portrait_of(who)
	# The player talks from the right, everyone else from the left.
	var right : bool = who == "player"
	draw_rect(Rect2(box.position + Vector2(1.0, 2.0), box.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, box)
	var text : Rect2 = box.grow_individual(-5.0, -4.0, -5.0, -3.0)
	if face:
		var frame : Rect2 = Rect2(Vector2(box.end.x - PORTRAIT - 3.0 if right else box.position.x + 3.0, box.position.y + 3.0), Vector2(PORTRAIT, PORTRAIT))
		UiKit.box(self, skin.card, frame)
		var talking : bool = typed < line_length() and fmod(time, 0.24) < 0.12
		var zoom : float = maxf(floorf((PORTRAIT - 2.0) / maxf(face.get_width(), face.get_height()) * 2.0) * 0.5, 0.5)
		var drawn : Vector2 = face.get_size() * zoom
		var at : Vector2 = (frame.get_center() - drawn * 0.5 + Vector2(0.0, -1.0 if talking else 0.0)).round()
		if right:
			draw_set_transform(Vector2(at.x + drawn.x, at.y), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(face, Rect2(Vector2.ZERO, drawn), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(face, Rect2(at, drawn), false)
		if right:
			text.size.x -= PORTRAIT + 4.0
		else:
			text.position.x += PORTRAIT + 4.0
			text.size.x -= PORTRAIT + 4.0
	if who != "narrator" and not who.is_empty():
		draw_name_tag(font, who, right)
	var left : int = int(typed)
	var y : float = text.position.y
	var color : Color = skin.text if who != "narrator" else skin.dim
	for line in wrapped:
		if left <= 0:
			break
		var part : String = line.substr(0, left)
		left -= line.length() + 1
		draw_string(font, Vector2(text.position.x, y + font.get_ascent(textSize)), part, HORIZONTAL_ALIGNMENT_LEFT, -1, textSize, color)
		y += textSize + 2.0
	if typed >= line_length() and (mode == Mode.LINES and (index < queue.size() - 1 or options.is_empty())) and fmod(time, 0.8) < 0.5:
		var tip : Vector2 = Vector2(box.end.x - (PORTRAIT + 9.0 if right and face else 6.0), box.end.y - 5.0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-1.5, -1.0), tip + Vector2(1.5, -1.0), tip + Vector2(0.0, 0.8)]), skin.title)

# The speaker's name on a tab over the box, on their side, with the
# friendship hearts beside a villager's.
func draw_name_tag(font : Font, who : String, right : bool) -> void:
	var label : String = player_name() if who == "player" else Cast.name_of(who)
	var width : float = UiKit.text_width(font, label, 3) + 8.0
	var tag : Rect2 = Rect2(box.end.x - width - 2.0 if right else box.position.x + 2.0, box.position.y - 6.0, width, 7.0)
	var tint : Color = Cast.color_of(who)
	draw_rect(tag, Color(0.12, 0.08, 0.05))
	draw_rect(tag.grow(-1.0), tint.darkened(0.55))
	draw_rect(Rect2(tag.position.x + 1.0, tag.position.y + 1.0, tag.size.x - 2.0, 1.0), tint.darkened(0.3))
	UiKit.label(self, font, Vector2(tag.position.x + 4.0, tag.position.y + 1.5 + font.get_ascent(3)), label, 3, tint.lightened(0.35))
	if Friendship.TASTES.has(who) and player and not right:
		draw_hearts(Vector2(tag.end.x + 3.0, tag.position.y + 1.5), who)

# The friendship hearts beside the name tag, the one being filled partly.
func draw_hearts(at : Vector2, who : String) -> void:
	var hearts : int = Friendship.hearts(player.progress, who)
	var part : float = Friendship.heart_progress(player.progress, who)
	var backing : Rect2 = Rect2(at + Vector2(-2.0, -1.5), Vector2(Friendship.MAX_HEARTS * 6.0 + 3.0, 7.0))
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
		UiKit.label(self, ui.font, Vector2(backing.end.x + 2.0, at.y + 3.0 - rise + ui.font.get_ascent(3) * 0.5), text, 3, Color(Friendship.HEART_COLOR if heartGain > 0 else Color(0.95, 0.5, 0.4), fade))

# A row of buttons on the box's top edge, right aligned.
func row_button(font : Font, area : Rect2, text : String, active : bool, icon : Texture2D = null, badge : String = "") -> void:
	UiKit.button(self, font, skin, area, "", 3, true, active)
	var x : float = area.position.x + 4.0
	if icon:
		draw_texture(icon, Vector2(area.position.x + 2.0, area.position.y + floorf((area.size.y - icon.get_height()) * 0.5)), Color.WHITE)
		x = area.position.x + 11.0
	UiKit.label(self, font, Vector2(x, UiKit.baseline(font, area, 3)), text, 3, skin.buttonText)
	if not badge.is_empty():
		var color : Color = Friendship.HEART_COLOR if badge == "+" else (Color(0.4, 0.85, 0.4) if badge == "?" else Color(1.0, 0.75, 0.2))
		draw_circle(area.position + Vector2(area.size.x - 1.5, 1.5), 2.0, Color(0.1, 0.06, 0.04))
		draw_circle(area.position + Vector2(area.size.x - 1.5, 1.5), 1.5, color)
	if active:
		UiKit.brackets(self, area, skin.title, time)

func draw_options(font : Font) -> void:
	optionRects.clear()
	if not at_end() or options.is_empty():
		return
	# On the other side from the speaker's name tag.
	var onLeft : bool = speaker() == "player"
	var x : float = box.position.x if onLeft else box.end.x
	for i in options.size():
		var width : float = UiKit.text_width(font, options[i], 3) + 10.0
		optionRects.append(Rect2(0.0, box.position.y - BUTTON_HEIGHT - 1.0, width, BUTTON_HEIGHT))
	var total : float = 0.0
	for area in optionRects:
		total += area.size.x + 1.0
	x = box.position.x if onLeft else box.end.x - total + 1.0
	for i in optionRects.size():
		optionRects[i].position.x = x
		x += optionRects[i].size.x + 1.0
	for i in options.size():
		row_button(font, optionRects[i], options[i], i == picked)

func draw_menu(font : Font) -> void:
	for i in menuItems.size():
		row_button(font, menuRects[i], menuItems[i][1], i == menuPick, ICONS.get(menuItems[i][0]), menuItems[i][2])

func draw_name_field(font : Font) -> void:
	if typed < line_length():
		return
	var field : Rect2 = Rect2(box.position.x + PORTRAIT + 9.0, box.end.y - 13.0, 70.0, 9.0)
	UiKit.box(self, skin.well, field)
	var shown_text : String = typing + ("_" if fmod(time, 1.0) < 0.6 else "")
	UiKit.label(self, font, Vector2(field.position.x + 3.0, UiKit.baseline(font, field, 4)), shown_text, 4, skin.text)
	UiKit.label(self, font, Vector2(field.end.x + 4.0, UiKit.baseline(font, field, 3)), "Type a name, Enter", 3, skin.dim)

func draw_board(font : Font, title : String, extra : String = "") -> void:
	draw_rect(Rect2(boardRect.position + Vector2(1.0, 2.0), boardRect.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, boardRect)
	UiKit.label(self, font, Vector2(boardRect.position.x + 4.0, boardRect.position.y + 3.0 + font.get_ascent(4)), title, 4, skin.title)
	if not extra.is_empty():
		UiKit.label(self, font, Vector2(boardRect.position.x, boardRect.position.y + 3.0 + font.get_ascent(3)), extra, 3, skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, boardRect.size.x - 4.0)

func draw_jobs(font : Font) -> void:
	draw_board(font, "%s's jobs" % Friendship.short_name(npc.id))
	for i in jobs.size():
		var quest : Quest = jobs[i]
		var area : Rect2 = jobRects[i]
		if i == jobPick:
			draw_rect(area, Color(skin.accent, 0.25))
			draw_rect(Rect2(area.position, Vector2(1.0, area.size.y)), skin.accent)
		elif zone == Zone.JOB and hoverIndex == i:
			draw_rect(area, skin.hover)
		var status : Color = Color(0.3, 0.7, 0.3) if quest.ready(player) else (Color(0.5, 0.55, 0.6) if player.progress.quest_active(quest) else Color(0.85, 0.6, 0.1))
		draw_rect(Rect2(area.position.x + 2.0, area.position.y + 3.0, 2.0, 2.0), status)
		UiKit.label(self, font, Vector2(area.position.x + 6.0, UiKit.baseline(font, area, 3)), quest.title, 3, skin.text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 7.0)
	# The picked job's card.
	var quest_now : Quest = jobs[jobPick]
	var cardRect : Rect2 = Rect2(jobRects[0].end.x + 4.0 if not jobRects.is_empty() else boardRect.position.x + 4.0, boardRect.position.y + 11.0, 0.0, boardRect.size.y - 25.0)
	cardRect.size.x = boardRect.end.x - cardRect.position.x - 4.0
	UiKit.box(self, skin.well, cardRect)
	var inner : Rect2 = cardRect.grow(-3.0)
	var y : float = inner.position.y
	UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), quest_now.title, 3, Color(0.7, 0.45, 0.1) if quest_now.story else skin.title, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	y += 5.0
	for line in ui.wrap_lines(quest_now.description, inner.size.x, 3).slice(0, 3):
		UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), line, 3, skin.dim)
		y += 4.0
	y += 2.0
	var started : bool = player.progress.quest_started(quest_now)
	for i in quest_now.goals.size():
		if y + 3.0 > inner.end.y:
			break
		var goal : QuestGoal = quest_now.goals[i]
		var have : int = quest_now.goal_progress(player, i) if started else 0
		var finished : bool = have >= goal.needed()
		draw_rect(Rect2(inner.position.x, y + 1.0, 2.0, 2.0), Color(0.3, 0.7, 0.3) if finished else skin.dim)
		UiKit.label(self, font, Vector2(inner.position.x + 4.0, y + font.get_ascent(3)), goal.describe(), 3, skin.text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 26.0)
		if started:
			UiKit.label(self, font, Vector2(inner.position.x, y + font.get_ascent(3)), "%d/%d" % [mini(have, goal.needed()), goal.needed()], 3, Color(0.3, 0.6, 0.3) if finished else skin.dim, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x)
		y += 4.0
	var rewards : PackedStringArray = QuestBoard.reward_names(quest_now)
	if not rewards.is_empty() and y + 3.0 <= inner.end.y:
		UiKit.label(self, font, Vector2(inner.position.x, y + 2.0 + font.get_ascent(3)), "Reward: " + ", ".join(rewards), 3, Color(0.7, 0.5, 0.1), HORIZONTAL_ALIGNMENT_LEFT, inner.size.x)
	var action : String = job_action_text(quest_now)
	UiKit.button(self, font, skin, buttonRects[0], action, 3, action != "Not yet", zone == Zone.BUTTON and hoverIndex == 0)
	UiKit.button(self, font, skin, buttonRects[1], "Back", 3, true, zone == Zone.BUTTON and hoverIndex == 1)

func draw_gifts(font : Font) -> void:
	var left : int = Friendship.GIFTS_PER_WEEK - Friendship.gifts_this_week(player.progress, npc.id, today())
	draw_board(font, "Give a gift", "Birthday! x8" if Friendship.is_birthday(npc.id, today()) else "%d left this week" % maxi(left, 0))
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
	draw_tastes(font, Rect2(boardRect.position.x + 3.0 + GIFT_COLUMNS * 12.0 + 3.0, boardRect.position.y + 10.0, 66.0, boardRect.size.y - 13.0))
	if giftPick >= 0 and giftPick < slotItems.size():
		var item : Item = player.inventory.get_item(slotItems[giftPick])
		if item:
			var taste : String = known_taste(item)
			var lines : PackedStringArray = PackedStringArray(["They %s it" % taste if not taste.is_empty() else "Not given before", ""])
			var anchor : Vector2 = slotRects[giftPick].end + Vector2(2.0, -4.0)
			ui.paint_tip(self, anchor if zone != Zone.SLOT else mouse, item.displayName, item.title_color(), lines, ui.tip_size(item.displayName, lines))

# What the villager is known to think of things: found out by giving them,
# plus hints they drop as friendship grows (likes at 3 hearts, loves at 6).
func draw_tastes(font : Font, area : Rect2) -> void:
	UiKit.box(self, skin.well, area)
	var y : float = area.position.y + 2.0
	var any : bool = false
	for kind in ["loved", "liked", "disliked", "hated"]:
		var things : PackedStringArray = Friendship.taste_names(player.progress, npc.id, kind)
		if things.is_empty():
			continue
		any = true
		UiKit.label(self, font, Vector2(area.position.x + 2.0, y + font.get_ascent(3)), kind.capitalize(), 3, skin.readable(REACTION_COLORS[kind]))
		y += 4.0
		for line in ui.wrap_lines(", ".join(things), area.size.x - 4.0, 3):
			if y + 3.0 > area.end.y:
				return
			UiKit.label(self, font, Vector2(area.position.x + 2.0, y + font.get_ascent(3)), line, 3, skin.dim)
			y += 4.0
		y += 1.0
	if not any:
		for line in ui.wrap_lines("Give gifts to learn what they like. Friends drop hints.", area.size.x - 4.0, 3):
			UiKit.label(self, font, Vector2(area.position.x + 2.0, y + font.get_ascent(3)), line, 3, skin.dim)
			y += 4.0
