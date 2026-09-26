extends SceneTree

const FRAMES : int = 300
const WARMUP : int = 40
const ROUNDS : int = 3

#------------------------#
var scene : Node
var cycle : DayNightCycle
var player : Player
var boat : Boat
var rod : FishingRod
var viewports : Array[RID] = []
var viewportNames : PackedStringArray = PackedStringArray()
var aim : Vector2 = Vector2(150.0, 70.0)
var results : Dictionary = {}
#------------------------#


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(12345)
	scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	run()

func frames(count : int) -> void:
	for i in count:
		await process_frame
		if player:
			player.aimTarget = aim

func node(path : String) -> Node:
	return scene.get_node(path)

func scenario(label : String) -> void:
	if label == "stopped":
		boat.stop(0.01)
	else:
		boat.change_speed(boat.cruiseSpeed, 0.01)
	cycle.set_time(22.0 if label == "night" else 12.0)
	if rod.mode != FishingRod.Mode.HOLD:
		rod.mode = FishingRod.Mode.HOLD
		await frames(10)
	if label == "fishing":
		rod.launch(Vector2(62.0, 96.0))
		await frames(60)

func measure(label : String) -> void:
	await frames(WARMUP)
	var gpu : float = 0.0
	var cpu : float = 0.0
	var perViewport : PackedFloat64Array = PackedFloat64Array()
	perViewport.resize(viewports.size())
	var start : int = Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
		if player:
			player.aimTarget = aim
		for v in viewports.size():
			var time : float = RenderingServer.viewport_get_measured_render_time_gpu(viewports[v])
			gpu += time
			perViewport[v] += time
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewports[v])
	var frameMs : float = (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
	if not results.has(label):
		results[label] = {"gpu": [], "cpu": [], "frame": [], "viewports": []}
	results[label]["gpu"].append(gpu / FRAMES)
	results[label]["cpu"].append(cpu / FRAMES)
	results[label]["frame"].append(frameMs)
	var split : PackedFloat64Array = PackedFloat64Array()
	for v in viewports.size():
		split.append(perViewport[v] / FRAMES)
	results[label]["viewports"].append(split)

func median(values : Array) -> float:
	var sorted : Array = values.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return sorted[sorted.size() / 2]

func run() -> void:
	await frames(2)
	cycle = node("DayNightCycle")
	player = node("Player")
	boat = node("BasicBoat")
	cycle.paused = true
	for light : NightLight in get_nodes_in_group(NightLight.GROUP):
		light.flicker = 0.0
	player.equip(0)
	rod = player.heldItem as FishingRod
	viewports.append(root.get_viewport_rid())
	viewportNames.append("root")
	for sub : SubViewport in scene.find_children("*", "SubViewport", true, false):
		viewports.append(sub.get_viewport_rid())
		viewportNames.append(str(sub.get_parent().name) + "/" + str(sub.get_index(true)))
	for rid in viewports:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	await frames(60)
	var mode : String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "scenarios"
	if mode == "scenarios" or mode == "once":
		for i in (ROUNDS if mode == "scenarios" else 1):
			for label in ["day", "night", "fishing", "stopped"]:
				await scenario(label)
				await measure(label)
	elif mode == "quick" or mode == "vsync":
		await scenario("day")
		for i in 5:
			await measure("day")
	else:
		var toggles : Array = breakdown()
		for i in ROUNDS:
			await scenario("day")
			await measure("all")
			for entry in toggles:
				entry[1].call()
				await measure(entry[0])
				entry[2].call()
	for label in results:
		print("RESULT %-22s gpu %.3f ms  rendercpu %.3f ms  frame %.3f ms  gpu rounds %s" % [label, median(results[label]["gpu"]), median(results[label]["cpu"]), median(results[label]["frame"]), str(results[label]["gpu"]).replace(" ", "")])
		var parts : PackedStringArray = PackedStringArray()
		for v in viewports.size():
			var values : Array = []
			for split in results[label]["viewports"]:
				values.append(split[v])
			parts.append("%s=%.3f" % [viewportNames[v], median(values)])
		print("   VIEWPORTS ", ", ".join(parts))
	quit()

func hide_node(path : String) -> Array:
	return [path, func() -> void: node(path).visible = false, func() -> void: node(path).visible = true]

func breakdown() -> Array:
	return [
		hide_node("BasicOcean/Sprite2D"),
		hide_node("BasicOcean/Ground"),
		hide_node("BasicOcean/DecorationLayer"),
		hide_node("BasicBoat/Wake/Distortion"),
		["BasicBoat/Wake/BackBufferCopy+Distortion", func() -> void:
			node("BasicBoat/Wake/Distortion").visible = false
			node("BasicBoat/Wake/BackBufferCopy").copy_mode = BackBufferCopy.COPY_MODE_DISABLED,
		func() -> void:
			node("BasicBoat/Wake/Distortion").visible = true
			node("BasicBoat/Wake/BackBufferCopy").copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT],
		hide_node("BasicBoat/Wake/Foam"),
		hide_node("BasicBoat/Ripples"),
		hide_node("BasicBoat/Visuals/Top"),
		hide_node("BasicBoat/Visuals/Front"),
		hide_node("BasicBoat/Visuals/FrontUnderwater"),
		hide_node("BasicBoat/Visuals/Mast"),
		hide_node("BasicBoat/Visuals"),
		hide_node("Player"),
		hide_node("FishingSpotSpawner"),
		hide_node("Hud"),
	]
