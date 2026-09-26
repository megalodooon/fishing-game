extends SceneTree


func _initialize() -> void:
	var before : String = OS.get_cmdline_user_args()[0]
	var after : String = OS.get_cmdline_user_args()[1]
	var total : int = 0
	var identical : int = 0
	for file in DirAccess.get_files_at(before):
		if not file.ends_with(".png"):
			continue
		total += 1
		if not FileAccess.file_exists(after.path_join(file)):
			print("MISSING ", file)
			continue
		var left : Image = Image.load_from_file(before.path_join(file))
		var right : Image = Image.load_from_file(after.path_join(file))
		if left.get_size() != right.get_size():
			print("SIZE ", file, " ", left.get_size(), " vs ", right.get_size())
			continue
		if left.get_data() == right.get_data():
			identical += 1
			print("SAME ", file)
			continue
		left.convert(Image.FORMAT_RGB8)
		right.convert(Image.FORMAT_RGB8)
		var a : PackedByteArray = left.get_data()
		var b : PackedByteArray = right.get_data()
		var differing : int = 0
		var largest : int = 0
		for i in range(0, a.size(), 3):
			var difference : int = maxi(absi(a[i] - b[i]), maxi(absi(a[i + 1] - b[i + 1]), absi(a[i + 2] - b[i + 2])))
			if difference > 0:
				differing += 1
				largest = maxi(largest, difference)
		print("DIFF %s pixels=%d (%.4f%%) max=%d" % [file, differing, 100.0 * differing / (left.get_width() * left.get_height()), largest])
	print("RESULT %d/%d identical" % [identical, total])
	quit()
