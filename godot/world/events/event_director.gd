extends Node
class_name EventDirector

# Runs the calendar's festivals and happenings (see GameEvent): announces them
# when they start and end, pays out their contests (see Contests), puts their
# host's stall in the village square and leaves the day's pickups beside a
# couple of forage spots on the island the player is on. The fishing side asks
# active() for what can bite and drop.

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
	cycle.day_changed.connect(func(day : int) -> void:
		spawnedDay = -1
		tidy()
		Bank.pay_interest(player, day)
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

# Whether someone is running a stall for an event on this island right now,
# so the everyday them stays out of sight.
static func hosting(tree : SceneTree, id : String) -> bool:
	var director : EventDirector = find(tree)
	if not director:
		return false
	for host in director.hosts:
		if is_instance_valid(host) and (host as Npc).id == id:
			return true
	return false

# The festivals running right now.
static func active(tree : SceneTree) -> Array[GameEvent]:
	var director : EventDirector = find(tree)
	return director.running if director else Calendar.active(tree)

func check() -> void:
	Achievements.check(player)
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
	if not started:
		Contests.finish(player, event, cycle.day)
	if not notices:
		return
	if started:
		notices.post("%s has begun!" % event.displayName, event.startText if not event.startText.is_empty() else event.description, event.color, event.icon)
	else:
		notices.post("%s is over" % event.displayName, event.endText if not event.endText.is_empty() else ("See you next year!" if event.is_festival() else "Until next time!"), event.color, event.icon)

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
	if event.specialCount > 0:
		stall.specials = event.shop
		stall.specialCount = event.specialCount
	else:
		stall.offers = event.shop
	stall.buyRate = 0.0
	stall.greeting = event.description
	if not event.contest.is_empty():
		npc.greeting = "Today's %s: %s!" % ["fish" if event.contest == &"derby" else "crop", Contests.featured_name(event, cycle.day)]
		stall.greeting = npc.greeting
	stall.portrait = Cast.portrait(event.host)
	stall.listed = false
	npc.add_child(stall)
	npc.shop = stall
	npc.shopLabel = "Stall"
	square.add_child(npc)
	hosts.append(npc)

# The day's pickups: two per island, each tucked beside one of its forage
# spots (or, on islands without any, near where the player lands), the same
# places all day. Nothing is strewn around the screens.
func scatter(island : Island, event : GameEvent) -> void:
	var spots : Array[Node] = island.find_children("*", "ForageSpot", true, false)
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([cycle.day, event.key(), String(island.scene_file_path)])
	var count : int = mini(maxi(event.pickupsPerRoom, 1), 2)
	for i in count:
		var key : String = "%s/%d/%s/%d" % [event.key(), cycle.day, island.scene_file_path, i]
		if player.progress.pickups.has(key):
			continue
		var room : IslandRoom = null
		var local : Vector2 = Vector2.INF
		if not spots.is_empty():
			var spot : ForageSpot = spots.pop_at(random.randi_range(0, spots.size() - 1))
			room = spot.get_parent() as IslandRoom
			for offset in [Vector2(14, 3), Vector2(-14, 3), Vector2(0, 10)]:
				if room and player.can_stand(spot.global_position + offset):
					local = spot.position + offset
					break
		if local == Vector2.INF:
			room = island.room_at(island.global_position + island.arrival)
			if room:
				local = land_spot(room, random)
		if not room or local == Vector2.INF:
			continue
		var pickup : EventPickup = EventPickup.new()
		pickup.item = event.pickup
		pickup.art = event.pickupArt
		pickup.key = key
		pickup.position = local
		room.add_child(pickup)

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
