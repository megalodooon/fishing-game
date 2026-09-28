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

# Caught but not looked at in the journal yet.
var unseen : Array[FishData] = []
#------------------------#


func setup() -> void:
	caught = caught.duplicate()
	heaviest = heaviest.duplicate()

func is_found(data : FishData) -> bool:
	return caught.get(data, 0) > 0

func count(data : FishData) -> int:
	return caught.get(data, 0)

func best(data : FishData) -> float:
	return heaviest.get(data, 0.0)

# Returns whether this was the first of its kind.
func record(fish : Fish) -> bool:
	var data : FishData = fish.species
	var first : bool = not is_found(data)
	var done : Array[Biome] = []
	if first:
		for biome in biomes:
			if found_in(biome.fish) == biome.fish.size() - 1 and biome.fish.has(data):
				done.append(biome)
	var wasComplete : bool = found_in(all_fish()) == all_fish().size()
	caught[data] = count(data) + 1
	heaviest[data] = maxf(best(data), fish.weight)
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

func found_in(list : Array[FishData]) -> int:
	var total : int = 0
	for data in list:
		if is_found(data):
			total += 1
	return total

# Every fish from every page once, the most common rarities first.
func all_fish() -> Array[FishData]:
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
