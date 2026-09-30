extends RefCounted
class_name RareDrops

# Rolls the rare drops after every fish landed. Each drop has a luck meter
# (Progress.pity): every catch where it could have come up fills it, and a
# full meter makes the next one certain, so grinding always pays off in the
# end. Getting it empties the meter. The journal shows the meters per page.

const FOLDER : String = "res://items/rare_drops"
const COLOR : Color = Color(1.0, 0.45, 0.85)

static var list : Array[RareDrop] = []
static var loaded : bool = false


static func all() -> Array[RareDrop]:
	if not loaded:
		loaded = true
		for resource in Catalog.scan(FOLDER):
			if resource is RareDrop and (resource as RareDrop).item:
				list.append(resource)
	return list

# The drops that can come up in a place, rarest first.
static func for_biome(biome : Biome) -> Array[RareDrop]:
	var found : Array[RareDrop] = []
	for drop in all():
		if drop.applies(biome):
			found.append(drop)
	found.sort_custom(func(a : RareDrop, b : RareDrop) -> bool: return a.chance < b.chance)
	return found

static func meter(progress : Progress, drop : RareDrop) -> int:
	return progress.pity.get(drop, 0) if progress else 0

# Rolls every drop for a catch here. Returns the items that came up.
static func roll(player : Player, biome : Biome) -> Array[Item]:
	var got : Array[Item] = []
	var level : int = Skills.level(player, Skills.FISHING)
	var luck : float = player.stat(&"luck") * (1.0 + player.stat(&"rareFind") * 0.01)
	for drop in all():
		if level < drop.minFishing or not drop.applies(biome):
			continue
		var count : int = meter(player.progress, drop) + 1
		if count >= drop.pity_count() or randf() < drop.chance * luck:
			player.progress.pity[drop] = 0
			got.append(drop.item)
		else:
			player.progress.pity[drop] = count
	return got
