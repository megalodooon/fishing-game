extends RefCounted
class_name Features

# The first time each system is used, someone explains it in a few lines (the
# "intro_<id>" scenes in the dialogue file): the bank, the trophy lodge, the
# hunters' board, forage spots, the charm pouch... Each plays once, so the
# game opens up one thing at a time instead of all at once. Seen intros are
# progress flags ("intro/<id>").


static func seen(player : Player, id : String) -> bool:
	return player.progress.has_flag("intro/" + id)

# Plays the intro if it hasn't been seen, then calls back (right away when
# there's nothing to show).
static func introduce(player : Player, id : String, callback : Callable = Callable()) -> void:
	var scene : String = "intro_" + id
	if id.is_empty() or seen(player, id) or not Dialogue.has_scene(scene):
		if callback.is_valid():
			callback.call()
		return
	player.progress.set_flag("intro/" + id)
	var story : StoryDirector = StoryDirector.find(player.get_tree())
	if not story:
		if callback.is_valid():
			callback.call()
		return
	story.play(scene, func(_choice : int) -> void:
		if callback.is_valid():
			callback.call())
