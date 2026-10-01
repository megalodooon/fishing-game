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
#------------------------#


static func find(tree : SceneTree) -> NetSession:
	return tree.get_first_node_in_group(GROUP) as NetSession

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
	Net.on(&"pose", on_pose)
	Net.on(&"clock", on_clock)
	Net.on(&"world", on_world)
	Net.on(&"world_all", on_world_all)
	Net.on(&"scene", on_scene)
	Net.on(&"quest", on_quest)
	Net.on(&"say", on_say)
	Net.on(&"sleep", on_sleep)
	Net.on(&"night", on_night)
	Net.on(&"toast", on_toast)
	worldKnown = world_snapshot()
	Net.say_ready.call_deferred()

func _exit_tree() -> void:
	for kind : StringName in [&"pose", &"clock", &"world", &"world_all", &"scene", &"quest", &"say", &"sleep", &"night", &"toast"]:
		for handler : Callable in Net.handlers.get(kind, []).duplicate():
			if handler.get_object() == self:
				Net.off(kind, handler)

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
	update_remotes()

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
	}
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
		Net.send(&"world_all", encode_world(world_snapshot()), id)
		if cycle:
			Net.send(&"clock", {"day": cycle.day, "time": cycle.time, "force": true}, id)

func on_left(id : int, who : String) -> void:
	drop_remote(id)
	asleep.erase(id)
	if boardedOn == id:
		boardedOn = 0
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
