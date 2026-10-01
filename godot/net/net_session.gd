extends Node
class_name NetSession

# Keeps two games together while they're in the same world (see Net). Each
# game runs the place its own player is at; this sends where the player is
# and what they're doing 15 times a second, and draws the other player when
# they're in the same place (on the same boat out at sea, or as a sail on
# the horizon when they're on their own boat). It also keeps the shared world
# the same in both games (story, quests, village, farm, places, see
# SaveGame.WORLD_PROGRESS), runs the host's clock in both, lets the night
# happen only once everyone's in bed, plays story scenes for both, and pays
# the partner their share of a shared quest.

const GROUP : StringName = &"net_sessions"
const POSE_RATE : float = 1.0 / 15.0
const CLOCK_RATE : float = 1.0
const WORLD_RATE : float = 0.3
const DATA_RATE : float = 30.0
# Off by more than this many game hours, the guest's clock jumps to the host's.
const CLOCK_SLACK : float = 0.02
# A shared quest's coins are split between the players.
const QUEST_COIN_SHARE : float = 0.5
# Every message this listens to, each handled by on_<kind>.
const MESSAGES : Array[StringName] = [&"pose", &"clock", &"world", &"world_all", &"scene", &"quest", &"say", &"sleep", &"night", &"toast", &"board_ask", &"board_reply", &"boarded", &"carry", &"spot", &"fight", &"fight_join", &"fight_hit", &"fight_state", &"fight_end"]
# Seconds to jump into a friend's fight, and how much tougher a foe gets with two.
const FIGHT_INVITE : float = 6.0
const COOP_HEALTH : float = 1.6

#------------------------#
var player : Player
var world : World
var cycle : DayNightCycle
var remotes : Dictionary = {}
# What each other player last said about themselves, by peer id.
var states : Dictionary = {}
var poseTimer : float = 0.0
var clockTimer : float = 0.0
var worldTimer : float = 0.0
var dataTimer : float = DATA_RATE
var worldDirty : bool = false
# The shared world as last sent or received, per field and key, as text.
var worldKnown : Dictionary = {}
var applying : bool = false
# Who's in bed waiting for the night, by peer id (host counts everyone).
var asleep : Dictionary = {}
var nightReady : bool = false
# The peer whose boat this player rides, 0 for their own.
var boardedOn : int = 0
# Asked to board this peer's boat and waiting for the answer.
var boardAsked : int = 0
# They said yes, but they're somewhere else: board once there.
var boardOnArrival : int = 0
# Someone asking to board this player's boat, and how long the question stays.
var boardRequest : int = 0
var boardRequestTime : float = 0.0
# Co-op fights: the one this player started, the one they joined, and an
# offer to join a friend's.
var fight : Dictionary = {}
var helping : Dictionary = {}
var invite : Dictionary = {}
#------------------------#


static func find(tree : SceneTree) -> NetSession:
	return tree.get_first_node_in_group(GROUP) as NetSession

# Everyone who has ever played in this world (1 alone).
static func players_in_world(progress : Progress) -> int:
	return maxi(int(progress.get_flag("world/players", 1)), 1)

# Riding on another player's boat.
static func riding(tree : SceneTree) -> bool:
	var session : NetSession = find(tree)
	return session != null and session.boardedOn > 0

func setup(into : World) -> void:
	world = into
	player = into.player

func _ready() -> void:
	add_to_group(GROUP)
	process_mode = PROCESS_MODE_ALWAYS
	cycle = DayNightCycle.find(get_tree())
	player.progress.changed.connect(mark_world)
	player.atlas.changed.connect(mark_world)
	player.progress.quest_taken.connect(func(quest : Quest) -> void: send_quest(quest, false))
	player.progress.quest_handed_in.connect(func(quest : Quest) -> void: send_quest(quest, true))
	player.fish_caught.connect(on_caught)
	Net.peer_joined.connect(on_joined)
	Net.peer_left.connect(on_left)
	for kind in MESSAGES:
		Net.on(kind, Callable(self, "on_" + kind))
	worldKnown = world_snapshot()
	if Net.is_guest():
		player.sprite.self_modulate = RemotePlayer.GUEST_TINT
		player.hand.self_modulate = RemotePlayer.GUEST_TINT
	Net.say_ready.call_deferred()

