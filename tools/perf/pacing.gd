extends SceneTree

# Frame pacing at the vsync-locked frame rate in one place: how long frames
# are between presents, how many physics ticks each frame ran, and how much
# of each frame the game itself used.
#
#   godot --path godot -s "$PWD\tools\perf\pacing.gd" [-- place=basic_ocean]

#------------------------#
var scene : Node
var last : int = 0
var ticks : int = 0
var deltas : PackedFloat32Array = PackedFloat32Array()
var tickCounts : Dictionary = {}
var busy : PackedFloat32Array = PackedFloat32Array()
var frameStart : int = 0
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
	scene = (load("res://test/test_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	run.call_deferred()

func run() -> void:
	for i in 60:
		await process_frame
	var talk : DialogueUI = DialogueUI.find(self)
	for i in 60:
		if talk.shown:
			talk.finish(-1)
		if talk.cardAge >= 0.0:
			talk.cardAge = talk.cardTime
		await process_frame
	var place : String = "basic_ocean"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("place="):
			place = arg.trim_prefix("place=")
	(scene.get_node("World") as World).arrive(load("res://world/locations/%s.tres" % place))
	for i in 120:
		await process_frame
	physics_frame.connect(func() -> void: ticks += 1)
	process_frame.connect(sample)
	for i in 900:
		await process_frame
	process_frame.disconnect(sample)
	var sorted : PackedFloat32Array = deltas.duplicate()
	sorted.sort()
	var buckets : Dictionary = {}
	for ms in deltas:
		var key : int = int(roundf(ms))
		buckets[key] = buckets.get(key, 0) + 1
	var keys : Array = buckets.keys()
	keys.sort()
	var histogram : PackedStringArray = PackedStringArray()
	for key in keys:
		histogram.append("%dms:%d" % [key, buckets[key]])
	var busySorted : PackedFloat32Array = busy.duplicate()
	busySorted.sort()
	print("PACING frames %d  median %.2f  p95 %.2f  p99 %.2f  max %.2f" % [sorted.size(), sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)], sorted[int(sorted.size() * 0.99)], sorted[-1]])
	print("HISTOGRAM ", " ".join(histogram))
	print("PHYSICS TICKS PER FRAME ", tickCounts)
	print("PROCESS TIME per frame (Performance.TIME_PROCESS) median %.2f ms  p99 %.2f ms" % [busySorted[busySorted.size() / 2] * 1000.0, busySorted[int(busySorted.size() * 0.99)] * 1000.0])
	SaveGame.erase(2)
	quit()

func sample() -> void:
	var now : int = Time.get_ticks_usec()
	if last > 0:
		deltas.append((now - last) / 1000.0)
		tickCounts[ticks] = tickCounts.get(ticks, 0) + 1
		busy.append(Performance.get_monitor(Performance.TIME_PROCESS))
	ticks = 0
	last = now
