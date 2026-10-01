extends RefCounted
class_name SaveGame

# Saving and loading. Three slots in user://, each a text file of plain values:
# resources the game ships with are stored by their path, fish and item stacks
# by what they're made of.
#
# A save is one world and the players in it. The world is what everyone in a
# multiplayer game shares (the story, quests, the village, the farm, unlocked
# places, the clock); each player keeps their own bag, coins, skills and so on
# under their name. The host's save holds every player who ever joined, so a
# friend picks up where they left off by joining with the same name. Every
# script variable of Progress is saved, so new progress fields are picked up
# without touching this file; they belong to the player unless listed in
# WORLD_PROGRESS.

const SLOTS : int = 3
const VERSION : int = 2
const RES : String = "@res:"
# The resources on the player and which of their properties are the save.
# Progress saves all of its properties.
const STATE : Dictionary = {
	"inventory": ["backpackSize", "items"],
	"tacklebox": ["owned"],
	"journal": ["caught", "heaviest", "discovered"],
	"energy": ["maximum", "value"],
	"wallet": ["coins"],
	"atlas": ["current", "previous"],
}
# Progress fields the whole world shares.
const WORLD_PROGRESS : PackedStringArray = ["donations", "farms", "quests", "chapter", "traps", "pickups"]
# Progress flags the whole world shares, by how their names start.
const WORLD_FLAGS : PackedStringArray = ["quest/", "story/", "project/", "forage/", "museum/", "vote/", "weather_order", "world/"]

# The slot the running game saves to.
static var slot : int = 0
# Filled by the title screen (or by joining a friend): the save to load when
# the game starts, or empty for a new game. "you" names the player to load
# when it isn't the save's owner.
static var pending : Dictionary = {}
# The name for a new game's player, picked on the title screen.
static var newName : String = ""
# Where the slots are kept (tests use their own folder).
static var folder : String = "user://"


static func path(which : int) -> String:
	return folder.path_join("save_%d.sav" % which)

static func exists(which : int) -> bool:
	return FileAccess.file_exists(path(which))

static func erase(which : int) -> void:
	if exists(which):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(which)))

static func read(which : int) -> Dictionary:
	if not exists(which):
		return {}
	var file : FileAccess = FileAccess.open(path(which), FileAccess.READ)
	if not file:
		return {}
	var data : Variant = str_to_var(file.get_as_text())
	return data if data is Dictionary else {}

# Saves from before the current format can't be loaded any more.
static func outdated(data : Dictionary) -> bool:
	return not data.is_empty() and int(data.get("version", 1)) != VERSION

# What the title screen shows for a slot, without loading any resources.
static func summary(which : int) -> Dictionary:
	var data : Dictionary = read(which)
	if data.is_empty():
		return {}
	var info : Dictionary = (data.get("summary", {}) as Dictionary).duplicate()
	info["outdated"] = outdated(data)
	return info

# The slot saved last that can still be loaded, or -1 when there are none.
static func latest() -> int:
	var best : int = -1
	var when : float = -1.0
	for i in SLOTS:
		var info : Dictionary = summary(i)
		if not info.is_empty() and not info.outdated and float(info.get("saved", 0.0)) > when:
			when = info.get("saved", 0.0)
			best = i
	return best

static func is_world_flag(key : String) -> bool:
	for prefix in WORLD_FLAGS:
		if key.begins_with(prefix):
			return true
	return false

# Everything that belongs to this player alone.
static func player_data(player : Player) -> Dictionary:
	var data : Dictionary = {}
	for key in STATE:
		var owner : Resource = player.get(key)
		var part : Dictionary = {}
		for property in STATE[key]:
			part[property] = encode(owner.get(property))
		data[key] = part
	var progress : Dictionary = {}
	for property in state_properties(player.progress):
		if property == "flags":
			progress[property] = encode(flags_of(player.progress, false))
		elif not WORLD_PROGRESS.has(property):
			progress[property] = encode(player.progress.get(property))
	data["progress"] = progress
	return data

