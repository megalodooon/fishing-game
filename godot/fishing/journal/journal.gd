extends Resource
class_name Journal

# Every fish ever caught: how many and the heaviest one. A fish shows up in
# the journal once it has been caught at least once.

# Emitted the first time a page fills up, with that page's biome, or null
# when the whole journal is done. Meant for completion rewards.
signal completed(biome : Biome)

#------------------------#
# Every ocean's page, in the order the journal flips through them.
@export var biomes : Array[Biome] = []
@export var caught : Dictionary[FishData, int] = {}
@export var heaviest : Dictionary[FishData, float] = {}
# What has been caught in each ocean. A fish is undiscovered on every other
# page until it is caught there too.
@export var discovered : Dictionary = {}

# Caught but not looked at in the journal yet.
var unseen : Array[FishData] = []
# all_fish(), worked out once: the pages don't change while playing.
var allFish : Array[FishData] = []
#------------------------#


func setup() -> void:
	for event in GameEvent.all():
		if event.page and not biomes.has(event.page):
			biomes.append(event.page)
	caught = caught.duplicate()
	heaviest = heaviest.duplicate()
	discovered = discovered.duplicate(true)

# With a biome: whether it was caught in that ocean. Without: anywhere.
func is_found(data : FishData, biome : Biome = null) -> bool:
	if biome:
		return discovered.get(biome, []).has(data)
	return caught.get(data, 0) > 0

func count(data : FishData) -> int:
	return caught.get(data, 0)

func best(data : FishData) -> float:
	return heaviest.get(data, 0.0)

# Returns whether this was the first of its kind in that ocean.
func record(fish : Fish, where : Biome = null) -> bool:
	var data : FishData = fish.species
	if where:
		where = where.journal_page()
	var first : bool = not is_found(data, where)
	var done : Array[Biome] = []
	if first and where and biomes.has(where) and found_in(where.fish, where) == where.fish.size() - 1 and where.fish.has(data):
		done.append(where)
	var wasComplete : bool = found_in(all_fish()) == all_fish().size()
	caught[data] = count(data) + 1
	heaviest[data] = maxf(best(data), fish.weight)
	if where:
		if not discovered.has(where):
			discovered[where] = []
		if first:
			discovered[where].append(data)
	if first and not unseen.has(data):
		unseen.append(data)
	emit_changed()
	for biome in done:
		completed.emit(biome)
	if not wasComplete and found_in(all_fish()) == all_fish().size():
		completed.emit(null)
	return first

func see(data : FishData) -> void:
	if unseen.has(data):
		unseen.erase(data)
		emit_changed()

func found_in(list : Array[FishData], biome : Biome = null) -> int:
	var total : int = 0
	for data in list:
		if is_found(data, biome):
			total += 1
	return total

# Every fish from every page once, the most common rarities first. The
# same list every time; don't change it.
func all_fish() -> Array[FishData]:
	if allFish.is_empty() or Engine.is_editor_hint():
		allFish = gather_fish()
	return allFish

func gather_fish() -> Array[FishData]:
	var list : Array[FishData] = []
	for biome in biomes:
		for data in biome.fish:
			if data and not list.has(data):
				list.append(data)
	var order : Dictionary[FishData, int] = {}
	for i in list.size():
		order[list[i]] = i
	list.sort_custom(func(a : FishData, b : FishData) -> bool:
		var left : float = a.rarity.difficulty if a.rarity else 0.0
		var right : float = b.rarity.difficulty if b.rarity else 0.0
		return left < right if left != right else order[a] < order[b])
	return list

func biome_names(data : FishData) -> PackedStringArray:
	var names : PackedStringArray = PackedStringArray()
	for biome in biomes:
		if biome.fish.has(data):
			names.append(biome.displayName)
	return names
