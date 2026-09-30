extends Resource
class_name RareDrop

# Something rare that can come up with any fish caught in its places: a
# message in a bottle, a pirate doubloon, a mermaid's comb. Every catch in
# those places rolls for it, luck helps, and the luck meter guarantees it
# after enough catches without one (see RareDrops). Files live in
# res://items/rare_drops, so new ones need no wiring.

#------------------------#
@export var item : Item
# The odds per catch, like 0.002 for 1 in 500.
@export_range(0.0, 1.0, 0.0001) var chance : float = 0.01
# Where it can come up. Empty means anywhere.
@export var biomes : Array[Biome] = []
# Fishing level needed before it can come up.
@export var minFishing : int = 1
# Catches without it that guarantee it. 0 works it out from the chance.
@export var pity : int = 0
#------------------------#


func pity_count() -> int:
	return pity if pity > 0 else maxi(roundi(2.5 / maxf(chance, 0.0001)), 10)

func applies(biome : Biome) -> bool:
	if biomes.is_empty():
		return true
	var page : Biome = biome.journal_page() if biome else null
	for place in biomes:
		if place == biome or place == page:
			return true
	return false

func where() -> String:
	if biomes.is_empty():
		return "any fishing ground"
	var names : PackedStringArray = PackedStringArray()
	for place in biomes:
		if place:
			names.append(place.displayName)
	return ", ".join(names)