func _exit_tree() -> void:
	for kind in MESSAGES:
		Net.off(kind, Callable(self, "on_" + kind))

func online() -> bool:
	return Net.has_company()

func _process(delta : float) -> void:
	# The clock gets ready after the world does.
	if not cycle:
		cycle = DayNightCycle.find(get_tree())
	if not Net.is_online():
		if not remotes.is_empty():
			for id in remotes.keys():
				drop_remote(id)
		return
	poseTimer -= delta
	if poseTimer <= 0.0:
		poseTimer = POSE_RATE
		Net.send_fast(&"pose", capture_pose())
	if Net.is_host():
		clockTimer -= delta
		if clockTimer <= 0.0 and cycle:
			clockTimer = CLOCK_RATE
			Net.send_fast(&"clock", {"day": cycle.day, "time": cycle.time})
	else:
		dataTimer -= delta
		if dataTimer <= 0.0:
			dataTimer = DATA_RATE
			Net.send_player_data()
	worldTimer -= delta
	if worldDirty and worldTimer <= 0.0:
		worldTimer = WORLD_RATE
		worldDirty = false
		send_world()
	if boardRequest > 0:
		boardRequestTime -= delta
		if boardRequestTime <= 0.0:
			answer_board(false)
	if boardedOn > 0 and not Net.names.has(boardedOn):
		unboard()
	steer_boat(delta)
	update_fight(delta)
	if not invite.is_empty():
		invite.time -= delta
		if invite.time <= 0.0:
			invite = {}
	update_remotes()

func _unhandled_key_input(event : InputEvent) -> void:
	var key : InputEventKey = event as InputEventKey
	if not invite.is_empty() and key and key.pressed and not key.echo and key.keycode == KEY_J:
		join_fight()
		get_viewport().set_input_as_handled()
		return
	if boardRequest > 0 and key and key.pressed and not key.echo and key.keycode in [KEY_Y, KEY_N]:
		answer_board(key.keycode == KEY_Y)
		get_viewport().set_input_as_handled()

#------------------------# Where everyone is

# The place this player is at, as the scene that's loaded (an ocean, an
# island or a room inside a building).
func place_key() -> String:
	return world.place.scene_file_path if world and world.place else ""

func at_sea() -> bool:
	return world and world.place is Ocean

func capture_pose() -> Dictionary:
	var held : Item = player.held_data()
	var data : Dictionary = {
		"at": place_key(),
		"p": player.global_position,
		"br": player.body.rotation,
		"sp": player.sprite.position,
		"ss": player.sprite.scale,
		"fr": player.sprite.frame,
		"hp": player.hand.position,
		"hr": player.hand.rotation,
		"hs": player.hand.scale,
		"ip": player.itemHolder.position,
		"ir": player.itemHolder.rotation,
		"is": player.itemHolder.scale,
		"item": held.original().resource_path if held else "",
		"board": boardedOn,
		"speed": world.boat.speed if world and world.boat else 0.0,
		"asleep": player.asleep,
		"loc": player.atlas.current.resource_path if player.atlas.current else "",
	}
	var map : WorldMapUI = WorldMapUI.find(get_tree())
	if map and not map.trip.is_empty():
		data["trip"] = [player.atlas.current.resource_path if player.atlas.current else "", (map.trip.to as Location).resource_path, map.trip_fraction()]
	var rod : FishingRod = player.heldItem as FishingRod
	if rod and rod.mode != FishingRod.Mode.HOLD and not rod.points.is_empty():
		data["tip"] = rod.to_global(rod.tip_local())
		data["bob"] = rod.project(rod.points[rod.points.size() - 1])
	return data

func on_pose(from : int, data : Variant) -> void:
	if not data is Dictionary:
		return
	states[from] = data
	var remote : RemotePlayer = remote_for(from)
	if remote:
		remote.receive(data)

func remote_for(id : int) -> RemotePlayer:
	if remotes.has(id):
		return remotes[id]
	if not Net.names.has(id):
		return null
	var remote : RemotePlayer = RemotePlayer.new()
	remote.setup(player, id, Net.name_of(id))
	player.get_parent().add_child(remote)
	remotes[id] = remote
	return remote

func drop_remote(id : int) -> void:
	if remotes.has(id):
		(remotes[id] as Node).queue_free()
		remotes.erase(id)
	states.erase(id)

