extends SceneTree

# GPU time per frame in the places the game now has, summed over the main
# viewport and every SubViewport (ocean passes, seabeds). "breakdown" hides
# each part in turn to show what it costs.
#
#   godot --path godot --fullscreen --fixed-fps 60 -s "$PWD\tools\perf\gpu2.gd" [-- breakdown] [-- only=sea,village]

const FRAMES : int = 240
const WARMUP : int = 40

#------------------------#
var scene : Node
var player : Player
var world : World
var talk : DialogueUI
var results : Dictionary = {}
#------------------------#


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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

func viewports() -> Array[RID]:
	var list : Array[RID] = [root.get_viewport_rid()]
	for sub : SubViewport in root.find_children("*", "SubViewport", true, false):
		list.append(sub.get_viewport_rid())
	for rid in list:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	return list

func measure(label : String) -> void:
	var rids : Array[RID] = viewports()
	await frames(WARMUP)
	var gpu : float = 0.0
	var cpu : float = 0.0
	var start : int = Time.get_ticks_usec()
	for i in FRAMES:
		await frames(1)
		for rid in rids:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var frameMs : float = (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
	if not results.has(label):
		results[label] = {"gpu": [], "cpu": [], "frame": []}
	results[label].gpu.append(gpu / FRAMES)
	results[label].cpu.append(cpu / FRAMES)
	results[label].frame.append(frameMs)

func go(place : String) -> void:
	world.arrive(load("res://world/locations/%s.tres" % place))
	await frames(10)
	await quiet()

func setup(label : String) -> void:
	match label:
		"sea", "sea_rain_night", "inventory", "chart":
			await go("basic_ocean")
		"fishing":
			await go("coral_reef")
		"village":
			await go("village")
			var island : Island = world.island()
			island.show_room(island.rooms[1])
			player.global_position = island.rooms[1].global_position + Vector2(90.0, 60.0)
		"meadow":
			await go("meadow_isle")
	match label:
		"sea_rain_night":
			DayNightCycle.find(self).set_time(22.0)
			Weather.find(self).force(Weather.State.RAIN)
		"fishing":
			(player.heldItem as FishingRod).launch(Vector2(40.0, 90.0), Vector2(40.0, 90.0))
		"inventory":
			(scene.get_node("Hud/Inventory") as InventoryUI).toggle()
		"chart":
			(scene.get_node("Hud/WorldMap") as WorldMapUI).try_open()
	await frames(30)

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
	await frames(20)

func parts() -> Array:
	var list : Array = []
	var place : Node = world.place
	for ocean : Ocean in place.find_children("*", "Ocean", true, false) + ([place] if place is Ocean else []):
		if ocean.is_visible_in_tree():
			for child in ocean.get_children():
				if child is CanvasItem:
					list.append(child)
	if place is Island:
		var island : Island = place
		for child in island.room.get_children():
			if child is CanvasItem and not child is Ocean:
				list.append(child)
	var boat : Boat = world.boat
	for path in ["Wake", "Ripples", "Visuals"]:
		if boat.has_node(path):
			list.append(boat.get_node(path))
	list.append(player)
	list.append(scene.get_node("FishingSpotSpawner"))
	for layer in root.find_children("*", "CanvasLayer", true, false):
		list.append(layer)
	return list

func run() -> void:
	await frames(20)
	player = Player.find(self)
	world = scene.get_node("World")
	talk = DialogueUI.find(self)
	await quiet()
	print("WINDOW ", DisplayServer.window_get_size(), " renderer ", RenderingServer.get_current_rendering_method())
	var cycle : DayNightCycle = DayNightCycle.find(self)
	cycle.paused = true
	cycle.set_time(12.0)
	for light : NightLight in get_nodes_in_group(NightLight.GROUP):
		light.flicker = 0.0
	player.equip(0)
	var labels : Array = ["sea", "sea_rain_night", "fishing", "village", "meadow", "inventory", "chart"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			labels = Array(arg.trim_prefix("only=").split(","))
	var breakdown : bool = OS.get_cmdline_user_args().has("breakdown")
	for round in (1 if breakdown else 3):
		for label in labels:
			await setup(label)
			await measure(label)
			if breakdown:
				for part in parts():
					var shown : bool = part.visible
					if not shown:
						continue
					part.visible = false
					await measure("%s -%s" % [label, part.name])
					part.visible = true
			await teardown(label)
	for label in results:
		var entry : Dictionary = results[label]
		print("RESULT %-36s gpu %.3f  rendercpu %.3f  frame %.3f   gpu rounds %s" % [label, median(entry.gpu), median(entry.cpu), median(entry.frame), str(entry.gpu)])
	SaveGame.erase(2)
	quit()

func median(values : Array) -> float:
	var sorted : Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
