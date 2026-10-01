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

# Inside a building: the inside is the place, the island outside waits
# (hidden, asleep) until the player walks back out, to where they came in.
var interior : Island
var outside : Island
var outsideAt : Vector2 = Vector2.ZERO
#------------------------#

static func find(tree : SceneTree) -> World:
	return tree.get_first_node_in_group(&"worlds") as World



func _ready() -> void:
	add_to_group(&"worlds")
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
	var session : NetSession = NetSession.find(get_tree())
	if session:
		session.arrived(location)

# Counts being here for quests that ask to sail here, also for ones taken (or
# loaded) while already here.
func count_visit() -> void:
	if player.atlas.current:
		Quest.notify(player, &"visit", player.atlas.current)

func load_place(location : Location) -> void:
	drop_interior()
	DroppedItem.clear_all(get_tree())
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

# Goes into a building: loads its inside over the island, which waits.
func enter_interior(path : String, comeBackAt : Vector2) -> void:
	var island : Island = place as Island
	if interior or not island or not ResourceLoader.exists(path) or island.switching:
		return
	await island.fade_through(func() -> void:
		outside = island
		outsideAt = comeBackAt
		outside.visible = false
		outside.process_mode = Node.PROCESS_MODE_DISABLED
		outside.remove_from_group(Island.GROUP)
		for node in outside.find_children("*", "Interactable", true, false):
			node.remove_from_group(Interactable.GROUP)
		DroppedItem.clear_all(get_tree())
		interior = (load(path) as PackedScene).instantiate()
		add_child(interior)
		move_child(interior, 0)
		place = interior
		interior.enter(self)
		player.frozen = false)
	interior.fade_in()

# Back out of the building, in front of its door.
func leave_interior() -> void:
	if not interior or interior.switching:
		return
	var inside : Island = interior
	await inside.fade_through(func() -> void:
		DroppedItem.clear_all(get_tree())
		drop_interior()
		place.enter(self, outsideAt)
		player.frozen = false)
	(place as Island).fade_in()

func drop_interior() -> void:
	if not interior:
		return
	interior.queue_free()
	remove_child(interior)
	interior = null
	place = outside
	outside.visible = true
	outside.process_mode = Node.PROCESS_MODE_INHERIT
	outside.add_to_group(Island.GROUP)
	for node in outside.find_children("*", "Interactable", true, false):
		node.add_to_group(Interactable.GROUP)
	outside = null

# Where dropped things lie (see DroppedItem): beside the player, so they
# sort with everything standing around.
func drops() -> Node2D:
	var holder : Node2D = get_parent().get_node_or_null("Drops") as Node2D
	if not holder:
		holder = Node2D.new()
		holder.name = "Drops"
		holder.y_sort_enabled = true
		get_parent().add_child(holder)
	return holder

# After passing out: in the village, in front of the house.
const HOME : String = "res://world/locations/village.tres"

func wake_at_home() -> void:
	var village : Location = load(HOME)
	if player.atlas.current != village:
		arrive(village)
	else:
		drop_interior()
	var house : Node2D = place.find_child("House", true, false) as Node2D if place else null
	if house:
		player.global_position = house.global_position + Vector2(0.0, 12.0)
		if place is Island:
			(place as Island).enter(self, player.global_position)

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
