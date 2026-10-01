extends MenuPanel
class_name ArcadeUI

# The little games around Bramblewick (see ArcadeStand):
# - Darts in the tavern: three darts at a board while the aim drifts. Play
#   Wren for a small stake (three paid games a day), or for nothing.
# - The harbor regatta: steer around rocks and through buoy gates; the first
#   finish each day pays by medal.
# - The lantern toss at festivals: darts with lanterns, paid in Contest
#   Ribbons once a festival day.
# With a friend in the world, darts and the regatta can be a challenge: both
# play the same board or course (one seed) whenever they like, and the scores
# are compared when both are in (see NetSession.on_arcade).

enum Stage { MENU, PLAY, RESULT }
const DARTS : int = 0
const RACE : int = 1
const TOSS : int = 2
const GROUP : StringName = &"arcade_ui"
const TITLES : PackedStringArray = ["Darts", "Harbor Regatta", "Lantern Toss"]
const BOARD : float = 24.0
const RINGS : Array = [[3.0, 50], [8.0, 25], [15.0, 10], [BOARD, 5]]
const STAKE : int = 10
const WIN : int = 25
const WREN_GAMES : int = 3
const COURSE : float = 1600.0
const BASE_SPEED : float = 70.0
const RACE_PAY : Array = [30, 18, 8]
const MEDALS : PackedStringArray = ["Gold", "Silver", "Bronze"]
const MEDAL_COLORS : Array = [Color(1.0, 0.84, 0.3), Color(0.82, 0.86, 0.92), Color(0.8, 0.55, 0.32)]
const RIBBON : String = "res://items/events/contest_ribbon.tres"

# Challenges by game: the seed, the friend's score (-1 until it comes in) and
# this player's (-1 until played), and who.
static var challenges : Dictionary = {}

#------------------------#
var player : Player
var ui : InventoryUI
var skin : MenuSkin
var game : int = DARTS
var stage : int = Stage.MENU
var mode : StringName = &""
var options : Array = []
var hovered : int = -1
var mouse : Vector2 = Vector2.ZERO
var panel : Rect2
var field : Rect2
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var seed_used : int = 0
var time : float = 0.0
var wait : float = 0.0
var resultLines : PackedStringArray = PackedStringArray()
var resultColor : Color = Color.WHITE
# Darts
var aimSpeed : Vector2 = Vector2.ONE
var aimPhase : Vector2 = Vector2.ZERO
var darts : Array[Vector2] = []
var wrenDarts : Array[Vector2] = []
# Race
var course : Array = []
var distance : float = 0.0
var boatY : float = 0.0
var boost : float = 0.0
var stun : float = 0.0
var raceTime : float = 0.0
var flash : String = ""
var flashTime : float = 0.0
#------------------------#


static func open(tree : SceneTree, who : Player, which : int) -> void:
	var arcade : ArcadeUI = tree.get_first_node_in_group(GROUP) as ArcadeUI
	if not arcade:
		var counter : CounterUI = CounterUI.find(tree)
		if not counter:
			return
		arcade = ArcadeUI.new()
		arcade.ui = counter.ui
		counter.get_parent().add_child(arcade)
	arcade.start(who, which)

# The festival running now, if any (festivals have set days, happenings repeat).
static func festival(tree : SceneTree) -> GameEvent:
	for event in EventDirector.active(tree):
		if event.every == 0 and event.weekday < 0:
			return event
	return null

static func friend_name() -> String:
	for id in Net.names:
		if id != Net.my_id():
			return Net.names[id]
	return "your friend"

func _ready() -> void:
	super()
	add_to_group(GROUP)
	set_anchors_preset(PRESET_TOP_LEFT)
	skin = load("res://ui/skins/themes/leather_blue.tres") as MenuSkin
	set_process(false)

func start(who : Player, which : int) -> void:
	player = who
	game = which
	scale = ui.scale
	place(Rect2(Vector2.ZERO, ui.size))
	panel = Rect2(floorf((ui.size.x - 150.0) * 0.5), floorf((ui.size.y - 86.0) * 0.5), 150.0, 86.0)
	field = Rect2(panel.position + Vector2(5.0, 12.0), Vector2(panel.size.x - 10.0, panel.size.y - 17.0))
	player.frozen = true
	show_menu()
	open_menu()
	set_process(true)

func close() -> void:
	if not shown:
		return
	close_menu()
	set_process(false)
	if player:
		player.frozen = false

#------------------------# Menu

