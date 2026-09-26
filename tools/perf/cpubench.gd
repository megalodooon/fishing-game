extends SceneTree

const FRAMES : int = 3000
const ROUNDS : int = 3

#------------------------#
var scene : Node
var results : Dictionary = {}
#------------------------#


func _initialize() -> void:
	seed(12345)
	scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	var ripples : ShaderMaterial = scene.get_node("BasicBoat/Ripples").material
	for pair in [["crest_width", 0.45], ["trough_width", 0.8], ["wobble", 1.2], ["hull_center", Vector2(0.5, 20.5)], ["hull_radii", Vector2(48.0, 20.0)]]:
		if ripples.get_shader_parameter(pair[0]) == null:
			ripples.set_shader_parameter(pair[0], pair[1])
	root.add_child(scene)
	current_scene = scene
	run()

func run() -> void:
	for i in 3:
		await process_frame
	var player : Player = scene.get_node("Player")
	var cycle : DayNightCycle = scene.get_node("DayNightCycle")
	cycle.paused = true
	for light : NightLight in get_nodes_in_group(NightLight.GROUP):
		light.flicker = 0.0
	player.equip(0)
	var rod : FishingRod = player.heldItem as FishingRod
	for i in ROUNDS:
		for label in ["day", "night", "fishing"]:
			cycle.set_time(22.0 if label == "night" else 12.0)
			if rod.mode != FishingRod.Mode.HOLD:
				rod.mode = FishingRod.Mode.HOLD
			if label == "fishing":
				rod.launch(Vector2(62.0, 96.0))
			for j in 120:
				await process_frame
				player.aimTarget = Vector2(150.0, 70.0)
			var start : int = Time.get_ticks_usec()
			for j in FRAMES:
				await process_frame
				player.aimTarget = Vector2(150.0, 70.0)
			if not results.has(label):
				results[label] = []
			results[label].append((Time.get_ticks_usec() - start) / 1000.0 / FRAMES)
	for label in results:
		var values : Array = results[label].duplicate()
		values.sort()
		@warning_ignore("integer_division")
		print("RESULT %-8s frame %.4f ms  rounds %s" % [label, values[values.size() / 2], str(results[label])])
	quit()
