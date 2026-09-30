extends RefCounted
class_name Collections

# Every fish, sea creature and item has a collection: how many were ever
# caught, beaten or obtained. Reaching a tier (by rarity, see TIERS) pays out
# coins and skill XP and can unlock recipes that ask for its flag,
# "collection/<file name>/<tier>". The Collection book shows it all, and the
# completion percentage says how much of the game has been found.

const CATEGORIES : PackedStringArray = ["Fish", "Creatures", "Treasure", "Rare", "Festival", "Farming", "Food", "Materials", "Bait", "Tackle", "Rods", "Charms"]
const TIERS : Dictionary = {
	"Common": [5, 25, 100, 400],
	"Uncommon": [3, 15, 50, 200],
	"Rare": [1, 5, 20, 75],
	"Legendary": [1, 3, 10, 30],
	"Trophy": [1, 2, 5, 10],
}
const WORTH : Dictionary = {"Common": 1.0, "Uncommon": 1.6, "Rare": 3.0, "Legendary": 6.0, "Trophy": 12.0}
const TIER_COINS : PackedInt32Array = [25, 80, 250, 800]
const TIER_XP : PackedFloat32Array = [30.0, 120.0, 400.0, 1200.0]
const ROMAN : PackedStringArray = ["I", "II", "III", "IV", "V"]
const TIER_COLOR : Color = Color(1.0, 0.78, 0.35)

# Per thing in Catalog.things(), worked out once for completion(): 0 fish,
# 1 sea creature, 2 item, and its tier thresholds.
static var kinds : PackedByteArray = PackedByteArray()
static var needs : Array = []
static var tierTotal : int = 0


static func key(thing : Resource) -> Resource:
	if thing is Fish:
		return (thing as Fish).species
	if thing is Item:
		return (thing as Item).original()
	return thing

static func name_of(thing : Resource) -> String:
	if thing is FishData:
		return (thing as FishData).displayName
	if thing is SeaCreature:
		return (thing as SeaCreature).displayName
	if thing is Item:
		return (thing as Item).displayName
	return "?"

static func icon_of(thing : Resource) -> Texture2D:
	if thing is FishData:
		return (thing as FishData).icon
	if thing is SeaCreature:
		return (thing as SeaCreature).icon
	if thing is Item:
		return (thing as Item).icon
	return null

static func rarity_of(thing : Resource) -> Rarity:
	if thing is FishData:
		return (thing as FishData).rarity
	if thing is SeaCreature:
		return (thing as SeaCreature).rarity
	if thing is Item:
		return (thing as Item).rarity
	return null

static func category(thing : Resource) -> String:
	if thing is FishData:
		return "Fish"
	if thing is SeaCreature:
		return "Creatures"
	if thing is Item and ["Festival", "Gift"].has((thing as Item).category):
		return "Festival"
	if thing is Item and ["Rare Catch", "Reforge Stone"].has((thing as Item).category):
		return "Rare"
	if thing is TreasureChest:
		return "Treasure"
	if thing is Seed or (thing is Item and ((thing as Item).category == "Crop")):
		return "Farming"
	if thing is Snack:
		return "Food"
	if thing is Bait:
		return "Bait"
	if thing is Tackle:
		return "Tackle"
	if thing is RodItem:
		return "Rods"
	if thing is Charm:
		return "Charms"
	return "Materials"

static func skill_for(thing : Resource) -> StringName:
	if thing is Item and (thing as Item).category == "Forage":
		return Skills.FORAGING
	if thing is Item and (thing as Item).category == "Potion":
		return Skills.ALCHEMY
	match category(thing):
		"Fish", "Treasure":
			return Skills.FISHING
		"Creatures":
			return Skills.HUNTING
		"Farming":
			return Skills.FARMING
		"Food":
			return Skills.COOKING
	return Skills.TRADING

static func count(player : Player, thing : Resource) -> int:
	if thing is FishData:
		return player.journal.count(thing)
	if thing is SeaCreature:
		return player.progress.bestiary.get(thing, 0)
	return player.progress.collected.get(thing, 0)

static func tiers(thing : Resource) -> Array:
	var rarity : Rarity = rarity_of(thing)
	return TIERS.get(rarity.displayName if rarity else "Common", TIERS["Common"])