# The boat a player stands on: their own, or the one they boarded.
func boat_of(id : int, state : Dictionary) -> int:
	return state.get("board", 0) if state.get("board", 0) > 0 else id

func same_boat(id : int) -> bool:
	return boat_of(id, states.get(id, {})) == (boardedOn if boardedOn > 0 else Net.my_id())

# Shown in full when in the same place (and out at sea, on the same boat), as
# a sail on the horizon when out at sea on their own boat.
func update_remotes() -> void:
	for id in remotes:
		var remote : RemotePlayer = remotes[id]
		var state : Dictionary = states.get(id, {})
		var here : bool = not state.is_empty() and state.get("at", "") == place_key()
		remote.far = here and at_sea() and not same_boat(id)
		remote.visible = here

# Everyone in the same place as this player, by peer id.
func nearby() -> Array:
	var list : Array = []
	for id in states:
		if states[id].get("at", "") == place_key():
			list.append(id)
	return list

func who_is_at(key : String) -> Array:
	var list : Array = []
	for id in states:
		if states[id].get("at", "") == key:
			list.append(id)
	return list

#------------------------# Joining and leaving

func on_joined(id : int, who : String) -> void:
	remote_for(id)
	toast("%s joined" % who, "Say hi! Open the sea chart (M) to see where they are.", Color(0.56, 0.93, 0.44))
	if Net.is_host():
		# How many people play in this world, for costs that scale with it.
		var count : int = 1 + Net.guestData.size() + (0 if Net.guestData.has(who) else 1)
		if count > players_in_world(player.progress):
			player.progress.set_flag("world/players", count)
		Net.send(&"world_all", encode_world(world_snapshot()), id)
		if cycle:
			Net.send(&"clock", {"day": cycle.day, "time": cycle.time, "force": true}, id)

func on_left(id : int, who : String) -> void:
	drop_remote(id)
	asleep.erase(id)
	if boardedOn == id:
		unboard(true)
	toast("%s left" % who, "Their progress is kept in this world's save.", Color(0.98, 0.85, 0.4))
	if Net.is_host():
		check_night()

#------------------------# The clock

func on_clock(from : int, data : Variant) -> void:
	if Net.is_host() or not cycle or from != 1 or not data is Dictionary:
		return
	var hostTime : float = data.get("day", cycle.day) * 24.0 + data.get("time", cycle.time)
	var mine : float = cycle.day * 24.0 + cycle.time
	if data.get("force", false) or absf(hostTime - mine) > CLOCK_SLACK:
		cycle.set_day(data.get("day", cycle.day))
		cycle.set_time(data.get("time", cycle.time))

#------------------------# The shared world

func mark_world() -> void:
	if not applying:
		worldDirty = true

# The shared world as text per field and key, so changes can be found and
# only those sent.
func world_snapshot() -> Dictionary:
	var snap : Dictionary = {}
	for field in SaveGame.WORLD_PROGRESS:
		var value : Variant = player.progress.get(field)
		var part : Dictionary = {}
		if value is Dictionary:
			for key in value:
				part[var_to_str(SaveGame.encode(key))] = var_to_str(SaveGame.encode(value[key]))
		else:
			part[""] = var_to_str(SaveGame.encode(value))
		snap[field] = part
	var flags : Dictionary = {}
	for key in player.progress.flags:
		if SaveGame.is_world_flag(key):
			flags[var_to_str(key)] = var_to_str(SaveGame.encode(player.progress.flags[key]))
	snap["flags"] = flags
	snap["unlocked"] = {"": var_to_str(SaveGame.encode(player.atlas.unlocked))}
	return snap

func encode_world(snap : Dictionary) -> Dictionary:
	var changes : Dictionary = {}
	for field in snap:
		changes[field] = {"set": snap[field], "del": []}
	return changes

func send_world() -> void:
	var snap : Dictionary = world_snapshot()
	var changes : Dictionary = {}
	for field in snap:
		var known : Dictionary = worldKnown.get(field, {})
		var now : Dictionary = snap[field]
		var set : Dictionary = {}
		var gone : Array = []
		for key in now:
			if known.get(key) != now[key]:
				set[key] = now[key]
		for key in known:
			if not now.has(key):
				gone.append(key)
		if not set.is_empty() or not gone.is_empty():
			changes[field] = {"set": set, "del": gone}
	worldKnown = snap
	if not changes.is_empty():
		Net.send(&"world", changes)

