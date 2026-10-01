extends Node2D
class_name World

# Holds the scene of the place the boat is at (an ocean, or an island with
# its own water) and swaps it when the boat arrives somewhere new.

#------------------------#
# The loaded place, a child of this node.
@export var place : Node
@export var boat : Boat
@export var player : Player
@export var spawner : FishingSpotSpawner
# Moved from screen to screen on islands, back to the start elsewhere.
@export var camera : Camera2D
# Where the player stands on the deck after coming back from an island.
@export var boardOffset : Vector2 = Vector2(-26.0, 3.0)
#------------------------#


func _ready() -> void:
	# Normally the loading screen has already loaded everything; this covers
	# starting the game scene directly, like from the editor.
	Preloader.start()
	set_process(not Preloader.done())
	player.atlas.setup()
	player.progress.quest_taken.connect(func(_quest : Quest) -> void: count_visit())
	var session : NetSession = NetSession.new()
	session.setup(self)
	add_child(session)
	if not SaveGame.pending.is_empty():
		load_save.call_deferred()
	else:
		player.progress.playerName = SaveGame.newName
	var location : Location = player.atlas.current
	if location and not location.scene.is_empty() and (not place or place.scene_file_path != location.scene):
		load_place(location)
	elif location:
		settle(location)

func _process(_delta : float) -> void:
	Preloader.poll()
	if Preloader.done():
		set_process(false)

func arrive(location : Location) -> void:
	player.atlas.arrive(location)
	load_place(location)
	count_visit()

# Counts being here for quests that ask to sail here, also for ones taken (or
# loaded) while already here.
func count_visit() -> void:
	if player.atlas.current:
		Quest.notify(player, &"visit", player.atlas.current)

func load_place(location : Location) -> void:
	if place:
		if place is Island:
			(place as Island).leave()
		remove_child(place)
		place.queue_free()
	place = (load(location.scene) as PackedScene).instantiate()
	for node in [place] + place.find_children("*", "Node2D", true, false):
		if node is Ocean:
			node.boat = boat
	add_child(place)
	move_child(place, 0)
	if spawner:
		for spot in spawner.get_children():
			spot.queue_free()
	settle(location)

func settle(location : Location) -> void:
	boat.set_docked(location.is_island())
	if place is Island:
		(place as Island).enter(self)
		return
	if not boat.on_deck(player.global_position):
		board()
	if camera:
		camera.position = Vector2.ZERO

# Puts the player back aboard, out at sea.
func board() -> void:
	player.global_position = boat.global_position + boardOffset

# Where the player stands: an island when docked at one, null out at sea.
func island() -> Island:
	return place as Island

# Puts the save the title screen picked into the game, once everything is
# ready, and moves to where the boat was.
func load_save() -> void:
	var data : Dictionary = SaveGame.pending
	SaveGame.pending = {}
	SaveGame.load_into(get_tree(), data)
	player.wake_reset()
	board()
	BoatParts.apply(player)
	if player.atlas.current:
		load_place(player.atlas.current)
	count_visit()