# Everything the world shares, as this player sees it.
static func world_data(player : Player) -> Dictionary:
	var progress : Dictionary = {"flags": encode(flags_of(player.progress, true))}
	for property in WORLD_PROGRESS:
		progress[property] = encode(player.progress.get(property))
	var data : Dictionary = {"progress": progress, "unlocked": encode(player.atlas.unlocked)}
	var cycle : DayNightCycle = DayNightCycle.find(player.get_tree())
	if cycle:
		data["clock"] = {"day": cycle.day, "time": cycle.time}
	return data

static func flags_of(progress : Progress, world : bool) -> Dictionary:
	var out : Dictionary = {}
	for key in progress.flags:
		if is_world_flag(key) == world:
			out[key] = progress.flags[key]
	return out

static func apply_player(player : Player, data : Dictionary) -> void:
	for key in STATE:
		var owner : Resource = player.get(key)
		var part : Dictionary = data.get(key, {})
		for property in part:
			put(owner, property, decode(part[property]))
	var progress : Dictionary = data.get("progress", {})
	var known : PackedStringArray = state_properties(player.progress)
	for property in progress:
		if property == "flags":
			replace_flags(player.progress, decode(progress[property]), false)
		elif known.has(property) and not WORLD_PROGRESS.has(property):
			put(player.progress, property, decode(progress[property]))
	player.inventory.setup()
	for key in STATE:
		(player.get(key) as Resource).emit_changed()
	player.progress.emit_changed()

static func apply_world(player : Player, data : Dictionary) -> void:
	var progress : Dictionary = data.get("progress", {})
	for property in progress:
		if property == "flags":
			replace_flags(player.progress, decode(progress[property]), true)
		elif WORLD_PROGRESS.has(property):
			put(player.progress, property, decode(progress[property]))
	if data.has("unlocked"):
		put(player.atlas, "unlocked", decode(data["unlocked"]))
		player.atlas.setup()
	var cycle : DayNightCycle = DayNightCycle.find(player.get_tree())
	var clock : Dictionary = data.get("clock", {})
	if cycle and not clock.is_empty():
		cycle.set_day(clock.day)
		cycle.set_time(clock.time)
	player.atlas.emit_changed()
	player.progress.emit_changed()

# Swaps the world's (or the player's) flags for these, keeping the others.
static func replace_flags(progress : Progress, incoming : Dictionary, world : bool) -> void:
	for key in progress.flags.keys():
		if is_world_flag(key) == world:
			progress.flags.erase(key)
	for key in incoming:
		if is_world_flag(key) == world:
			progress.flags[key] = incoming[key]

static func save_game(tree : SceneTree) -> bool:
	var player : Player = Player.find(tree)
	var cycle : DayNightCycle = DayNightCycle.find(tree)
	if not player:
		return false
	# A guest's game is kept in the host's save.
	if Net.is_guest():
		Net.send_player_data()
		return true
	var data : Dictionary = read(slot)
	var players : Dictionary = {} if outdated(data) else data.get("players", {})
	var me : String = player.progress.playerName
	players[me] = player_data(player)
	for name in Net.guestData:
		players[name] = Net.guestData[name]
	data = {
		"version": VERSION,
		"owner": me,
		"world": world_data(player),
		"players": players,
		"summary": {
			"saved": Time.get_unix_time_from_system(),
			"name": me,
			"players": players.keys(),
			"day": cycle.day if cycle else 1,
			"weekday": cycle.weekday_name(true) if cycle else "",
			"coins": player.wallet.coins,
			"place": player.atlas.current.displayName if player.atlas.current else "",
			"playtime": player.progress.playtime,
			"chapter": player.progress.chapter_title(),
			"completion": Collections.completion(player),
		},
	}
	var file : FileAccess = FileAccess.open(path(slot), FileAccess.WRITE)
	if not file:
		return false
	file.store_string(var_to_str(data))
	return true