func on_world_all(from : int, data : Variant) -> void:
	on_world(from, data, true)

func on_world(_from : int, data : Variant, everything : bool = false) -> void:
	if not data is Dictionary:
		return
	applying = true
	var chapterBefore : int = player.progress.chapter
	for field in data:
		var change : Dictionary = data[field]
		var known : Dictionary = worldKnown.get(field, {})
		if everything:
			known = {}
			if field == "flags":
				for key in player.progress.flags.keys():
					if SaveGame.is_world_flag(key):
						player.progress.flags.erase(key)
		for key in change.get("set", {}):
			known[key] = change.set[key]
			apply_key(field, key, SaveGame.decode(str_to_var(change.set[key])), false)
		for key in change.get("del", []):
			known.erase(key)
			apply_key(field, key, null, true)
		worldKnown[field] = known
	applying = false
	player.atlas.emit_changed()
	player.progress.emit_changed()
	if player.progress.chapter > chapterBefore:
		var story : StoryDirector = StoryDirector.find(get_tree())
		if story:
			story.check_chapter()

func apply_key(field : String, key : String, value : Variant, erase : bool) -> void:
	if field == "unlocked":
		SaveGame.put(player.atlas, "unlocked", value if value is Array else [])
		return
	if field == "flags":
		var flag : String = str_to_var(key)
		if erase:
			player.progress.flags.erase(flag)
		else:
			player.progress.flags[flag] = value
		return
	var current : Variant = player.progress.get(field)
	if current is Dictionary:
		var decodedKey : Variant = SaveGame.decode(str_to_var(key))
		if decodedKey == null:
			return
		if erase:
			(current as Dictionary).erase(decodedKey)
		else:
			(current as Dictionary)[decodedKey] = value
	elif not erase:
		SaveGame.put(player.progress, field, value)

#------------------------# Story and quests

# A story scene this player just started; the other player sees it too when
# they're in the same place, and is told about it otherwise.
func share_scene(id : String, title : String = "") -> void:
	if online() and not applying:
		Net.send(&"scene", {"id": id, "at": place_key(), "title": title})

func on_scene(from : int, data : Variant) -> void:
	var story : StoryDirector = StoryDirector.find(get_tree())
	if not story or not data is Dictionary:
		return
	var id : String = data.get("id", "")
	if data.get("at", "") == place_key():
		story.play(id, Callable(), true)
	else:
		story.remember(id)
		toast("Story", "%s saw a scene%s. Watch it in the quest log." % [Net.name_of(from), "" if str(data.get("title", "")).is_empty() else ": " + data.title], Color(0.55, 0.78, 1.0))

func send_quest(quest : Quest, finished : bool) -> void:
	if online() and not applying:
		Net.send(&"quest", {"quest": SaveGame.encode(quest), "done": finished})

func on_quest(from : int, data : Variant) -> void:
	var quest : Quest = SaveGame.decode(data.get("quest")) as Quest if data is Dictionary else null
	if not quest:
		return
	if not data.get("done", false):
		toast("New quest", "%s took \"%s\"." % [Net.name_of(from), quest.title], Color(0.55, 0.78, 1.0))
		return
	# The partner's share: the same items, half the coins (the other half went
	# to whoever handed it in).
	for i in quest.rewardItems.size():
		if quest.rewardItems[i]:
			var amount : int = quest.rewardAmounts[i] if i < quest.rewardAmounts.size() else 1
			if not Counter.deliver(player, quest.rewardItems[i], amount):
				player.inventory.give(quest.rewardItems[i], amount)
	var coins : int = Quest.shared_coins(quest.rewardCoins)
	if coins > 0:
		player.wallet.add(coins)
	toast("Quest done!", "%s handed in \"%s\"%s." % [Net.name_of(from), quest.title, " (+$%d for you)" % coins if coins > 0 else ""], Color(0.56, 0.93, 0.44))

#------------------------# Little things

func on_caught(fish : Fish, _biome : Biome) -> void:
	if online() and fish and fish.species:
		Net.send(&"say", {"text": fish.species.displayName + "!", "color": fish.species.rarity.color if fish.species.rarity else Color.WHITE})

