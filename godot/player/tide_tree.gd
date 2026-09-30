extends RefCounted
class_name TideTree

# The Tide Tree (like SkyBlock's Heart of the Mountain): perks bought with
# Tide Tokens. Every Angler Level gives a token and some story moments give
# more. A node can be grown once a node it hangs from is, and most take
# several levels; the crown needs three branches grown all the way. Levels
# are saved as progress flags ("tide/<id>" = level).

const TOKEN_COLOR : Color = Color(0.45, 0.85, 0.95)
# id, name, stat, per level, max level, tokens per level, hangs from (any of),
# place on the tree (column 0-6, row 0-4 from the bottom), what it's about.
const NODES : Array = [
	["heart", "Tidecaller's Heart", &"biteSpeed", 2.0, 3, 1, [], Vector2i(3, 0), "Where every angler starts."],
	["swift_line", "Swift Line", &"biteSpeed", 3.0, 5, 1, ["heart"], Vector2i(1, 1), "Fish bite sooner."],
	["deep_luck", "Deep Luck", &"luck", 2.0, 5, 1, ["heart"], Vector2i(2, 1), "Rarer fish, more often."],
	["forager", "Forager", &"forageBonus", 10.0, 5, 1, ["heart"], Vector2i(4, 1), "More from every forage spot."],
	["haggler", "Haggler", &"sellBonus", 1.0, 5, 1, ["heart"], Vector2i(5, 1), "Better prices when you sell."],
	["double_hook", "Double Hook", &"doubleCatch", 1.0, 5, 1, ["swift_line"], Vector2i(0, 2), "Sometimes two fish at once."],
	["monster_lure", "Monster Lure", &"seaCreature", 0.5, 5, 1, ["swift_line", "deep_luck"], Vector2i(1, 2), "Sea creatures take the bait more."],
	["treasure_sense", "Treasure Sense", &"treasure", 0.3, 5, 1, ["deep_luck"], Vector2i(2, 2), "Treasure comes up more."],
	["green_hands", "Green Hands", &"harvestBonus", 5.0, 5, 1, ["forager"], Vector2i(4, 2), "Bigger harvests."],
	["artisan", "Artisan", &"craftBonus", 2.0, 5, 1, ["forager", "haggler"], Vector2i(5, 2), "Crafts sometimes make double."],
	["foreman", "Foreman", &"crewSpeed", 5.0, 5, 1, ["haggler"], Vector2i(6, 2), "Your crew works faster."],
	["trophy_eye", "Trophy Eye", &"trophyLuck", 6.0, 5, 2, ["double_hook", "monster_lure"], Vector2i(1, 3), "Better trophy fish tiers."],
	["scholar", "Scholar", &"xpBonus", 2.0, 5, 2, ["treasure_sense", "green_hands"], Vector2i(3, 3), "More skill XP from everything."],
	["brewer", "Brewer", &"potionPower", 10.0, 3, 2, ["artisan", "foreman"], Vector2i(5, 3), "Potions last longer."],
	["voyager", "Voyager", &"travelDiscount", 5.0, 3, 2, ["scholar"], Vector2i(2, 4), "Cheaper trips on the sea chart."],
	["crown", "Heart of the Sea", &"rareFind", 10.0, 1, 6, ["trophy_eye", "scholar", "brewer"], Vector2i(4, 4), "Rare finds everywhere. Needs three nodes grown all the way."],
]
# Tokens from story moments on top of Angler Levels: flag -> tokens.
const STORY_TOKENS : Dictionary = {"quest/q_four_tides": 2, "quest/q_truth": 2, "quest/q_seal": 3, "quest/q_festival": 5}

static var byId : Dictionary = {}
static var cacheAt : int = -100000
static var cached : Dictionary = {}


static func node(id : String) -> Array:
	if byId.is_empty():
		for each in NODES:
			byId[each[0]] = each
	return byId.get(id, [])

static func level(progress : Progress, id : String) -> int:
	return int(progress.get_flag("tide/" + id, 0))

static func earned(player : Player) -> int:
	var total : int = AnglerLevel.level(player)
	for flag in STORY_TOKENS:
		if player.progress.has_flag(flag):
			total += STORY_TOKENS[flag]
	return total

static func spent(progress : Progress) -> int:
	var total : int = 0
	for each in NODES:
		total += level(progress, each[0]) * int(each[5])
	return total

static func tokens(player : Player) -> int:
	return earned(player) - spent(player.progress)

static func maxed(progress : Progress, id : String) -> bool:
	return level(progress, id) >= int(node(id)[4])

static func reachable(progress : Progress, id : String) -> bool:
	var each : Array = node(id)
	if (each[6] as Array).is_empty():
		return true
	if id == "crown":
		var full : int = 0
		for other in NODES:
			if other[0] != "crown" and other[0] != "heart" and maxed(progress, other[0]):
				full += 1
		if full < 3:
			return false
	for parent in each[6]:
		if level(progress, parent) > 0:
			return true
	return false

# Why a node can't grow right now, or nothing.
static func blocked(player : Player, id : String) -> String:
	var each : Array = node(id)
	if maxed(player.progress, id):
		return "Fully grown"
	if not reachable(player.progress, id):
		return "Needs three nodes fully grown" if id == "crown" else "Grow a node below it first"
	if tokens(player) < int(each[5]):
		return "Needs %d Tide Token%s" % [each[5], "" if int(each[5]) == 1 else "s"]
	return ""

static func grow(player : Player, id : String) -> bool:
	if not blocked(player, id).is_empty():
		return false
	player.progress.set_flag("tide/" + id, level(player.progress, id) + 1)
	player.progress.count("tide_nodes")
	cacheAt = -100000
	return true

# What the tree adds to a stat, in the units Stats uses. Worked out at most
# every half second, since stats ask all the time.
static func bonus(player : Player, stat : StringName) -> float:
	if not player or not player.progress:
		return 0.0
	var now : int = Time.get_ticks_msec()
	if now - cacheAt > 500:
		cacheAt = now
		cached.clear()
		for each in NODES:
			var at : int = level(player.progress, each[0])
			if at > 0:
				cached[each[2]] = cached.get(each[2], 0.0) + at * float(each[3])
	return cached.get(stat, 0.0)
