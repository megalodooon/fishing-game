extends RefCounted
class_name AnglerLevel

# The Angler Level (like the SkyBlock Level): one number for everything the
# player has done. Skill levels, collection tiers, fish found, sea creatures
# beaten, quests, pearls, rare catches, crew, Magical Power, recipes,
# festivals, trophy fish, museum pieces, sea hunts, friendships, treasure
# trails and achievements all give Angler XP; every 100 XP is a level. Levels raise max
# energy, and every few levels open another charm pouch slot and another crew
# slot. The skills menu shows where the XP comes from and what's next.

const XP_PER_LEVEL : int = 100
# Label, Angler XP each, and what it counts.
const SOURCES : Array = [
	["Skill levels", 8, "skills"],
	["Collection tiers", 4, "tiers"],
	["Fish discovered", 3, "fish"],
	["Sea creatures beaten", 5, "creatures"],
	["Quests done", 6, "quests"],
	["Pearls found", 4, "pearls"],
	["Rare catches found", 10, "rares"],
	["Crew tiers", 4, "crew"],
	["Magical Power", 1, "power"],
	["Recipes made", 2, "recipes"],
	["Festivals joined", 15, "festivals"],
	["Trophy tiers caught", 5, "trophies"],
	["Museum pieces", 3, "museum"],
	["Sea hunts finished", 8, "hunts"],
	["Friendship hearts", 3, "hearts"],
	["Treasure trails dug", 3, "trails"],
	["Achievements", 4, "achievements"],
]
const POUCH_EVERY : int = 3
const CREW_EVERY : int = 5
const ENERGY_PER_LEVEL : float = 1.0

# Worked out at most every couple of seconds: stats ask for it all the time.
static var cachedAt : int = -100000
static var cachedCounts : Dictionary = {}
static var cachedXp : int = 0


static func counts(player : Player) -> Dictionary:
	var now : int = Time.get_ticks_msec()
	if now - cachedAt < 2000 and not cachedCounts.is_empty():
		return cachedCounts
	cachedAt = now
	var found : Dictionary = {}
	var levels : int = 0
	for skill in Skills.LIST:
		levels += Skills.level(player, skill) - 1
	found["skills"] = levels
	var tiers : int = 0
	for thing in player.progress.collectionTiers:
		tiers += player.progress.collectionTiers[thing]
	found["tiers"] = tiers
	found["fish"] = player.journal.caught.size()
	found["creatures"] = player.progress.bestiary.size()
	var quests : int = 0
	for quest in player.progress.quests:
		if player.progress.quests[quest].done:
			quests += 1
	found["quests"] = quests
	found["pearls"] = Pearls.found(player.progress)
	var rares : int = 0
	for drop in RareDrops.all():
		if player.progress.collected.has(drop.item):
			rares += 1
	found["rares"] = rares
	var crew : int = 0
	var recipes : int = 0
	var festivals : int = 0
	for flag in player.progress.flags:
		var key : String = flag
		if key.begins_with("crew_tier/"):
			crew += 1
		elif key.begins_with("crafted/"):
			recipes += 1
		elif key.begins_with("festival_seen/"):
			festivals += 1
	found["crew"] = crew
	found["recipes"] = recipes
	found["festivals"] = festivals
	found["power"] = CharmPouch.pouch_power(player)
	found["trophies"] = TrophyFishing.tiers_caught(player.progress)
	found["museum"] = player.progress.counter("museum_items")
	found["hunts"] = player.progress.counter("hunts_done")
	var hearts : int = 0
	for id in player.progress.friends:
		hearts += Friendship.hearts(player.progress, id)
	found["hearts"] = hearts
	found["trails"] = player.progress.counter("trails")
	found["achievements"] = player.progress.counter("achievements")
	var total : int = 0
	for source in SOURCES:
		total += found.get(source[2], 0) * source[1]
	cachedCounts = found
	cachedXp = total
	return found

static func forget() -> void:
	cachedAt = -100000

static func xp(player : Player) -> int:
	counts(player)
	return cachedXp

static func level(player : Player) -> int:
	return floori(xp(player) / float(XP_PER_LEVEL)) if player and player.progress else 0

static func progress_in_level(player : Player) -> float:
	return fmod(float(xp(player)), XP_PER_LEVEL) / XP_PER_LEVEL

static func pouch_bonus(player : Player) -> int:
	return floori(level(player) / float(POUCH_EVERY))

static func crew_bonus(player : Player) -> int:
	return floori(level(player) / float(CREW_EVERY))

static func bonus(player : Player, stat : StringName) -> float:
	if stat == &"energyMax" and player and player.progress:
		return level(player) * ENERGY_PER_LEVEL
	return 0.0

# What reaching a level gives, for the menu.
static func rewards(at : int) -> PackedStringArray:
	var list : PackedStringArray = PackedStringArray(["+%d max energy" % roundi(ENERGY_PER_LEVEL)])
	if at % POUCH_EVERY == 0:
		list.append("+1 charm pouch slot")
	if at % CREW_EVERY == 0:
		list.append("+1 crew slot")
	return list
