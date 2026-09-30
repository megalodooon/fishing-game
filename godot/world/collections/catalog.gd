extends RefCounted
class_name Catalog

# Everything there is to find, gathered from the content folders the first
# time it's asked for, so new fish, items, creatures, quests and recipes show
# up in collections and completion just by adding their files. The Preloader
# normally gathers it all on its thread before the game starts.

const FISH_FOLDER : String = "res://fishing/fish/species"
const CREATURE_FOLDER : String = "res://fishing/creatures"
const ITEM_FOLDERS : PackedStringArray = ["res://items", "res://fishing/bait", "res://fishing/tacklebox", "res://fishing/rods", "res://world/village/farm/seeds"]
const QUEST_FOLDER : String = "res://world/quests"
const RECIPE_FOLDERS : PackedStringArray = ["res://fishing/bait/recipes", "res://items/snacks/recipes", "res://items/recipes"]
const BIOME_FOLDER : String = "res://oceans"
const LOCATION_FOLDER : String = "res://world/locations"
const PROJECT_FOLDER : String = "res://world/village/restoration/projects"
# Left out of collections.
const SKIP : PackedStringArray = ["sample_pro_rod"]

static var cache : Dictionary = {}


static func fish() -> Array[FishData]:
	if cache.is_empty():
		Preloader.hand_over()
	return fish_in(cache)

static func creatures() -> Array[SeaCreature]:
	if cache.is_empty():
		Preloader.hand_over()
	return creatures_in(cache)

static func items() -> Array[Item]:
	if cache.is_empty():
		Preloader.hand_over()
	return items_in(cache)

# Fish, then sea creatures, then items.
static func things() -> Array[Resource]:
	if cache.is_empty():
		Preloader.hand_over()
	return things_in(cache)

static func quests() -> Array[Quest]:
	if cache.is_empty():
		Preloader.hand_over()
	return quests_in(cache)

static func biomes() -> Array[Biome]:
	if cache.is_empty():
		Preloader.hand_over()
	return biomes_in(cache)

static func locations() -> Array[Location]:
	if cache.is_empty():
		Preloader.hand_over()
	return locations_in(cache)

static func projects() -> Array[Project]:
	if cache.is_empty():
		Preloader.hand_over()
	return projects_in(cache)

static func recipes() -> Array[BaitRecipe]:
	if cache.is_empty():
		Preloader.hand_over()
	return recipes_in(cache)

# Every list, gathered into a new dictionary, so the Preloader can do it on
# its thread without touching the cache.
static func build() -> Dictionary:
	var built : Dictionary = {}
	things_in(built)
	quests_in(built)
	recipes_in(built)
	biomes_in(built)
	locations_in(built)
	projects_in(built)
	return built

# Takes the lists the Preloader gathered, unless the game already needed
# them (and gathered them itself) before it was done.
static func adopt(built : Dictionary) -> void:
	if cache.is_empty():
		cache = built

static func scan(folder : String, recursive : bool = true) -> Array[Resource]:
	var list : Array[Resource] = []
	if not DirAccess.dir_exists_absolute(folder):
		return list
	for file in DirAccess.get_files_at(folder):
		var path : String = file.trim_suffix(".remap")
		if path.ends_with(".tres") or path.ends_with(".res"):
			var resource : Resource = load(folder.path_join(path))
			if resource:
				list.append(resource)
	if recursive:
		for sub in DirAccess.get_directories_at(folder):
			list.append_array(scan(folder.path_join(sub), true))
	return list

static func fish_in(lists : Dictionary) -> Array[FishData]:
	if not lists.has("fish"):
		var list : Array[FishData] = []
		for resource in scan(FISH_FOLDER):
			if resource is FishData:
				list.append(resource)
		lists["fish"] = list
	return lists["fish"]

static func creatures_in(lists : Dictionary) -> Array[SeaCreature]:
	if not lists.has("creatures"):
		var list : Array[SeaCreature] = []
		for resource in scan(CREATURE_FOLDER):
			if resource is SeaCreature:
				list.append(resource)
		lists["creatures"] = list
	return lists["creatures"]

static func items_in(lists : Dictionary) -> Array[Item]:
	if not lists.has("items"):
		var list : Array[Item] = []
		for folder in ITEM_FOLDERS:
			for resource in scan(folder):
				var item : Item = resource as Item
				if item and item.useAction.is_empty() and not list.has(item) and not SKIP.has(item.resource_path.get_file().get_basename()) and not item.category == "Key Item" and not Collections.uncollected(item):
					list.append(item)
		lists["items"] = list
	return lists["items"]

static func things_in(lists : Dictionary) -> Array[Resource]:
	if not lists.has("things"):
		var list : Array[Resource] = []
		list.append_array(fish_in(lists))
		list.append_array(creatures_in(lists))
		list.append_array(items_in(lists))
		lists["things"] = list
	return lists["things"]

static func quests_in(lists : Dictionary) -> Array[Quest]:
	if not lists.has("quests"):
		var list : Array[Quest] = []
		for resource in scan(QUEST_FOLDER):
			if resource is Quest:
				list.append(resource)
		lists["quests"] = list
	return lists["quests"]

static func biomes_in(lists : Dictionary) -> Array[Biome]:
	if not lists.has("biomes"):
		var list : Array[Biome] = []
		for resource in scan(BIOME_FOLDER):
			if resource is Biome:
				list.append(resource)
		lists["biomes"] = list
	return lists["biomes"]

static func locations_in(lists : Dictionary) -> Array[Location]:
	if not lists.has("locations"):
		var list : Array[Location] = []
		for resource in scan(LOCATION_FOLDER):
			if resource is Location:
				list.append(resource)
		lists["locations"] = list
	return lists["locations"]

static func projects_in(lists : Dictionary) -> Array[Project]:
	if not lists.has("projects"):
		var list : Array[Project] = []
		for resource in scan(PROJECT_FOLDER):
			if resource is Project:
				list.append(resource)
		lists["projects"] = list
	return lists["projects"]

static func recipes_in(lists : Dictionary) -> Array[BaitRecipe]:
	if not lists.has("recipes"):
		var list : Array[BaitRecipe] = []
		for folder in RECIPE_FOLDERS:
			for resource in scan(folder):
				if resource is BaitRecipe:
					list.append(resource)
		lists["recipes"] = list
	return lists["recipes"]