func on_say(from : int, data : Variant) -> void:
	if remotes.has(from) and data is Dictionary:
		(remotes[from] as RemotePlayer).say(str(data.get("text", "")), data.get("color", Color.WHITE))

# Tells the other player something (like a rare catch) as a notice.
func tell(title : String, text : String, color : Color) -> void:
	if online():
		Net.send(&"toast", {"title": title, "text": text, "color": color})

func on_toast(_from : int, data : Variant) -> void:
	if data is Dictionary:
		toast(str(data.get("title", "")), str(data.get("text", "")), data.get("color", Color.WHITE))

func toast(title : String, text : String, color : Color) -> void:
	var board : NoticeBoard = NoticeBoard.find(get_tree())
	if board:
		board.post(title, text, color)

#------------------------# Boarding

# Asking to ride along on another player's boat. They get a prompt; once
# they say yes, this player sails to them if needed and steps aboard. While
# aboard, the owner steers: the boat here moves at their speed, their
# fishing spots come over, and when they sail somewhere this player is
# carried along (until they dock at an island).

func ask_to_board(id : int) -> void:
	boardAsked = id
	Net.send(&"board_ask", null, id)
	toast("Asked to board", "Waiting for %s to say yes..." % Net.name_of(id), Color(0.55, 0.78, 1.0))

func on_board_ask(from : int, _data : Variant) -> void:
	if not at_sea() or boardedOn > 0:
		Net.send(&"board_reply", {"ok": false, "why": "%s isn't out at sea on their own boat." % Net.myName}, from)
		return
	boardRequest = from
	boardRequestTime = 15.0
	toast("%s wants to come aboard" % Net.name_of(from), "Press Y to let them on, N to say no.", Color(0.55, 0.78, 1.0))

func answer_board(yes : bool) -> void:
	if boardRequest <= 0:
		return
	Net.send(&"board_reply", {"ok": yes and at_sea(), "location": SaveGame.encode(player.atlas.current), "at": place_key(), "why": "%s said no." % Net.myName}, boardRequest)
	boardRequest = 0

func on_board_reply(from : int, data : Variant) -> void:
	if boardAsked != from or not data is Dictionary:
		return
	boardAsked = 0
	if not data.get("ok", false):
		toast("Can't board", str(data.get("why", "")), Color(0.98, 0.85, 0.4))
		return
	var location : Location = SaveGame.decode(data.get("location")) as Location
	if location and location != player.atlas.current:
		# Sail over first; boarding happens on arrival.
		boardOnArrival = from
		var map : WorldMapUI = WorldMapUI.find(get_tree())
		if map:
			map.sail_to(location)
		return
	board(from)

func board(owner : int) -> void:
	boardedOn = owner
	boardOnArrival = 0
	world.spawner.clear_spots()
	player.global_position = world.boat.global_position + world.boardOffset + Vector2(16.0, 7.0)
	Net.send(&"boarded", true, owner)
	toast("Aboard!", "You're on %s's boat. They steer; open the sea chart to leave." % Net.name_of(owner), Color(0.56, 0.93, 0.44))

func unboard(quiet : bool = false) -> void:
	if boardedOn <= 0:
		return
	var owner : int = boardedOn
	boardedOn = 0
	world.spawner.clear_spots()
	if Net.names.has(owner):
		Net.send(&"boarded", false, owner)
	if not quiet:
		toast("Back on your own boat", "", Color(0.55, 0.78, 1.0))

func on_boarded(from : int, data : Variant) -> void:
	toast("%s %s your boat" % [Net.name_of(from), "came aboard" if data else "left"], "", Color(0.55, 0.78, 1.0))

# The owner sailed somewhere: riders come along.
func on_carry(from : int, data : Variant) -> void:
	if boardedOn != from:
		return
	var location : Location = SaveGame.decode(data) as Location
	if not location:
		unboard()
		return
	world.arrive(location)
	if location.is_island():
		unboard(true)

func riders() -> Array:
	var list : Array = []
	for id in states:
		if states[id].get("board", 0) == Net.my_id():
			list.append(id)
	return list

