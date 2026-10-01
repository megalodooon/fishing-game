extends Node
class_name StoryDirector

# Runs the story around the player: the intro on a new game, the scenes
# quests play when taken and handed in, scenes on the first arrival at a
# place ("arrive_<location file>") and the chapter cards. Scenes wait their
# turn when another one is still on screen.

#------------------------#
@export var player : Player
@export var dialogue : DialogueUI
# Taken automatically at the end of the intro.
@export var firstQuest : Quest
@export var introDelay : float = 0.8

var lastChapter : int = 0
var lastPlace : Location
var waiting : Array[Array] = []
#------------------------#


static func find(tree : SceneTree) -> StoryDirector:
	return tree.get_first_node_in_group(&"story_directors") as StoryDirector

func _ready() -> void:
	add_to_group(&"story_directors")
	player.progress.quest_taken.connect(on_started)
	player.progress.quest_handed_in.connect(on_finished)
	player.atlas.changed.connect(on_atlas)
	begin.call_deferred()

func begin() -> void:
	await get_tree().create_timer(introDelay).timeout
	lastChapter = player.progress.chapter
	lastPlace = player.atlas.current
	if not player.progress.has_flag("story/intro"):
		player.progress.set_flag("story/intro")
		play("intro", func(_choice : int) -> void:
			ask_name(func() -> void:
				play("intro_named", func(_c : int) -> void:
					show_card()
					if firstQuest and not player.progress.quest_started(firstQuest):
						player.progress.start_quest(firstQuest))))
	elif player.progress.playerName.is_empty():
		ask_name(Callable())
	elif Net.is_guest() and not player.progress.has_flag("intro/guest"):
		# A friend's first time in this world: someone says hello.
		player.progress.set_flag("intro/guest")
		play("guest_intro")
	# Pip walks them through the first fish until one is landed.
	if not player.progress.has_flag(FishingTutorial.FLAG):
		var tutorial : FishingTutorial = FishingTutorial.new()
		tutorial.player = player
		tutorial.dialogue = dialogue
		add_child(tutorial)

# Pip asks the player's name (once; a guest named themselves when joining).
func ask_name(then : Callable) -> void:
	if not player.progress.playerName.is_empty():
		if then.is_valid():
			then.call()
		return
	dialogue.ask_name("pip", "Sorry, my memory's like a sieve these days. What was your name again?", func(_name : Variant) -> void:
		if then.is_valid():
			then.call())

# Watching along (multiplayer): the other player started this scene, so
# choices in it change nothing here.
func play(id : String, callback : Callable = Callable(), _watching : bool = false) -> void:
	if id.is_empty() or not Dialogue.has_scene(id):
		if callback.is_valid():
			callback.call(-1)
		return
	if dialogue.busy():
		waiting.append([id, callback])
		return
	dialogue.play(id, callback)

func _process(_delta : float) -> void:
	if not waiting.is_empty() and not dialogue.busy():
		var next : Array = waiting.pop_front()
		dialogue.play(next[0], next[1])

func on_started(quest : Quest) -> void:
	play(quest.startScene)
	share(quest.startScene, quest.title)

func on_finished(quest : Quest) -> void:
	play(quest.endScene, func(_choice : int) -> void: check_chapter())
	share(quest.endScene, quest.title)
	if quest.endScene.is_empty() or not Dialogue.has_scene(quest.endScene):
		check_chapter.call_deferred()

# The other player in a multiplayer game sees story scenes too.
func share(id : String, title : String) -> void:
	var session : NetSession = NetSession.find(get_tree())
	if session and Dialogue.has_scene(id):
		session.share_scene(id, title)

# A story scene that played in the other player's game while this one was
# somewhere else, kept to watch later from the quest log.
func remember(id : String) -> void:
	if Dialogue.has_scene(id) and not player.progress.missedScenes.has(id):
		player.progress.missedScenes.append(id)
		player.progress.emit_changed()

func check_chapter() -> void:
	if player.progress.chapter > lastChapter:
		lastChapter = player.progress.chapter
		show_card()

func show_card() -> void:
	var index : int = player.progress.chapter
	dialogue.card(Story.chapter_title(index), "Epilogue" if index >= Story.CHAPTERS.size() - 1 else "Chapter %d" % (index + 1))

func on_atlas() -> void:
	var place : Location = player.atlas.current
	if place == lastPlace or not place:
		return
	lastPlace = place
	var key : String = place.resource_path.get_file().get_basename()
	if not player.progress.has_flag("arrived/" + key):
		player.progress.set_flag("arrived/" + key)
		play("arrive_" + key)
