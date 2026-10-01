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
	(find(QuestLog) as QuestLog).open_log(player)

func chart() -> void:
	(find(WorldMapUI) as WorldMapUI).try_open()

func profile() -> void:
	(find(ProfileUI) as ProfileUI).open_profile()

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
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	check(await wait_for(func() -> bool: return cycle.time >= 21.5, 20.0), "the host's clock comes over")
	var day : int = cycle.day
	await seconds(3.5)
	SleepSchedule.find(get_tree()).go_to_sleep()
	check(await wait_for(func() -> bool: return cycle.day == day + 1, 30.0), "the guest wakes on the next day too")
	await seconds(8.0)
