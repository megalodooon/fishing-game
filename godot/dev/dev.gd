extends RefCounted
class_name Dev

# Cheats toggled from the developer menu (0 key). Everything checks these
# flags, so turning them off puts the game back to normal.

static var legendaryCatches : bool = false
static var trophyCatches : bool = false
static var instantBites : bool = false
static var autoWin : bool = false
static var infiniteEnergy : bool = false


static func flag(flagName : String) -> bool:
	match flagName:
		"legendaryCatches":
			return legendaryCatches
		"trophyCatches":
			return trophyCatches
		"instantBites":
			return instantBites
		"autoWin":
			return autoWin
		"infiniteEnergy":
			return infiniteEnergy
	return false

static func flip(flagName : String) -> void:
	var on : bool = not flag(flagName)
	match flagName:
		"legendaryCatches":
			legendaryCatches = on
		"trophyCatches":
			trophyCatches = on
		"instantBites":
			instantBites = on
		"autoWin":
			autoWin = on
		"infiniteEnergy":
			infiniteEnergy = on

# The fish a cheat forces out of this pool, ignoring times and requirements.
# Empty when no cheat is on (or the pool has none of that rarity).
static func forced_fish(pool : Array[FishData]) -> Array[FishData]:
	var wanted : PackedStringArray = PackedStringArray()
	if trophyCatches:
		wanted.append("Trophy")
	if legendaryCatches:
		wanted.append("Legendary")
	for rarity in wanted:
		var list : Array[FishData] = []
		for data in pool:
			if data and data.rarity and data.rarity.displayName == rarity:
				list.append(data)
		if not list.is_empty():
			return list
	return []

# Every resource of a folder (exported builds list them with .remap).
static func load_all(folder : String) -> Array[Resource]:
	var list : Array[Resource] = []
	for file in DirAccess.get_files_at(folder):
		var path : String = file.trim_suffix(".remap")
		if path.ends_with(".tres") or path.ends_with(".res"):
			var resource : Resource = load(folder.path_join(path))
			if resource:
				list.append(resource)
	return list
