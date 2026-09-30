extends Node
class_name EventDirector

# Runs the calendar's festivals (see GameEvent): announces them when they
# start and end, puts their host's stall in the village square, scatters the
# day's pickups over the island the player is on, and tells the catch what
# can bite and drop. It also lays out each island's things to gather. The fishing side asks active() and fish_pool().

const GROUP : StringName = &"event_directors"
# Where the festival host stands in the village square.
const HOST_SPOT : Vector2 = Vector2(86.0, 74.0)

#------------------------#
@export var player : Player
@export var cycle : DayNightCycle
@export var world : World
@export var notices : NoticeBoard

var running : Array[GameEvent] = []
var hosts : Array[Node] = []
var spawnedFor : Node
var spawnedDay : int = -1
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	cycle.time_changed.connect(check.unbind(2))
	cycle.day_changed.connect(func(_day : int) -> void:
		spawnedDay = -1
		tidy()
		check())
	player.atlas.changed.connect(arrived.call_deferred)
	start.call_deferred()

func start() -> void:
	running = Calendar.active(get_tree())
	for event in running:
		introduce(event)
	arrived()

# The first time a festival is seen, its opening scene plays (festival_<file>).
func introduce(event : GameEvent) -> void:
	var key : String = "festival_seen/" + event.key()
	if player.progress.has_flag(key):
		return
	player.progress.set_flag(key)
	var story : StoryDirector = StoryDirector.find(get_tree())
	if story:
		story.play("festival_" + event.key())

static func find(tree : SceneTree) -> EventDirector:
	return tree.get_first_node_in_group(GROUP) as EventDirector

# The festivals running right now.
static func active(tree : SceneTree) -> Array[GameEvent]:
	var director : EventDirector = find(tree)
	return director.running if director else Calendar.active(tree)

func check() -> void:
	var now : Array[GameEvent] = Calendar.active(get_tree())
	for event in now:
		if not running.has(event):
			announce(event, true)
			introduce(event)
	for event in running:
		if not now.has(event):
			announce(event, false)
	if now != running:
		running = now
		spawnedDay = -1
		arrived()

func announce(event : GameEvent, started : bool) -> void:
	if not notices:
		return
	if started:
		notices.post("%s has begun!" % event.displayName, event.startText if not event.startText.is_empty() else event.description, event.color, event.icon)
	else:
		notices.post("%s is over" % event.displayName, event.endText if not event.endText.is_empty() else "See you next year!", event.color, event.icon)

# Sets up the place the player is at: hosts in the village, pickups on islands.
func arrived() -> void:
	for host in hosts:
		if is_instance_valid(host):
			host.queue_free()
	hosts.clear()
	var island : Island = world.island() if world else null
	if not island:
		return
	for event in running:
		if not event.host.is_empty() and player.atlas.current and player.atlas.current.resource_path.ends_with("village.tres"):
			place_host(island, event)
	if spawnedFor != island or spawnedDay != cycle.day:
		spawnedFor = island
		spawnedDay = cycle.day
		for room in island.rooms:
			for old in room.get_children():
				if old is EventPickup:
					old.queue_free()
		for event in running:
			if event.pickup:
				scatter(island, event)
		forage(island)

func place_host(island : Island, event : GameEvent) -> void:
	var square : Node2D = null
	for room in island.rooms:
		if room.name == "Square":
			square = room
	if not square:
		return
	var npc : Npc = Npc.new()
	npc.id = event.host
	npc.greeting = event.startText
	npc.position = HOST_SPOT + Vector2(hosts.size() * 18.0, 0.0)
	var sprite : Sprite2D = Sprite2D.new()
	sprite.name = "Art"
	var path : String = "res://world/npcs/%s.png" % event.host
	sprite.texture = load(path) as Texture2D if ResourceLoader.exists(path) else event.icon
	npc.add_child(sprite)
	npc.art = sprite
	var stall : Shop = Shop.new()
	stall.title = event.shopTitle if not event.shopTitle.is_empty() else "%s Stall" % event.displayName
	stall.offers = event.shop
	stall.buyRate = 0.0
	stall.greeting = event.description
	stall.portrait = Cast.portrait(event.host)
	stall.listed = false
	npc.add_child(stall)
	npc.shop = stall
	npc.shopLabel = "Stall"
	square.add_child(npc)
	hosts.append(npc)

# The day's pickups: a few per screen, on land, the same spots all day.
func scatter(island : Island, event : GameEvent) -> void:
	for room in island.rooms:
		var random : RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash([cycle.day, event.key(), String(room.get_path())])
		for i in event.pickupsPerRoom:
			var key : String = "%s/%d/%s/%d" % [event.key(), cycle.day, room.get_path(), i]
			if player.progress.pickups.has(key):
				continue
			var spot : Vector2 = land_spot(room, random)
			if spot == Vector2.INF:
				continue
			var pickup : EventPickup = EventPickup.new()
			pickup.item = event.pickup
			pickup.art = event.pickupArt
			pickup.key = key
			pickup.position = spot
			room.add_child(pickup)

# The island's things to gather (its biome's forage list), a few per screen,
# new spots every day.
func forage(island : Island) -> void:
	var place : Location = player.atlas.current
	var biome : Biome = place.biome if place else null
	if not biome or biome.forage.is_empty():
		return
	for room in island.rooms:
		var random : RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = hash([cycle.day, "forage", String(room.get_path())])
		for i in biome.foragePerRoom:
			var key : String = "forage/%d/%s/%d" % [cycle.day, room.get_path(), i]
			var thing : Item = biome.forage[random.randi_range(0, biome.forage.size() - 1)]
			if player.progress.pickups.has(key) or not thing:
				continue
			var spot : Vector2 = land_spot(room, random)
			if spot == Vector2.INF:
				continue
			var node : ForageNode = ForageNode.new()
			node.item = thing
			node.key = key
			node.position = spot
			room.add_child(node)

# A random spot where the player can stand, or INF when none turns up.
func land_spot(room : IslandRoom, random : RandomNumberGenerator) -> Vector2:
	for attempt in 40:
		var local : Vector2 = Vector2(random.randf_range(12.0, 180.0), random.randf_range(20.0, 100.0)).round()
		if player.can_stand(room.global_position + local):
			return local
	return Vector2.INF

# Old pickup keys are dropped each new day, so the save stays small.
func tidy() -> void:
	var today : String = "/%d/" % cycle.day
	for key in player.progress.pickups.keys():
		if not String(key).contains(today):
			player.progress.pickups.erase(key)
