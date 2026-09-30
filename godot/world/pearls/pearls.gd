extends RefCounted
class_name Pearls

# Lost pearls hidden all over the islands (Secrets whose flag starts with
# "pearl_"). The pearl diver trades every five found for a lasting blessing,
# in this order.

const PER_BLESSING : int = 5
# How many are hidden around the world.
const TOTAL : int = 60
const PREFIX : String = "secret/pearl_"
const BLESSINGS : Array = [
	[&"energyMax", 5.0], [&"luck", 2.0], [&"treasure", 0.5], [&"energyMax", 5.0],
	[&"seaCreature", 0.5], [&"variantLuck", 10.0], [&"sellBonus", 2.0], [&"energyMax", 5.0],
	[&"doubleCatch", 2.0], [&"luck", 3.0], [&"xpBonus", 5.0], [&"energyMax", 10.0],
]


static func found(progress : Progress) -> int:
	var count : int = 0
	for key in progress.flags:
		if String(key).begins_with(PREFIX):
			count += 1
	return count

static func claimed(progress : Progress) -> int:
	return progress.get_flag("pearl_blessings", 0)

static func claimable(progress : Progress) -> int:
	@warning_ignore("integer_division")
	return mini(found(progress) / PER_BLESSING, BLESSINGS.size()) - claimed(progress)

static func bonus(progress : Progress, stat : StringName) -> float:
	var total : float = 0.0
	for i in mini(claimed(progress), BLESSINGS.size()):
		if BLESSINGS[i][0] == stat:
			total += BLESSINGS[i][1]
	return total
