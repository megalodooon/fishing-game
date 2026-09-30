extends SceneTree

# A scripted play session at the normal vsync-locked frame rate that logs
# every slow frame and what was going on: menus, the sea chart, sailing,
# islands and their rooms, talking, catching fish and minigames.
#
#   godot --path godot -s "$PWD\tools\perf\hitch.gd"

const SLOW_MS : float = 20.0

#------------------------#
var scene : Node
var player : Player
var world : World
var talk : DialogueUI
var event : String = "start"
var last : int = 0
var frameTimes : PackedFloat32Array = PackedFloat32Array()
var slow : Array = []
#------------------------#


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(192, 108)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	Settings.load_file()
	Settings.values.fullscreen = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	seed(12345)
	SaveGame.slot = 2
	SaveGame.pending = {}
	start.call_deferred()

# Through the real loading screen (preloading and warm-up), like pressing Play.
func start() -> void:
	var began : int = Time.get_ticks_usec()
	if OS.get_cmdline_user_args().has("direct"):
		# Preloaded the same way, but no loading screen or warm-up.
		Preloader.start()
		while not Preloader.done():
			Preloader.poll()
			await process_frame
		Preloader.poll()
		scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
		root.add_child(scene)
		current_scene = scene
	else:
		var loading : Node = (load("res://ui/loading/loading_screen.tscn") as PackedScene).instantiate()
		root.add_child(loading)
		while is_instance_valid(loading):
			await process_frame
		scene = current_scene
	print("PRELOAD %.0f ms" % ((Time.get_ticks_usec() - began) / 1000.0))
	process_frame.connect(tick)
	run()

func tick() -> void:
	var now : int = Time.get_ticks_usec()
	if last > 0:
		var ms : float = (now - last) / 1000.0
		frameTimes.append(ms)
		if ms > SLOW_MS:
			slow.append([ms, event])
	last = now

func frames(count : int) -> void:
	for i in count:
		await process_frame

func mark(label : String) -> void:
	event = label

func quiet() -> void:
	for i in 60:
		if talk.shown:
			talk.finish(-1)
		if talk.cardAge >= 0.0:
			talk.cardAge = talk.cardTime
		await frames(1)

func run() -> void:
	await frames(30)
	player = Player.find(self)
	world = scene.get_node("World")
	talk = DialogueUI.find(self)
	mark("intro")
	await quiet()
	player.wallet.add(50000)
	for location in player.atlas.locations:
		if not player.atlas.is_unlocked(location):
			player.atlas.unlocked.append(location)
	mark("sea idle")
	await frames(120)
	mark("equip rod")
	player.equip(0)
	await frames(60)
	var hud : Node = scene.get_node("Hud")
	for pair in [["inventory", "Inventory"], ["tacklebox", "Tacklebox"], ["journal", "Journal"]]:
		mark("open " + pair[0])
		hud.get_node(pair[1]).toggle()
		await frames(60)
		mark("close " + pair[0])
		hud.get_node(pair[1]).close()
		await frames(30)
	mark("open profile")
	(hud.get_node("Profile") as ProfileUI).open_profile()
	await frames(30)
	for tab in 3:
		mark("profile tab %d" % tab)
		(hud.get_node("Profile") as ProfileUI).tab = tab
		await frames(30)
	(hud.get_node("Profile") as ProfileUI).close()
	await frames(30)
	mark("open pause")
	(hud.get_node("Pause") as PauseMenu).open_pause()
	await frames(60)
	(hud.get_node("Pause") as PauseMenu).resume()
	await frames(30)
	mark("catch fish")
	var catchState : PlayerCatchState = player.handStates.get_node("Catch")
	for path in ["res://fishing/fish/species/anchovy.tres", "res://fishing/fish/species/sea_bass.tres", "res://fishing/fish/species/reef/lionfish.tres"]:
		catchState.fishBiome = Ocean.current_biome(self)
		catchState.land(Fish.caught(load(path)))
		await frames(40)
	var screen : MinigameScreen = player.minigameScreen
	for game in ["reel_bar", "bullet_hell", "boss_duel", "lure_dance", "reel_rhythm", "net_chase", "strike_rings", "timing_needle", "line_tension"]:
		mark("minigame " + game)
		var mini : Minigame = (load("res://fishing/minigames/%s/%s.tscn" % [game, game]) as PackedScene).instantiate()
		screen.play(mini)
		mini.begin(0.5, 0.5, Color(0.4, 0.72, 1.0), (load("res://fishing/fish/species/reef/lionfish.tres") as FishData).icon)
		await frames(50)
		mini.finish(true)
		await frames(30)
	var map : WorldMapUI = hud.get_node("WorldMap")
	for place in ["meadow_isle", "coral_reef", "village", "ember_isle", "volcanic_ocean"]:
		mark("open chart")
		map.try_open()
		await frames(40)
		mark("sail to " + place)
		map.sail(load("res://world/locations/%s.tres" % place))
		while map.shown:
			await frames(1)
		mark("arrived " + place)
		await quiet()
		await frames(60)
		var island : Island = world.island()
		if island:
			for room in island.rooms:
				mark("room " + room.name)
				player.global_position = room.global_position + Vector2(96.0, 54.0)
				await frames(40)
			for node in get_nodes_in_group(Interactable.GROUP):
				if node is Npc and node.is_visible_in_tree():
					mark("talk " + node.id)
					node.interact(player)
					await frames(40)
					await quiet()
					break
			for node in get_nodes_in_group(Interactable.GROUP):
				if node is Counter and node.listed and node.is_visible_in_tree():
					mark("counter " + node.title)
					node.interact(player)
					await frames(40)
					CounterUI.find(self).close()
					await frames(20)
	mark("weather rain")
	Weather.find(self).force(Weather.State.RAIN)
	await frames(120)
	mark("weather fog")
	Weather.find(self).force(Weather.State.FOG)
	await frames(120)
	mark("night")
	DayNightCycle.find(self).set_time(22.0)
	await frames(120)
	var sorted : PackedFloat32Array = frameTimes.duplicate()
	sorted.sort()
	var over17 : int = 0
	for ms in frameTimes:
		if ms > 17.5:
			over17 += 1
	print("FRAMES %d  median %.2f ms  p99 %.2f ms  max %.2f ms  over 17.5 ms: %d" % [sorted.size(), sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.99)], sorted[-1], over17])
	for entry in slow:
		print("SLOW %7.1f ms  %s" % [entry[0], entry[1]])
	SaveGame.erase(2)
	quit()
