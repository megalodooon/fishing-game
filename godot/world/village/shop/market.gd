extends RefCounted
class_name Market

# Fish prices move a little every day: a few kinds are in demand and pay a
# lot more, a few are out of fashion. The same day always gives the same
# picks, so the market board can list them.

const HOT_CHANCE : float = 0.12
const COLD_CHANCE : float = 0.1


static func factor(species : FishData, day : int) -> float:
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([day, species.resource_path, "market"])
	var roll : float = random.randf()
	if roll < HOT_CHANCE:
		return snappedf(random.randf_range(1.5, 2.2), 0.1)
	if roll < HOT_CHANCE + COLD_CHANCE:
		return snappedf(random.randf_range(0.6, 0.8), 0.1)
	return 1.0

# Today's hot fish among the ones the player has found, best first.
static func hot(journal : Journal, day : int, limit : int = 6) -> Array:
	var list : Array = []
	for species in Catalog.fish():
		var rate : float = factor(species, day)
		if rate > 1.0 and journal.is_found(species):
			list.append([species, rate])
	list.sort_custom(func(a : Array, b : Array) -> bool: return a[1] > b[1])
	return list.slice(0, limit)
