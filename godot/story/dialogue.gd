extends RefCounted
class_name Dialogue

# All the spoken lines, read from story/dialogue.txt. The file is split into
# scenes by lines like "[scene_id]". Every line after that is "who: what
# they say" (who is a Cast id), and a scene can end in choices written as
# "> Choice text". Lines starting with # are notes. Scenes named "<id>_chat"
# are pools of small talk: one line is picked at random.

const FILE : String = "res://story/dialogue.txt"

static var scenes : Dictionary = {}
static var loaded : bool = false


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var file : FileAccess = FileAccess.open(FILE, FileAccess.READ)
	if not file:
		return
	var current : String = ""
	for raw in file.get_as_text().split("\n"):
		var line : String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2)
			scenes[current] = {"lines": [], "choices": PackedStringArray()}
		elif current.is_empty():
			continue
		elif line.begins_with(">"):
			scenes[current].choices.append(line.substr(1).strip_edges())
		else:
			var split : int = line.find(":")
			if split > 0 and not line.substr(0, split).contains(" "):
				scenes[current].lines.append([line.substr(0, split), line.substr(split + 1).strip_edges()])
			else:
				scenes[current].lines.append(["narrator", line])

static func has_scene(id : String) -> bool:
	load_all()
	return scenes.has(id)

# Every line of a scene as [speaker, text].
static func lines(id : String) -> Array:
	load_all()
	return scenes[id].lines if scenes.has(id) else []

static func choices(id : String) -> PackedStringArray:
	load_all()
	return scenes[id].choices if scenes.has(id) else PackedStringArray()

static func random_line(id : String) -> Array:
	var list : Array = lines(id)
	return list.pick_random() if not list.is_empty() else []
