extends SceneTree

#------------------------#
var outDir : String = ""
var frame : int = 0
var scene : Node
var cycle : DayNightCycle
var player : Player
var boat : Boat
var aim : Vector2 = Vector2(150.0, 70.0)
#------------------------#


func _initialize() -> void:
	outDir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(outDir)
	seed(12345)
	scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	run()

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
	root.get_texture().get_image().save_png(outDir.path_join("%03d_%s.png" % [frame, label]))

func run() -> void:
	await step()
	cycle = scene.get_node("DayNightCycle")
	player = scene.get_node("Player")
	boat = scene.get_node("BasicBoat")
	cycle.paused = true
	cycle.set_time(12.0)
	for light : NightLight in get_nodes_in_group(NightLight.GROUP):
		light.flicker = light.flicker if OS.get_cmdline_user_args().has("flicker") else 0.0
	player.aimTarget = aim
	await step_to(2)
	await capture("start")
	await step()
	await capture("start")
	await step_to(5)
	await capture("start")
	await step_to(10)
	player.equip(0)
	await step_to(60)
	await capture("day")
	await step()
	await capture("day")
	await step_to(65)
	await capture("day")
	await step_to(70)
	await capture("day")
	cycle.set_time(6.5)
	await step_to(72)
	await capture("sunrise")
	cycle.set_time(19.5)
	await step_to(74)
	await capture("dusk")
	cycle.set_time(21.0)
	await step_to(76)
	await capture("night")
	await step()
	await capture("night")
	cycle.set_time(12.0)
	var rod : FishingRod = player.heldItem as FishingRod
	aim = Vector2(40.0, 90.0)
	await step_to(82)
	rod.launch(Vector2(40.0, 90.0))
	await step_to(88)
	await capture("cast_flight")
	await step_to(94)
	await capture("cast_flight")
	await step_to(150)
	await capture("cast_water")
	await step()
	await capture("cast_water")
	player.global_position = Vector2(112.0, 40.0)
	aim = Vector2(40.0, 10.0)
	await step_to(190)
	await capture("behind_mast")
	await step()
	await capture("behind_mast")
	player.global_position = Vector2(66.0, 50.0)
	await step_to(210)
	await capture("rim_shadow")
	boat.stop(0.5)
	await step_to(222)
	await capture("slowing")
	await step_to(300)
	await capture("stopped")
	cycle.set_time(22.0)
	await step_to(302)
	await capture("stopped_night")
	cycle.set_time(12.0)
	boat.change_speed(boat.cruiseSpeed, 0.5)
	await step_to(315)
	await capture("accelerating")
	await step_to(360)
	await capture("moving_again")
	quit()
