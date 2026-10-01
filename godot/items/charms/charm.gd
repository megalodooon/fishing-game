extends Item
class_name Charm

# A lucky trinket, worn in one of the two charm slots (see Equipment).
# Charms come in families that upgrade (charm, ring, artifact, relic); two
# of the same family can't be worn at once. Every charm ever found adds
# Magical Power by rarity for good, worn or not. Stats are in the units Stats uses:
# percent points, and percent for multiplier stats like luck.

#------------------------#
@export var stats : Dictionary[StringName, float] = {}
# The upgrade line it belongs to, like "angler". Empty: a family of its own.
@export var family : String = ""
# Its place in the family: 1 charm, 2 ring, 3 artifact, 4 relic.
@export var tier : int = 1
#------------------------#


func default_type() -> String:
	return ["Charm", "Charm", "Ring", "Artifact", "Relic"][clampi(tier, 0, 4)] if not family.is_empty() else "Charm"

func use(player : Player) -> bool:
	return Equipment.equip(player, player.heldSlot)

func family_key() -> String:
	return family if not family.is_empty() else original().resource_path

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	for stat in stats:
		lines.append_array([Stats.name_of(stat), Stats.bonus_text(stat, stats[stat])])
	lines.append_array(["Magical Power", "+%d once found" % Equipment.power_of(self)])
	lines.append_array(["Use it to wear it", ""])
	lines.append_array(super())
	return lines
