extends SceneTree


func _initialize() -> void:
	var start : int = Time.get_ticks_usec()
	root.add_child((load("res://test/test_scene.tscn") as PackedScene).instantiate())
	run(start)

func run(start : int) -> void:
	var last : int = Time.get_ticks_usec()
	var frames : Array = []
	for i in 10:
		await process_frame
		var now : int = Time.get_ticks_usec()
		frames.append(snappedf((now - last) / 1000.0, 0.1))
		last = now
	print("RESULT load+10 frames %.1f ms  first frames %s" % [(Time.get_ticks_usec() - start) / 1000.0, str(frames.slice(0, 4))])
	quit()