# Puts a save into the running game. Called once everything is ready.
static func load_into(tree : SceneTree, data : Dictionary) -> void:
	var player : Player = Player.find(tree)
	if not player or data.is_empty() or outdated(data):
		return
	var you : String = data.get("you", data.get("owner", ""))
	var players : Dictionary = data.get("players", {})
	var mine : Dictionary = players.get(you, {})
	# The friends who played in this world, kept for when they join again.
	if not Net.is_guest():
		Net.guestData = players.duplicate()
		Net.guestData.erase(you)
	if not mine.is_empty():
		apply_player(player, mine)
	if not you.is_empty():
		player.progress.playerName = you
	apply_world(player, data.get("world", {}))

static func state_properties(resource : Resource) -> PackedStringArray:
	var list : PackedStringArray = PackedStringArray()
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			list.append(property.name)
	return list

# Typed arrays and dictionaries are filled in place so they keep their types.
static func put(owner : Object, property : String, value : Variant) -> void:
	var current : Variant = owner.get(property)
	if current is Array and value is Array:
		(current as Array).clear()
		(current as Array).assign(value)
	elif current is Dictionary and value is Dictionary:
		(current as Dictionary).clear()
		(current as Dictionary).assign(value)
	else:
		owner.set(property, value)

static func encode(value : Variant) -> Variant:
	if value is Fish:
		var fish : Fish = value
		return {"@fish": fish.species.resource_path, "weight": fish.weight, "variant": fish.variant}
	if value is RodItem and (value as RodItem).original().resource_path.begins_with("res://") and value != (value as RodItem).original():
		var rod : RodItem = value
		return {"@rod": rod.original().resource_path, "tackle": encode(rod.tackle), "reforge": encode(rod.reforge), "enchants": rod.enchants.duplicate()}
	if value is Item and (value as Item).base != null:
		return {"@item": (value as Item).original().resource_path, "amount": (value as Item).amount}
	if value is Resource:
		var resource : Resource = value
		if resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::"):
			return RES + resource.resource_path
		return null
	if value is Dictionary:
		var out : Dictionary = {}
		for key in value:
			out[encode(key)] = encode(value[key])
		return out
	if value is Array:
		var list : Array = []
		for each in value:
			list.append(encode(each))
		return list
	return value

static func decode(value : Variant) -> Variant:
	if value is String and (value as String).begins_with(RES):
		var file : String = (value as String).substr(RES.length())
		return load(file) if ResourceLoader.exists(file) else null
	if value is Dictionary:
		var dict : Dictionary = value
		if dict.has("@fish"):
			var species : FishData = load(dict["@fish"]) if ResourceLoader.exists(dict["@fish"]) else null
			return Fish.restore(species, dict.get("weight", 1.0), dict.get("variant", 0)) if species else null
		if dict.has("@rod"):
			var base : RodItem = load(dict["@rod"]) if ResourceLoader.exists(dict["@rod"]) else null
			if not base:
				return null
			var rod : RodItem = base.unique() as RodItem
			var parts : Array = decode(dict.get("tackle", []))
			for i in mini(parts.size(), rod.tackle.size()):
				rod.tackle[i] = parts[i] as Tackle
			var reforged : Reforge = decode(dict.get("reforge")) as Reforge
			if reforged:
				rod.apply_reforge(reforged)
			rod.enchants = (dict.get("enchants", {}) as Dictionary).duplicate()
			return rod
		if dict.has("@item"):
			var kind : Item = load(dict["@item"]) if ResourceLoader.exists(dict["@item"]) else null
			if not kind:
				return null
			var stack : Item = kind.unique()
			stack.amount = dict.get("amount", 1)
			return stack
		var out : Dictionary = {}
		for key in dict:
			var decodedKey : Variant = decode(key)
			if decodedKey != null:
				out[decodedKey] = decode(dict[key])
		return out
	if value is Array:
		var list : Array = []
		for each in value:
			list.append(decode(each))
		return list
	return value