func show_menu() -> void:
	stage = Stage.MENU
	options.clear()
	var challenge : Dictionary = challenges.get(game, {})
	match game:
		DARTS:
			var left : int = WREN_GAMES - wren_games()
			options.append(["Play Wren ($%d, win $%d)" % [STAKE, WIN], &"wren", left > 0 and player.wallet.coins >= STAKE])
			options.append(["Practice", &"practice", true])
		RACE:
			options.append(["Race" + ("" if raced_today() else " (pays today)"), &"race", true])
		TOSS:
			options.append(["Toss three lanterns" + ("" if tossed_today() else " (ribbons today)"), &"toss", true])
	if game != TOSS and Net.has_company():
		if not challenge.is_empty() and challenge.mine < 0:
			options.append(["Answer %s's challenge" % challenge.name, &"answer", true])
		else:
			options.append(["Challenge %s" % friend_name(), &"challenge", challenge.is_empty() or challenge.theirs >= 0])
	options.append(["Leave", &"leave", true])
	hovered = -1
	queue_redraw()

func option_rect(index : int) -> Rect2:
	return Rect2(panel.position.x + 20.0, panel.position.y + 22.0 + index * 11.0, panel.size.x - 40.0, 9.0)

func choose(action : StringName) -> void:
	mode = action
	match action:
		&"leave":
			close()
			return
		&"wren":
			player.wallet.spend(STAKE)
			var count : Array = player.progress.get_flag("arcade/wren", [day(), 0])
			player.progress.set_flag("arcade/wren", [day(), (count[1] if count[0] == day() else 0) + 1])
			begin(randi())
		&"challenge":
			var picked : int = randi()
			challenges[game] = {"seed": picked, "theirs": -1, "mine": -1, "name": friend_name()}
			Net.send(&"arcade", {"game": game, "seed": picked, "score": -1, "name": Net.myName})
			begin(picked)
		&"answer":
			begin(int(challenges[game].seed))
		_:
			begin(randi())

func begin(picked : int) -> void:
	seed_used = picked
	rng.seed = picked
	stage = Stage.PLAY
	time = 0.0
	wait = 0.0
	darts.clear()
	wrenDarts.clear()
	if game == RACE:
		make_course()
	else:
		aimSpeed = Vector2(rng.randf_range(2.0, 2.6), rng.randf_range(2.9, 3.5)) * (1.25 if game == TOSS else 1.0)
		aimPhase = Vector2(rng.randf() * TAU, rng.randf() * TAU)

#------------------------# Darts and toss

func board_center() -> Vector2:
	return (field.get_center() + Vector2(0.0, 2.0)).floor()

func aim() -> Vector2:
	return Vector2(sin(time * aimSpeed.x + aimPhase.x), sin(time * aimSpeed.y + aimPhase.y)) * BOARD * 0.9

static func ring_score(offset : Vector2) -> int:
	for ring in RINGS:
		if offset.length() <= ring[0]:
			return ring[1]
	return 0

func total(list : Array[Vector2]) -> int:
	var sum : int = 0
	for dart in list:
		sum += ring_score(dart)
	return sum

