extends RefCounted
class_name SaveGame

# Saving and loading. Three slots in user://, each a text file of plain values:
# resources the game ships with are stored by their path, fish and item stacks
# by what they're made of. Everything the player owns or has done lives in the
# player's resources (inventory, tacklebox, journal, energy, wallet, atlas,
# progress) plus the clock. Every script variable of Progress is saved, so new
# progress fields are picked up without touching this file.

const SLOTS : int = 3
const VERSION : int = 1
const RES : String = "@res:"
# The resources on the player and which of their properties are the save.
# Progress saves all of its properties.
const STATE : Dictionary = {
	"inventory": ["backpackSize", "items"],
	"tacklebox": ["owned"],
	"journal": ["caught", "heaviest", "discovered"],
	"energy": ["maximum", "value"],
	"wallet": ["coins"],
	"atlas": ["current", "previous", "unlocked"],
}

# The slot the running game saves to.
static var slot : int = 0
# Filled by the title screen: the save to load when the game starts, or empty
# for a new game.
static var pending : Dictionary = {}


static func path(which : int) -> String:
	return "user://save_%d.sav" % which

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

# What the title screen shows for a slot, without loading any resources.
static func summary(which : int) -> Dictionary:
	var data : Dictionary = read(which)
	return data.get("summary", {}) if not data.is_empty() else {}

# The slot saved last, or -1 when there are none.
static func latest() -> int:
	var best : int = -1
	var when : float = -1.0
	for i in SLOTS:
		var info : Dictionary = summary(i)
		if not info.is_empty() and float(info.get("saved", 0.0)) > when:
			when = info.get("saved", 0.0)
			best = i
	return best

static func save_game(tree : SceneTree) -> bool:
	var player : Player = Player.find(tree)
	var cycle : DayNightCycle = DayNightCycle.find(tree)
	if not player:
		return false
	var data : Dictionary = {"version": VERSION}
	for key in STATE:
		var owner : Resource = player.get(key)
		var part : Dictionary = {}
		for property in STATE[key]:
			part[property] = encode(owner.get(property))
		data[key] = part
	var progress : Dictionary = {}
	for property in state_properties(player.progress):
		progress[property] = encode(player.progress.get(property))
	data["progress"] = progress
	if cycle:
		data["clock"] = {"day": cycle.day, "time": cycle.time}
	data["summary"] = {
		"saved": Time.get_unix_time_from_system(),
		"day": cycle.day if cycle else 1,
		"weekday": cycle.weekday_name(true) if cycle else "",
		"coins": player.wallet.coins,
		"place": player.atlas.current.displayName if player.atlas.current else "",
		"playtime": player.progress.playtime,
		"chapter": player.progress.chapter_title(),
		"completion": Collections.completion(player),
	}
	var file : FileAccess = FileAccess.open(path(slot), FileAccess.WRITE)
	if not file:
		return false
	file.store_string(var_to_str(data))
	return true

# Puts a save into the running game. Called once everything is ready.
static func load_into(tree : SceneTree, data : Dictionary) -> void:
	var player : Player = Player.find(tree)
	if not player or data.is_empty():
		return
	for key in STATE:
		var owner : Resource = player.get(key)
		var part : Dictionary = data.get(key, {})
		for property in part:
			put(owner, property, decode(part[property]))
	var progress : Dictionary = data.get("progress", {})
	var known : PackedStringArray = state_properties(player.progress)
	for property in progress:
		if known.has(property):
			put(player.progress, property, decode(progress[property]))
	player.inventory.setup()
	var cycle : DayNightCycle = DayNightCycle.find(tree)
	var clock : Dictionary = data.get("clock", {})
	if cycle and not clock.is_empty():
		cycle.set_day(clock.day)
		cycle.set_time(clock.time)
	for key in STATE:
		(player.get(key) as Resource).emit_changed()
	player.progress.emit_changed()

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
		return {"@rod": rod.original().resource_path, "tackle": encode(rod.tackle), "reforge": encode(rod.reforge)}
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