# Called when this player arrives somewhere: riders come along, a pending
# boarding happens.
func arrived(location : Location) -> void:
	if not online():
		return
	if boardOnArrival > 0 and not location.is_island():
		board(boardOnArrival)
	for id in riders():
		Net.send(&"carry", SaveGame.encode(location), id)

# The boat here follows its owner's speed.
func steer_boat(delta : float) -> void:
	if boardedOn <= 0 or not world or not world.boat:
		return
	var owner : Dictionary = states.get(boardedOn, {})
	if owner.is_empty() or owner.get("at", "") != place_key():
		return
	world.boat.speed = lerpf(world.boat.speed, owner.get("speed", 0.0), 1.0 - exp(-6.0 * delta))
	world.boat.targetSpeed = world.boat.speed

#------------------------# Fishing spots

# Who makes the fishing spots: out at sea each boat's owner, on an island
# whoever has the lowest id there (the host when they're around).
func spawns_spots() -> bool:
	if not online():
		return true
	if boardedOn > 0:
		return false
	if at_sea():
		return true
	for id in nearby():
		if id < Net.my_id():
			return false
	return true

func share_spot(spot : FishingSpot) -> void:
	if not online():
		return
	var to : Array = riders() if at_sea() else nearby()
	for id in to:
		Net.send(&"spot", {"at": place_key(), "p": spot.global_position, "life": spot.life, "biome": SaveGame.encode(spot.biome)}, id)

func on_spot(from : int, data : Variant) -> void:
	if not data is Dictionary or data.get("at", "") != place_key():
		return
	if at_sea() and boardedOn != from:
		return
	world.spawner.add_shared(data.p, data.get("life", 20.0), SaveGame.decode(data.get("biome")) as Biome)

#------------------------# Co-op fights

# A creature fight this player started tells the players beside them (on
# the same boat, or on the same island). They have a few seconds to press J
# and jump in: each fights in their own copy, hits from both wear down the
# one foe (which gets tougher with two), and both get the loot.

func fight_partners() -> Array:
	var list : Array = []
	for id in nearby():
		if not at_sea() or same_boat(id):
			list.append(id)
	return list

func fight_started(creature : SeaCreature, game : BossMinigame) -> void:
	var path : Variant = SaveGame.encode(creature)
	if not online() or path == null:
		return
	var partners : Array = fight_partners()
	if partners.is_empty():
		return
	fight = {"id": randi(), "game": game, "helpers": [], "timer": 0.0}
	game.finished.connect(func(won : bool) -> void: fight_over(won))
	for id in partners:
		Net.send(&"fight", {"id": fight.id, "creature": path}, id)

func on_fight(from : int, data : Variant) -> void:
	var creature : SeaCreature = SaveGame.decode(data.get("creature")) as SeaCreature if data is Dictionary else null
	if not creature:
		return
	invite = {"from": from, "id": data.id, "creature": creature, "time": FIGHT_INVITE}
	toast("%s hooked a %s!" % [Net.name_of(from), creature.displayName], "Press J to jump in and help.", creature.rarity.color if creature.rarity else Color(1.0, 0.45, 0.4))

# Joins the fight this player was asked to, in their own copy of it.
func join_fight() -> void:
	if invite.is_empty() or not helping.is_empty():
		return
	if player.asleep or player.charting or not player.handStates.currentState is PlayerHandIdleState or player.minigameScreen.shown:
		toast("Can't help right now", "Put the rod away from the water first.", Color(0.98, 0.85, 0.4))
		return
	var creature : SeaCreature = invite.creature
	var scene : PackedScene = creature.fight if creature.fight else load("res://fishing/minigames/boss_duel/boss_duel.tscn")
	var game : BossMinigame = scene.instantiate()
	game.hearts = roundi(player.stat(&"hearts"))
	game.power = 1.0 + player.stat(&"damage") * 0.01
	game.style = creature.style
	game.toughness = creature.toughness
	helping = {"owner": invite.from, "id": invite.id, "game": game, "creature": creature, "ended": false}
	invite = {}
	game.dealt.connect(func(amount : float) -> void: Net.send(&"fight_hit", {"id": helping.get("id", 0), "amount": amount}, helping.get("owner", 0)))
	game.finished.connect(on_helper_finished)
	player.frozen = true
	player.minigameScreen.caption = "Helping %s" % Net.name_of(helping.owner)
	player.minigameScreen.play(game)
	game.begin(creature.difficulty, 0.5, creature.rarity.color if creature.rarity else Color(1.0, 0.45, 0.4), creature.icon)
	Net.send(&"fight_join", {"id": helping.id}, helping.owner)

