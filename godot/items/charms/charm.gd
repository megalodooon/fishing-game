extends Item
class_name Charm

# A lucky trinket. It works while it's in the bag, on the hotbar or in the
# charm pouch, and each kind only counts once. Charms come in families that
# upgrade (charm, ring, artifact, relic): only the best one of a family you
# carry counts. Charms in the pouch also add Magical Power by rarity, which
# turns into stats (see CharmPouch). Stats are in the units Stats uses:
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

func family_key() -> String:
	return family if not family.is_empty() else original().resource_path

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	for stat in stats:
		lines.append_array([Stats.name_of(stat), Stats.bonus_text(stat, stats[stat])])
	lines.append_array(["Magical Power", "+%d in the pouch" % CharmPouch.power_of(self)])
	if not family.is_empty():
		lines.append_array(["Only the best of a family counts", ""])
	lines.append_array(super())
	return lines