func throw() -> void:
	if darts.size() >= 3 or wait > 0.0:
		return
	darts.append(aim() + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
	if darts.size() == 3:
		wait = 0.9

func finish_darts() -> void:
	var score : int = total(darts)
	match mode:
		&"wren":
			var wren : RandomNumberGenerator = RandomNumberGenerator.new()
			for i in 3:
				wrenDarts.append(Vector2(wren.randfn(0.0, 7.5), wren.randfn(0.0, 7.5)))
			var theirs : int = total(wrenDarts)
			if score > theirs:
				player.wallet.add(WIN)
				show_result(["You %d, Wren %d" % [score, theirs], "You win $%d." % WIN, "Wren: Again. Tomorrow. I'll be ready."], skin.good)
			elif score == theirs:
				player.wallet.add(STAKE)
				show_result(["You %d, Wren %d" % [score, theirs], "A tie. Stake back.", "Wren: Unsatisfying for everyone."], skin.text)
			else:
				show_result(["You %d, Wren %d" % [score, theirs], "Wren keeps the stake.", "Wren: It's my board. It likes me."], skin.bad)
		&"challenge", &"answer":
			played_challenge(score)
		_:
			if game == TOSS:
				pay_toss(score)
			else:
				show_result(["%d points." % score, "Best possible is 150."], skin.text)

func pay_toss(score : int) -> void:
	var ribbons : int = 3 if score >= 100 else 2 if score >= 60 else 1 if score >= 25 else 0
	if tossed_today() or ribbons == 0:
		show_result(["%d points." % score, "Ribbons come once a festival day." if tossed_today() else "No ribbon this time."], skin.text)
		return
	player.progress.set_flag("arcade/toss", day())
	var ribbon : Item = load(RIBBON) as Item
	if ribbon and player.inventory.give(ribbon, ribbons) == 0:
		show_result(["%d points." % score, "+%d Contest Ribbon%s" % [ribbons, "" if ribbons == 1 else "s"]], skin.good)
	else:
		show_result(["%d points." % score, "No room in the bag for ribbons."], skin.bad)

#------------------------# Race

func make_course() -> void:
	course.clear()
	var x : float = 120.0
	var count : int = 0
	while x < COURSE - 40.0:
		count += 1
		var gate : bool = count % 4 == 0
		course.append({"x": x, "y": rng.randf_range(8.0, field.size.y - 8.0), "gate": gate, "done": false})
		x += rng.randf_range(38.0, 64.0)
	distance = 0.0
	boatY = field.size.y * 0.5
	boost = 0.0
	stun = 0.0
	raceTime = 0.0
	flash = ""

func boat_x() -> float:
	return field.position.x + 20.0

func race_step(delta : float) -> void:
	raceTime += delta
	stun = maxf(stun - delta, 0.0)
	boost = maxf(boost - 30.0 * delta, 0.0)
	flashTime = maxf(flashTime - delta, 0.0)
	var steer : float = Input.get_axis("up", "down")
	if steer == 0.0 and field.has_point(mouse):
		steer = clampf((mouse.y - field.position.y - boatY) / 6.0, -1.0, 1.0)
	boatY = clampf(boatY + steer * 65.0 * delta, 4.0, field.size.y - 4.0)
	var speed : float = 25.0 if stun > 0.0 else BASE_SPEED + boost
	var before : float = distance
	distance += speed * delta
	for item in course:
		if item.done or item.x > distance + 3.0:
			continue
		if item.gate:
			if item.x <= distance and item.x > before:
				item.done = true
				if absf(boatY - item.y) <= 8.0:
					boost += 40.0
					flash = "Through the gate!"
					flashTime = 0.8
		elif item.x > distance - 3.0 and absf(boatY - item.y) < 5.0:
			item.done = true
			stun = 0.7
			flash = "Rocks!"
			flashTime = 0.8
	if distance >= COURSE:
		finish_race()

func par() -> float:
	return COURSE / 85.0

func medal(seconds : float) -> int:
	for i in 3:
		if seconds <= par() * [1.0, 1.08, 1.18][i]:
			return i
	return -1

func finish_race() -> void:
	var seconds : float = raceTime
	var won : int = medal(seconds)
	if mode == &"challenge" or mode == &"answer":
		played_challenge(roundi(seconds * 100.0))
		return
	var lines : PackedStringArray = ["%.2f seconds." % seconds, (MEDALS[won] + " time!") if won >= 0 else "No medal. The harbor wins this one."]
	if won >= 0 and not raced_today():
		player.progress.set_flag("arcade/race", day())
		player.wallet.add(RACE_PAY[won])
		Skills.add(player, Skills.SAILING, 15.0)
		lines.append("+$%d, +15 Sailing XP" % RACE_PAY[won])
	show_result(lines, MEDAL_COLORS[won] if won >= 0 else skin.text)

#------------------------# Challenges

func played_challenge(score : int) -> void:
	var challenge : Dictionary = challenges.get(game, {})
	if challenge.is_empty():
		show_result([score_text(score)], skin.text)
		return
	challenge.mine = score
	Net.send(&"arcade", {"game": game, "seed": challenge.seed, "score": score, "name": Net.myName})
	if challenge.theirs >= 0:
		show_result(ArcadeUI.verdict(game, score, challenge.theirs, challenge.name), skin.accent)
		challenges.erase(game)
	else:
		show_result([score_text(score), "Waiting on %s's go." % challenge.name], skin.text)

static func score_text(score : int, game_kind : int = DARTS) -> String:
	return "%.2f seconds" % (score / 100.0) if game_kind == RACE else "%d points" % score

static func verdict(game_kind : int, mine : int, theirs : int, who : String) -> PackedStringArray:
	var better : bool = mine < theirs if game_kind == RACE else mine > theirs
	var lines : PackedStringArray = ["You: %s" % score_text(mine, game_kind), "%s: %s" % [who, score_text(theirs, game_kind)]]
	lines.append("A tie!" if mine == theirs else ("You win!" if better else "%s wins." % who))
	return lines

# A challenge message from the friend: a new challenge, or their score.
static func received(tree : SceneTree, data : Dictionary) -> void:
	var kind : int = int(data.get("game", DARTS))
	var score : int = int(data.get("score", -1))
	var who : String = str(data.get("name", "Your friend"))
	var challenge : Dictionary = challenges.get(kind, {})
	var board : NoticeBoard = NoticeBoard.find(tree)
	if challenge.is_empty() or int(challenge.seed) != int(data.get("seed", 0)):
		challenges[kind] = {"seed": int(data.get("seed", 0)), "theirs": score, "mine": -1, "name": who}
		if board:
			board.post("%s challenges you!" % who, "%s at the %s." % [TITLES[kind], "tavern" if kind == DARTS else "east pier"], Color(1.0, 0.84, 0.3))
		return
	challenge.theirs = score
	if score >= 0 and challenge.mine >= 0:
		var lines : PackedStringArray = verdict(kind, challenge.mine, score, who)
		challenges.erase(kind)
		if board:
			board.post(TITLES[kind] + " challenge", lines[2], Color(1.0, 0.84, 0.3))

#------------------------# Shared

func day() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 0

func wren_games() -> int:
	var count : Array = player.progress.get_flag("arcade/wren", [-1, 0])
	return count[1] if count[0] == day() else 0

func raced_today() -> bool:
	return player.progress.get_flag("arcade/race", -1) == day()

func tossed_today() -> bool:
	return player.progress.get_flag("arcade/toss", -1) == day()

func show_result(lines : PackedStringArray, color : Color) -> void:
	stage = Stage.RESULT
	resultLines = lines
	resultColor = color

func _process(delta : float) -> void:
	time += delta
	if stage == Stage.PLAY:
		if game == RACE:
			race_step(delta)
		elif wait > 0.0:
			wait -= delta
			if wait <= 0.0:
				finish_darts()
	queue_redraw()

func _unhandled_input(event : InputEvent) -> void:
	if not shown:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if stage == Stage.PLAY:
			return
		close()
	elif event.is_action_pressed("use") and stage == Stage.PLAY and game != RACE:
		get_viewport().set_input_as_handled()
		throw()

func _has_point(point : Vector2) -> bool:
	return shown and panel.grow(1.0).has_point(point)

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.position
		hovered = -1
		if stage == Stage.MENU:
			for i in options.size():
				if option_rect(i).has_point(mouse):
					hovered = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match stage:
			Stage.MENU:
				if hovered >= 0 and options[hovered][2]:
					choose(options[hovered][1])
			Stage.PLAY:
				if game != RACE:
					throw()
			Stage.RESULT:
				show_menu()
	accept_event()

func _draw() -> void:
	var font : Font = ui.font
	draw_rect(Rect2(panel.position + Vector2(2.0, 2.0), panel.size), Color(0.0, 0.0, 0.0, 0.3))
	UiKit.box(self, skin.frame, panel)
	UiKit.label(self, font, Vector2(panel.position.x, panel.position.y + 2.0 + font.get_ascent(ui.titleSize)), TITLES[game], ui.titleSize, skin.title, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	match stage:
		Stage.MENU:
			for i in options.size():
				UiKit.button(self, font, skin, option_rect(i), options[i][0], 3, options[i][2], i == hovered)
		Stage.PLAY:
			if game == RACE:
				draw_race(font)
			else:
				draw_board(font)
		Stage.RESULT:
			var y : float = panel.position.y + 30.0
			for i in resultLines.size():
				UiKit.label(self, font, Vector2(panel.position.x, y + font.get_ascent(4)), resultLines[i], 4, resultColor if i == 0 else skin.text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
				y += 7.0
			UiKit.label(self, font, Vector2(panel.position.x, panel.end.y - 4.0), "Click to go on", 3, skin.dim, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)

func draw_board(font : Font) -> void:
	var c : Vector2 = board_center()
	var toss : bool = game == TOSS
	draw_rect(field, Color(0.1, 0.09, 0.18) if toss else Color(0.36, 0.25, 0.16))
	var colors : Array = [Color(0.85, 0.2, 0.2), Color(0.2, 0.55, 0.3), Color(0.92, 0.88, 0.76), Color(0.08, 0.08, 0.1)]
	if toss:
		colors = [Color(1.0, 0.85, 0.4), Color(0.95, 0.55, 0.3), Color(0.6, 0.3, 0.5), Color(0.2, 0.15, 0.3)]
	for i in range(RINGS.size() - 1, -1, -1):
		draw_circle(c, RINGS[i][0], colors[i])
	for dart in wrenDarts:
		draw_rect(Rect2((c + dart).floor() - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(0.5, 0.9, 0.8))
	for dart in darts:
		draw_rect(Rect2((c + dart).floor() - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color.WHITE)
		draw_rect(Rect2((c + dart).floor(), Vector2(1.0, 1.0)), Color.BLACK)
	if darts.size() < 3:
		var at : Vector2 = (c + aim()).floor()
		for d in [Vector2(-3, 0), Vector2(2, 0), Vector2(0, -3), Vector2(0, 2)]:
			draw_rect(Rect2(at + d, Vector2(1.0, 1.0)), skin.accent)
	UiKit.label(self, font, Vector2(field.position.x + 2.0, field.position.y + 2.0 + font.get_ascent(3)), "%s %d/3" % ["Lantern" if toss else "Dart", mini(darts.size() + 1, 3)], 3, skin.text)
	UiKit.label(self, font, Vector2(field.position.x, field.end.y - 2.0), "%d pts" % total(darts), 3, skin.accent, HORIZONTAL_ALIGNMENT_RIGHT, field.size.x - 2.0)

func draw_race(font : Font) -> void:
	draw_rect(field, Color(0.12, 0.35, 0.55))
	var shift : float = fmod(distance * 0.5, 12.0)
	for row in 5:
		for col in 14:
			var dash : Vector2 = Vector2(field.position.x + col * 12.0 - shift, field.position.y + 4.0 + row * 12.0 + (col % 2) * 3.0)
			if dash.x >= field.position.x and dash.x + 3.0 <= field.end.x:
				draw_rect(Rect2(dash, Vector2(3.0, 1.0)), Color(0.3, 0.55, 0.75))
	for item in course:
		var x : float = boat_x() + item.x - distance
		if x < field.position.x + 3.0 or x > field.end.x - 3.0:
			continue
		var y : float = field.position.y + item.y
		if item.gate:
			for side in [-9.0, 9.0]:
				draw_rect(Rect2(Vector2(x - 1.0, y + side - 1.0), Vector2(2.0, 2.0)), Color(1.0, 0.4, 0.3) if not item.done else Color(0.6, 0.6, 0.6))
		else:
			draw_circle(Vector2(x, y), 3.0, Color(0.35, 0.33, 0.32))
			draw_rect(Rect2(x - 1.0, y - 2.0, 2.0, 1.0), Color(0.55, 0.53, 0.5))
	var finish_x : float = boat_x() + COURSE - distance
	if finish_x < field.end.x:
		for i in int(field.size.y / 3.0):
			draw_rect(Rect2(finish_x, field.position.y + i * 3.0, 2.0, 3.0), Color.WHITE if i % 2 == 0 else Color.BLACK)
	var boat : Vector2 = Vector2(boat_x(), field.position.y + boatY).floor()
	draw_rect(Rect2(boat + Vector2(-4.0, 0.0), Vector2(8.0, 2.0)), Color(0.55, 0.35, 0.2) if stun <= 0.0 or fmod(time, 0.2) < 0.1 else Color(1.0, 1.0, 1.0, 0.5))
	draw_rect(Rect2(boat + Vector2(-1.0, -5.0), Vector2(1.0, 5.0)), Color(0.4, 0.3, 0.2))
	draw_rect(Rect2(boat + Vector2(0.0, -5.0), Vector2(3.0, 3.0)), Color(0.95, 0.95, 0.9))
	UiKit.label(self, font, Vector2(field.position.x + 2.0, field.position.y + 2.0 + font.get_ascent(3)), "%.1f s" % raceTime, 3, skin.text)
	UiKit.label(self, font, Vector2(field.position.x, field.position.y + 2.0 + font.get_ascent(3)), "%d%%" % roundi(minf(distance / COURSE, 1.0) * 100.0), 3, skin.text, HORIZONTAL_ALIGNMENT_RIGHT, field.size.x - 2.0)
	if flashTime > 0.0:
		UiKit.label(self, font, Vector2(field.position.x, field.end.y - 3.0), flash, 3, skin.accent, HORIZONTAL_ALIGNMENT_CENTER, field.size.x)
