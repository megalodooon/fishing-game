extends Node

# A test runner for development, started from the command line:
#   godot --path . res://dev/harness.tscn -- <out_dir> <step> [step...]
# It loads the game the way the loading screen does, skips the intro, runs
# each step (a method below) and saves a screenshot after it to out_dir.
# Steps starting with "host"/"join" run a two-player session instead (see
# tools/net_test). Prints "HARNESS: done" at the end and quits.

var out : String = ""
var game : Node
var player : Player
var failures : int = 0


func _ready() -> void:
	var args : PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("HARNESS: give an output folder and steps")
		get_tree().quit(1)
		return
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred(Array(args.slice(1)))

func wait(frames : int) -> void:
	for i in frames:
		await get_tree().process_frame

func seconds(time : float) -> void:
	await get_tree().create_timer(time).timeout

func shot(label : String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))

func check(ok : bool, what : String) -> void:
	print("HARNESS: %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1

func load_game() -> void:
	Preloader.start()
	while not Preloader.done():
		Preloader.poll()
		await get_tree().process_frame
	game = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	player = game.get_node("Player")
	player.progress.set_flag("story/intro")
	player.progress.playerName = "Tester"
	await wait(30)
	var dialogue : DialogueUI = find(DialogueUI)
	if dialogue and dialogue.shown:
		dialogue.finish(-1)
	await wait(10)

func run(steps : Array) -> void:
	SaveGame.folder = "user://harness/"
	DirAccess.make_dir_recursive_absolute(SaveGame.folder)
	if steps.is_empty() or not (String(steps[0]).begins_with("title") or String(steps[0]).begins_with("join")):
		await load_game()
	for step in steps:
		print("HARNESS: step ", step)
		await call(StringName(step))
		await wait(20)
		await shot(step)
		close_all()
		await wait(10)
	print("HARNESS: done, %d failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func find(type : Variant) -> Node:
	var root : Node = game if game else get_tree().root
	for node in root.find_children("*", "", true, false):
		if is_instance_of(node, type):
			return node
	return null

func close_all() -> void:
	var press : InputEventAction = InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	var release : InputEventAction = InputEventAction.new()
	release.action = "ui_cancel"
	Input.parse_input_event(release)

#------------------------# Steps

func title() -> void:
	get_tree().change_scene_to_file("res://ui/title/title_screen.tscn")
	await wait(10)

func plain() -> void:
	pass

func pause() -> void:
	(find(PauseMenu) as PauseMenu).open_pause()

func village() -> void:
	(game.get_node("World") as World).arrive(load("res://world/locations/village.tres"))
	await wait(30)

func hub() -> void:
	var menu : MenuHub = MenuHub.find(get_tree())
	menu.switch_to(menu.firstTab)

func bag() -> void:
	(find(InventoryUI) as InventoryUI).show_backpack()

func journal() -> void:
	(find(JournalUI) as JournalUI).toggle()

func quests() -> void:
	# Quests set straight into the progress, so their scenes don't play.
	for path in ["res://world/quests/story/q_market.tres", "res://world/quests/story/q_rod.tres", "res://world/quests/side/" + DirAccess.get_files_at("res://world/quests/side")[0].trim_suffix(".remap")]:
		var quest : Quest = load(path)
		var counts : Array = []
		counts.resize(quest.goals.size())
		counts.fill(1)
		player.progress.quests[quest] = {"counts": counts, "done": false}
	player.progress.tracked = load("res://world/quests/story/q_market.tres")
	(find(QuestLog) as QuestLog).open_log(player)

func chart() -> void:
	(find(WorldMapUI) as WorldMapUI).try_open()

func scene_player() -> void:
	(find(DialogueUI) as DialogueUI).start([["pip", "Well now, {name}! You came back."], ["player", "I got Grandpa's letter. Is it true about the harbor?"]], PackedStringArray(["Tell me", "Later"]), Callable())
	await seconds(0.3)
	(find(DialogueUI) as DialogueUI).index = 1
	(find(DialogueUI) as DialogueUI).rewrap()
	await seconds(1.5)

func talk_pip() -> void:
	await village()
	var pip : Npc = null
	for node in game.find_children("*", "Npc", true, false):
		if (node as Npc).id == "pip":
			pip = node
	(find(DialogueUI) as DialogueUI).converse(pip, player)
	await seconds(1.5)

func gift_pip() -> void:
	await talk_pip()
	(find(DialogueUI) as DialogueUI).open_gift()
	await seconds(1.0)

func toasts() -> void:
	var talk : DialogueUI = find(DialogueUI)
	if talk.shown:
		talk.finish(-1)
	var board : NoticeBoard = NoticeBoard.find(get_tree())
	board.post("Quest ready!", "Fresh Off the Boat: go back to Gus.", Color(0.56, 0.93, 0.44))
	board.post("Treasure!", "Wooden Chest", Color(1.0, 0.86, 0.36))
	board.post("Treasure!", "Wooden Chest", Color(1.0, 0.86, 0.36))
	board.banner("Fishing 5", "+2% rare fish luck", Color(0.4, 0.8, 1.0), TideTree.icon("crown"))
	board.post("Heart", "icon test", Color.WHITE, TideTree.icon("heart"))
	await seconds(0.6)

func profile() -> void:
	(find(ProfileUI) as ProfileUI).open_profile()

func tide_tree() -> void:
	var menu : ProfileUI = find(ProfileUI)
	menu.open_profile()
	menu.tab = ProfileUI.Tab.TREE
	player.progress.set_flag("tide/heart", 3)
	player.progress.set_flag("tide/forager", 2)
	menu.treeNode = 3
	var icon : Texture2D = TideTree.icon("heart")
	print("HARNESS: icon ", icon, " ", icon.get_class() if icon else "", " ", icon.get_image().get_pixel(0, 0) if icon else "")
	menu.queue_redraw()

#------------------------# Two players (run host_test in one game, join_test in another)

const TEST_PORT : int = 24681

# Waits until the test is true or the time runs out. Returns whether it came true.
func wait_for(test : Callable, timeout : float) -> bool:
	var left : float = timeout
	while left > 0.0:
		if test.call():
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return test.call()

func host_test() -> void:
	player.progress.playerName = "Alice"
	check(Net.host(TEST_PORT) == OK, "hosting started")
	check(await wait_for(func() -> bool: return Net.names.size() == 1, 30.0), "a guest joined")
	var session : NetSession = NetSession.find(get_tree())
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	check(await wait_for(func() -> bool: return session.states.size() == 1, 20.0), "the guest's pose arrives")
	player.progress.set_flag("project/harness_host")
	check(await wait_for(func() -> bool: return player.progress.has_flag("project/harness_guest"), 20.0), "the guest's world flag arrives")
	await seconds(1.0)
	check(not player.progress.has_flag("seen/harness_private"), "the guest's own flags stay theirs")
	var quest : Quest = load("res://world/quests/story/q_market.tres")
	check(await wait_for(func() -> bool: return player.progress.quest_started(quest), 10.0), "a quest the guest took is shared")
	check(session.remotes.size() == 1 and (session.remotes.values()[0] as RemotePlayer).visible, "the guest is drawn (same place)")
	check(await wait_for(func() -> bool: return session.boardRequest > 0, 20.0), "the guest asks to board")
	session.answer_board(true)
	check(await wait_for(func() -> bool: return session.riders().size() == 1, 15.0), "the guest is aboard")
	await wait(3)
	check(not (session.remotes.values()[0] as RemotePlayer).far, "a rider is drawn on the deck, not on the horizon")
	await shot("host_aboard")
	var screen : Rect2 = Rect2(Vector2.ZERO, Vector2(192.0, 108.0))
	for i in 3:
		(game.get_node("World") as World).spawner.spawn(screen)
	var crab : SeaCreature = load("res://fishing/creatures/giant_crab.tres")
	var fightGame : BossMinigame = (load("res://fishing/minigames/boss_duel/boss_duel.tscn") as PackedScene).instantiate()
	fightGame.hearts = 3
	player.minigameScreen.play(fightGame)
	fightGame.begin(0.2, 0.5, Color.WHITE, crab.icon)
	session.fight_started(crab, fightGame)
	check(await wait_for(func() -> bool: return not session.fight.is_empty() and session.fight.helpers.size() == 1, 15.0), "the guest jumps into the fight")
	var health : float = fightGame.health_left()
	check(await wait_for(func() -> bool: return fightGame.health_left() < health, 10.0), "the guest's hits wear the foe down")
	fightGame.finish(true)
	player.minigameScreen.close_menu()
	await seconds(3.0)
	(game.get_node("World") as World).arrive(load("res://world/locations/cold_ocean.tres"))
	check(await wait_for(func() -> bool: return session.riders().is_empty(), 25.0), "the guest steps off again")
	cycle.set_time(22.0)
	session.clockTimer = 0.0
	await seconds(1.5)
	var day : int = cycle.day
	SleepSchedule.find(get_tree()).go_to_sleep()
	await seconds(2.0)
	check(cycle.day == day, "the night waits for the guest")
	check(await wait_for(func() -> bool: return cycle.day == day + 1, 30.0), "the night comes once both are in bed")
	await seconds(4.0)
	SaveGame.slot = 0
	check(SaveGame.save_game(get_tree()), "the host saves")
	var saved : Dictionary = SaveGame.read(0)
	check((saved.get("players", {}) as Dictionary).has("Bob"), "the save keeps the guest's character")
	check((saved.get("players", {}) as Dictionary).has("Alice"), "the save keeps the host's character")
	await seconds(1.0)
	Net.leave()

func join_test() -> void:
	# The game scene replaces the current scene; this runner has to stay.
	get_tree().current_scene = null
	check(Net.join("127.0.0.1:%d" % TEST_PORT, "Bob") == OK, "joining started")
	check(await wait_for(func() -> bool: return NetSession.find(get_tree()) != null, 60.0), "the host's world loads")
	await seconds(1.0)
	player = Player.find(get_tree())
	game = get_tree().current_scene
	check(player.progress.playerName == "Bob", "the guest has their own name")
	check(await wait_for(func() -> bool: return player.progress.has_flag("project/harness_host"), 20.0), "the host's world flag arrives")
	player.progress.set_flag("project/harness_guest")
	player.progress.set_flag("seen/harness_private")
	player.progress.start_quest(load("res://world/quests/story/q_market.tres"))
	var session : NetSession = NetSession.find(get_tree())
	await seconds(2.0)
	session.ask_to_board(1)
	check(await wait_for(func() -> bool: return session.boardedOn == 1, 20.0), "the host lets the guest aboard")
	var spawner : FishingSpotSpawner = (get_tree().current_scene.get_node("World") as World).spawner
	check(await wait_for(func() -> bool: return spawner.get_child_count() > 0, 10.0), "the host's fishing spots show up for the rider")
	var map : WorldMapUI = WorldMapUI.find(get_tree())
	map.try_open()
	await seconds(0.6)
	await shot("guest_chart")
	map.close()
	check(await wait_for(func() -> bool: return not session.invite.is_empty(), 15.0), "the host's creature fight is offered")
	session.join_fight()
	check(not session.helping.is_empty(), "the guest joins the fight")
	await seconds(0.5)
	(session.helping.game as BossMinigame).dealt.emit(4.0)
	var crab : SeaCreature = load("res://fishing/creatures/giant_crab.tres")
	check(await wait_for(func() -> bool: return session.helping.is_empty(), 15.0), "the fight ends for the helper too")
	check(player.progress.bestiary.get(crab, 0) == 1, "the helper gets the creature's loot")
	var cold : Location = load("res://world/locations/cold_ocean.tres")
	check(await wait_for(func() -> bool: return player.atlas.current == cold, 40.0), "the rider is carried along when the host sails")
	check(session.boardedOn == 1, "and is still aboard")
	await seconds(1.0)
	session.unboard()
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	check(await wait_for(func() -> bool: return cycle.time >= 21.5, 40.0), "the host's clock comes over")
	var day : int = cycle.day
	await seconds(3.5)
	SleepSchedule.find(get_tree()).go_to_sleep()
	check(await wait_for(func() -> bool: return cycle.day == day + 1, 30.0), "the guest wakes on the next day too")
	await seconds(8.0)

func journal_fish() -> void:
	var book : JournalUI = find(JournalUI)
	if not book.shown:
		book.toggle()
	await wait(5)
	for i in book.journal.biomes.size():
		if not book.journal.biomes[i].creatures.is_empty():
			book.show_page(i + 1, 1)
			break
	book.journal.record(Fish.caught(book.list[0], 0.0), book.page_biome())
	book.select(book.list[0])
	await seconds(0.5)

func journal_creatures() -> void:
	await journal_fish()
	var book : JournalUI = find(JournalUI)
	book.show_tab(true)
	player.progress.bestiary[book.creatureList[0]] = 2
	book.pickedCreature = book.creatureList[0]
	book.refresh()
	await seconds(0.5)
