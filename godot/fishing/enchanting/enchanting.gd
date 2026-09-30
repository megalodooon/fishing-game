extends RefCounted
class_name Enchanting

# Rod enchantments (like SkyBlock's enchanting table): put on a rod at Luma's
# altar for Sea Essence and coins, one level at a time, higher levels needing
# more Alchemy. They live on the rod (RodItem.enchants) and count as the
# player's stats while that rod is in hand. Sea Essence comes from sea
# creatures, sea hunts, buried treasure and the museum.

const ESSENCE : String = "res://items/enchanting/sea_essence.tres"
const COLOR : Color = Color(0.72, 0.55, 1.0)
const ROMAN : PackedStringArray = ["", "I", "II", "III", "IV", "V"]
# Per level: Sea Essence, coins and the Alchemy level needed.
const ESSENCE_COST : PackedInt32Array = [0, 6, 15, 35, 80, 180]
const COIN_COST : PackedInt32Array = [0, 250, 1000, 4000, 15000, 50000]
const ALCHEMY_NEEDED : PackedInt32Array = [0, 1, 4, 10, 17, 25]
# id, name, stat, per level, most levels, what it does.
const LIST : Array = [
	["lure", "Lure", &"biteSpeed", 4.0, 5, "Fish bite sooner."],
	["luck_of_the_sea", "Luck of the Sea", &"luck", 3.0, 5, "Rarer fish."],
	["blessing", "Blessing", &"rareFind", 3.0, 5, "Rare catches come up more."],
	["magnet", "Magnet", &"treasure", 0.3, 5, "More treasure."],
	["piscary", "Piscary", &"doubleCatch", 1.0, 5, "Double catches."],
	["frail", "Frail", &"seaCreature", 0.5, 5, "Sea creatures bite more."],
	["charm", "Charm", &"trophyLuck", 5.0, 5, "Better trophy fish tiers."],
	["angler", "Angler", &"xpBonus", 2.0, 5, "More skill XP."],
	["caster", "Caster", &"castEnergy", -4.0, 5, "Casting takes less energy."],
	["spiked_hook", "Spiked Hook", &"damage", 6.0, 5, "Hit sea creatures harder."],
	["expertise", "Expertise", &"weight", 3.0, 5, "Heavier fish."],
]

static var frame : int = -1
static var cachedRod : RodItem
static var cached : Dictionary = {}


static func entry(id : String) -> Array:
	for each in LIST:
		if each[0] == id:
			return each
	return []

static func level(rod : RodItem, id : String) -> int:
	return int(rod.enchants.get(id, 0)) if rod else 0

static func held_rod(player : Player) -> RodItem:
	var held : FishingRod = player.heldItem as FishingRod if player else null
	return held.item as RodItem if held else null

# What the held rod's enchantments add to a stat, worked out once a frame.
static func bonus(player : Player, stat : StringName) -> float:
	var now : int = Engine.get_process_frames()
	var rod : RodItem = held_rod(player)
	if now != frame or rod != cachedRod:
		frame = now
		cachedRod = rod
		cached.clear()
		if rod:
			for id in rod.enchants:
				var each : Array = entry(id)
				if not each.is_empty():
					cached[each[2]] = cached.get(each[2], 0.0) + float(each[3]) * int(rod.enchants[id])
	return cached.get(stat, 0.0)

# Why a rod can't take the next level of an enchantment, or nothing.
static func blocked(player : Player, rod : RodItem, id : String) -> String:
	var each : Array = entry(id)
	var next : int = level(rod, id) + 1
	if next > int(each[4]):
		return "Already at its best"
	if Skills.level(player, Skills.ALCHEMY) < ALCHEMY_NEEDED[next]:
		return "Needs Alchemy %d" % ALCHEMY_NEEDED[next]
	var essence : Item = load(ESSENCE) as Item
	if player.inventory.count(essence) < ESSENCE_COST[next]:
		return "Needs %d Sea Essence" % ESSENCE_COST[next]
	if not player.wallet.can_afford(COIN_COST[next]):
		return "Needs $%s" % UiKit.coins_text(COIN_COST[next])
	return ""

static func enchant(player : Player, rod : RodItem, id : String) -> bool:
	if not blocked(player, rod, id).is_empty():
		return false
	var next : int = level(rod, id) + 1
	player.inventory.take(load(ESSENCE) as Item, ESSENCE_COST[next])
	player.wallet.spend(COIN_COST[next])
	rod.enchants[id] = next
	rod.emit_changed()
	player.progress.count("enchants")
	if next >= 5:
		player.progress.count("enchant_max")
	Skills.add(player, Skills.ALCHEMY, 20.0 * next * next)
	frame = -1
	return true

static func lines(rod : RodItem) -> PackedStringArray:
	var list : PackedStringArray = PackedStringArray()
	for each in LIST:
		var at : int = level(rod, each[0])
		if at > 0:
			list.append_array(["%s %s" % [each[1], ROMAN[at]], Stats.bonus_text(each[2], float(each[3]) * at)])
	return list
