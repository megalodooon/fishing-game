extends SceneTree

# Deterministic frames of today's game for pixel-exact before/after checks:
# sailing by day and night, rain, casting, the boat stopped, the bag, the sea
# chart, the village and an island. Run on two builds, then compare.gd.
#
#   godot --path godot --fixed-fps 60 -s "$PWD\tools\perf\capture2.gd" -- <out folder>

#------------------------#
var outDir : String = ""
var frame : int = 0
var scene : Node
var cycle : DayNightCycle
var player : Player
var world : World
var talk : DialogueUI
var aim : Vector2 = Vector2(150.0, 70.0)
#------------------------#


func _initialize() -> void:
	outDir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(outDir)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(192, 108)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	Settings.load_file()
	Settings.values.fullscreen = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# The real mouse would show tooltips wherever it happens to rest.
	root.gui_disable_input = true
	SaveGame.slot = 2
	SaveGame.pending = {}
	seed(12345)
	scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	player = scene.get_node("Player")
	physics_frame.connect(func() -> void:
		if player.aimTarget == null:
			player.aimTarget = aim)
	run.call_deferred()

func step(count : int = 1) -> void:
	for i in count:
		await process_frame
		frame += 1
		if player:
			player.aimTarget = aim

func step_to(target : int) -> void:
	await step(target - frame)

func capture(label : String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(outDir.path_join("%04d_%s.png" % [frame, label]))

func hush() -> void:
	if talk.shown:
		talk.finish(-1)
	if talk.cardAge >= 0.0:
		talk.cardAge = talk.cardTime
	NoticeBoard.find(self).clear()

func run() -> void:
	await step()
	cycle = scene.get_node("DayNightCycle")
	world = scene.get_node("World")
	talk = DialogueUI.find(self)
	cycle.paused = true
	cycle.set_time(12.0)
	for light : NightLight in get_nodes_in_group(NightLight.GROUP):
		light.flicker = 0.0
	for i in 12:
		await step()
		hush()
	world.arrive(load("res://world/locations/basic_ocean.tres"))
	Weather.find(self).force(Weather.State.CLEAR)
	for i in 30:
		await step()
		hush()
	player.equip(0)
	await step_to(100)
	await capture("sea_day")
	await step()
	await capture("sea_day")
	await step_to(130)
	await capture("sea_day")
	cycle.set_time(21.5)
	await step_to(134)
	await capture("sea_night")
	Weather.find(self).force(Weather.State.RAIN)
	await step_to(200)
	await capture("sea_night_rain")
	cycle.set_time(12.0)
	await step_to(204)
	await capture("sea_rain")
	Weather.find(self).force(Weather.State.CLEAR)
	await step_to(400)
	var rod : FishingRod = player.heldItem as FishingRod
	aim = Vector2(40.0, 90.0)
	rod.launch(Vector2(40.0, 90.0), Vector2(40.0, 90.0))
	await step_to(410)
	await capture("cast_flight")
	await step_to(470)
	await capture("cast_water")
	world.boat.stop(0.5)
	await step_to(560)
	await capture("stopped")
	world.boat.change_speed(world.boat.cruiseSpeed, 0.5)
	await step_to(600)
	await capture("moving_again")
	rod.mode = FishingRod.Mode.HOLD
	aim = Vector2(150.0, 70.0)
	var inventory : InventoryUI = scene.get_node("Hud/Inventory")
	inventory.toggle()
	await step_to(640)
	await capture("inventory")
	inventory.close()
	var map : WorldMapUI = scene.get_node("Hud/WorldMap")
	map.try_open()
	await step_to(680)
	await capture("chart")
	map.close()
	await step_to(720)
	await capture("chart_closed")
	world.arrive(load("res://world/locations/village.tres"))
	for i in 20:
		await step()
		hush()
	var island : Island = world.island()
	island.show_room(island.rooms[1])
	player.global_position = island.rooms[1].global_position + Vector2(90.0, 60.0)
	await step_to(800)
	await capture("village_square")
	world.arrive(load("res://world/locations/meadow_isle.tres"))
	for i in 20:
		await step()
		hush()
	await step_to(880)
	await capture("meadow_landing")
	island = world.island()
	island.show_room(island.rooms[1])
	player.global_position = island.rooms[1].global_position + Vector2(40.0, 40.0)
	await step_to(940)
	await capture("meadow_fields")
	world.arrive(load("res://world/locations/coral_reef.tres"))
	for i in 20:
		await step()
		hush()
	await step_to(1020)
	await capture("reef")
	SaveGame.erase(2)
	quit()
