extends Tackle
class_name Bait

# Goes in a rod's bait slot. Every fish caught with it on uses one up. It
# makes some rarities, or some fish, bite more often.

#------------------------#
@export_group("Lure")
# How much likelier each rarity bites, like 2 for twice as often.
@export var rarityBoost : Dictionary[Rarity, float] = {}
# The same for single fish.
@export var fishBoost : Dictionary[FishData, float] = {}
#------------------------#


func boost(data : FishData) -> float:
	return rarityBoost.get(data.rarity, 1.0) * fishBoost.get(data, 1.0)

func details() -> PackedStringArray:
	var lines : PackedStringArray = super()
	for each in rarityBoost:
		lines.append_array([each.displayName + " fish", "x%.1f" % rarityBoost[each]])
	for each in fishBoost:
		lines.append_array([each.displayName, "x%.1f" % fishBoost[each]])
	lines.append_array(["One used per catch", ""])
	return lines