static func tier(player : Player, thing : Resource) -> int:
	var have : int = count(player, thing)
	var reached : int = 0
	for need in tiers(thing):
		if have >= need:
			reached += 1
	return reached

static func flag(thing : Resource, level : int) -> String:
	return "collection/%s/%d" % [thing.resource_path.get_file().get_basename(), level]

# Currencies are spent, not collected.
static func uncollected(item : Item) -> bool:
	return item.category == "Currency" or item.category == "Essence"

# An item came into the bag or the tacklebox. Fish count through the journal.
static func add(player : Player, item : Item, amount : int) -> void:
	if not player or not player.progress or not item or item is Fish or uncollected(item):
		return
	var thing : Resource = key(item)
	if thing.resource_path.is_empty():
		return
	player.progress.collected[thing] = player.progress.collected.get(thing, 0) + amount
	check(player, thing)

# Pays out every tier reached since the last check.
static func check(player : Player, thing : Resource) -> void:
	var reached : int = tier(player, thing)
	var paid : int = player.progress.collectionTiers.get(thing, 0)
	if reached <= paid:
		return
	player.progress.collectionTiers[thing] = reached
	var rarity : Rarity = rarity_of(thing)
	var worth : float = WORTH.get(rarity.displayName if rarity else "Common", 1.0)
	var coins : int = 0
	var xp : float = 0.0
	var unlocked : PackedStringArray = PackedStringArray()
	for level in range(paid, reached):
		coins += roundi(TIER_COINS[mini(level, TIER_COINS.size() - 1)] * worth)
		xp += TIER_XP[mini(level, TIER_XP.size() - 1)] * worth
		var key_flag : String = flag(thing, level + 1)
		player.progress.set_flag(key_flag)
		for recipe in Catalog.recipes():
			if recipe.requiredFlag == key_flag and recipe.result():
				unlocked.append(recipe.result().displayName)
	player.wallet.add(coins)
	Skills.add(player, skill_for(thing), xp)
	var text : String = "+$%d, +%d %s XP" % [coins, roundi(xp), Skills.NAMES[skill_for(thing)]]
	if not unlocked.is_empty():
		text += ". New recipe: " + ", ".join(unlocked)
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if board:
		board.post("Collection: %s %s" % [name_of(thing), ROMAN[reached - 1]], text, TIER_COLOR, icon_of(thing))

static func index_things(things : Array[Resource]) -> void:
	kinds.resize(things.size())
	needs.resize(things.size())
	tierTotal = 0
	for i in things.size():
		var thing : Resource = things[i]
		kinds[i] = 0 if thing is FishData else (1 if thing is SeaCreature else 2)
		needs[i] = tiers(thing)
		tierTotal += needs[i].size()

static func found(player : Player, thing : Resource) -> bool:
	return count(player, thing) > 0

# 0 to 100: things found, collection tiers, skill levels, quests and pearls.
static func completion(player : Player) -> float:
	var things : Array[Resource] = Catalog.things()
	if kinds.size() != things.size():
		index_things(things)
	var caught : Dictionary = player.journal.caught
	var beaten : Dictionary = player.progress.bestiary
	var collected : Dictionary = player.progress.collected
	var foundCount : float = 0.0
	var tierCount : float = 0.0
	for i in things.size():
		var thing : Resource = things[i]
		var kind : int = kinds[i]
		var have : int = caught.get(thing, 0) if kind == 0 else (beaten.get(thing, 0) if kind == 1 else collected.get(thing, 0))
		if have <= 0:
			continue
		foundCount += 1.0
		for need in needs[i]:
			if have >= need:
				tierCount += 1.0
	var skills : float = 0.0
	for skill in Skills.LIST:
		skills += (Skills.level(player, skill) - 1) / float(Skills.MAX_LEVEL - 1)
	var quests : Array[Quest] = Catalog.quests()
	var done : float = 0.0
	for quest in quests:
		if player.progress.quest_done(quest):
			done += 1.0
	var parts : float = 0.0
	parts += 40.0 * foundCount / maxf(things.size(), 1.0)
	parts += 20.0 * tierCount / maxf(float(tierTotal), 1.0)
	parts += 15.0 * skills / Skills.LIST.size()
	parts += 15.0 * done / maxf(quests.size(), 1.0)
	parts += 10.0 * minf(Pearls.found(player.progress) / float(Pearls.TOTAL), 1.0)
	return parts