func on_fight_join(from : int, data : Variant) -> void:
	if fight.is_empty() or data.get("id") != fight.id or not is_instance_valid(fight.game):
		Net.send(&"fight_end", {"id": data.get("id"), "won": false}, from)
		return
	fight.helpers.append(from)
	(fight.game as BossMinigame).grow_health(COOP_HEALTH)
	toast("%s jumped in!" % Net.name_of(from), "", Color(0.56, 0.93, 0.44))

func on_fight_hit(from : int, data : Variant) -> void:
	if not fight.is_empty() and data.get("id") == fight.id and fight.helpers.has(from) and is_instance_valid(fight.game):
		(fight.game as BossMinigame).take_damage(float(data.get("amount", 0.0)))

# The owner keeps the helpers' health bars in step.
func update_fight(delta : float) -> void:
	if fight.is_empty() or fight.helpers.is_empty() or not is_instance_valid(fight.game):
		return
	fight.timer -= delta
	if fight.timer <= 0.0:
		fight.timer = 0.2
		for id in fight.helpers:
			Net.send_fast(&"fight_state", {"id": fight.id, "left": (fight.game as BossMinigame).health_left()}, id)

func on_fight_state(_from : int, data : Variant) -> void:
	if not helping.is_empty() and data.get("id") == helping.id and is_instance_valid(helping.game):
		(helping.game as BossMinigame).set_health_left(float(data.get("left", 1.0)))

func fight_over(won : bool) -> void:
	if fight.is_empty():
		return
	for id in fight.helpers:
		Net.send(&"fight_end", {"id": fight.id, "won": won}, id)
	fight = {}

func on_fight_end(_from : int, data : Variant) -> void:
	if helping.is_empty() or data.get("id") != helping.id:
		return
	helping.ended = true
	helping.won = data.get("won", false)
	if is_instance_valid(helping.game) and not (helping.game as BossMinigame).done:
		(helping.game as BossMinigame).finish(helping.won)

func on_helper_finished(won : bool) -> void:
	var creature : SeaCreature = helping.get("creature")
	var shared : bool = helping.get("ended", false) and helping.get("won", false)
	# Beating it in this copy first means the owner's copy is beaten too a
	# moment later; the loot comes either way.
	if won or shared:
		PlayerCatchState.pay_out(player, creature)
		player.say("Beat the %s!" % creature.displayName, creature.rarity.color if creature.rarity else Color(1.0, 0.45, 0.4))
	elif not helping.get("ended", false):
		player.say("Knocked out of the fight", Color(0.82, 0.86, 0.92))
	helping = {}
	player.frozen = false
	player.minigameScreen.caption = ""
	player.minigameScreen.close_menu()

#------------------------# Sleeping

# The night only comes once everyone's in bed. Each game tells the others
# when its player lies down or gets up; the host starts the night for all.
func lie_down(value : bool) -> void:
	if not online():
		return
	nightReady = false
	if value:
		# The host saves at night, with the guest's latest.
		Net.send_player_data()
		asleep[Net.my_id()] = true
	else:
		asleep.erase(Net.my_id())
	Net.send(&"sleep", value)
	if Net.is_host():
		check_night()

func on_sleep(from : int, data : Variant) -> void:
	if data:
		asleep[from] = true
	else:
		asleep.erase(from)
	if Net.is_host():
		check_night()

func check_night() -> void:
	if not Net.is_host() or not asleep.has(Net.my_id()):
		return
	for id in Net.others():
		if not asleep.has(id):
			return
	asleep.clear()
	Net.send(&"night")
	nightReady = true

func on_night(_from : int, _data : Variant) -> void:
	asleep.clear()
	nightReady = true

# Who the sleeper is still waiting for, or empty when the night can come.
func waiting_for() -> String:
	if not online() or nightReady:
		return ""
	var names : PackedStringArray = PackedStringArray()
	for id in Net.others():
		if not states.get(id, {}).get("asleep", false):
			names.append(Net.name_of(id))
	return ", ".join(names) if not names.is_empty() else "everyone"
