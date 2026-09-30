extends SceneTree

# Game logic cost per frame without rendering (run with --headless), in the
# places the game now has: at sea, fishing, on islands and with menus open.
# "breakdown" also switches each top-level system off in turn to show what
# it costs.
#
#   godot --headless --path godot --fixed-fps 60 -s "$PWD\tools\perf\cpu2.gd" [-- breakdown]

const FRAMES : int = 600
const WARMUP : int = 60

#------------------------#
var scene : Node
var player : Player
var world : World
var talk : DialogueUI
var results : Dictionary = {}
#------------------------#


func _initialize() -> void:
	seed(12345)
	SaveGame.slot = 2
	SaveGame.pending = {}
	scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	run.call_deferred()

func frames(count : int) -> void:
	for i in count:
		await process_frame
		if player:
			player.aimTarget = Vector2(150.0, 70.0)

func quiet() -> void:
	for i in 40:
		if talk.shown:
			talk.finish(-1)
		if talk.cardAge >= 0.0:
			talk.cardAge = talk.cardTime
		await frames(2)
	NoticeBoard.find(self).clear()

func measure(label : String) -> float:
	await frames(WARMUP)
	var start : int = Time.get_ticks_usec()
	await frames(FRAMES)
	var ms : float = (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
	results[label] = results.get(label, []) + [ms]
	return ms

func go(place : String) -> void:
	world.arrive(load("res://world/locations/%s.tres" % place))
	await frames(10)
	await quiet()

func setup(label : String) -> void:
	var inventory : InventoryUI = scene.get_node("Hud/Inventory")
	match label:
		"sea":
			await go("basic_ocean")
		"sea_rain_night":
			await go("basic_ocean")
			DayNightCycle.find(self).set_time(22.0)
			Weather.find(self).force(Weather.State.RAIN)
		"fishing":
			await go("coral_reef")
			var rod : FishingRod = player.heldItem as FishingRod
			rod.launch(Vector2(40.0, 90.0), Vector2(40.0, 90.0))
		"village":
			await go("village")
			var island : Island = world.island()
			island.show_room(island.rooms[1])
			player.global_position = island.rooms[1].global_position + Vector2(90.0, 60.0)
		"meadow":
			await go("meadow_isle")
		"inventory":
			await go("basic_ocean")
			inventory.toggle()
		"chart":
			await go("basic_ocean")
			(scene.get_node("Hud/WorldMap") as WorldMapUI).try_open()

func teardown(label : String) -> void:
	DayNightCycle.find(self).set_time(12.0)
	Weather.find(self).force(Weather.State.CLEAR)
	var rod : FishingRod = player.heldItem as FishingRod
	if rod and rod.mode != FishingRod.Mode.HOLD:
		rod.mode = FishingRod.Mode.HOLD
	if label == "inventory":
		(scene.get_node("Hud/Inventory") as InventoryUI).close()
	if label == "chart":
		(scene.get_node("Hud/WorldMap") as WorldMapUI).close()
	await frames(5)

func run() -> void:
	await frames(20)
	player = Player.find(self)
	world = scene.get_node("World")
	talk = DialogueUI.find(self)
	await quiet()
	var cycle : DayNightCycle = DayNightCycle.find(self)
	cycle.paused = true
	cycle.set_time(12.0)
	for light : NightLight in get_nodes_in_group(NightLight.GROUP):
		light.flicker = 0.0
	player.equip(0)
	var breakdown : bool = OS.get_cmdline_user_args().has("breakdown")
	var labels : Array = ["sea", "sea_rain_night", "fishing", "village", "meadow", "inventory", "chart"]
	for round in 3:
		for label in labels:
			await setup(label)
			await measure(label)
			if breakdown and round == 0:
				for node in systems():
					var before : Node.ProcessMode = node.process_mode
					node.process_mode = Node.PROCESS_MODE_DISABLED
					await measure(label + " -" + str(node.get_path()).trim_prefix("/root/TestScene/"))
					node.process_mode = before
			await teardown(label)
	for label in results:
		var values : Array = results[label].duplicate()
		values.sort()
		print("RESULT %-44s %.4f ms  %s" % [label, values[values.size() / 2], str(results[label])])
	SaveGame.erase(2)
	quit()

func systems() -> Array[Node]:
	var list : Array[Node] = []
	for path in ["World", "BasicBoat", "FishingSpotSpawner", "Player", "DayNightCycle", "Weather", "Tournament", "StoryDirector", "Hud", "SleepSchedule"]:
		if scene.has_node(path):
			list.append(scene.get_node(path))
	return list
