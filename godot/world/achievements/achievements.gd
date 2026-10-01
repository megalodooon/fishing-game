extends RefCounted
class_name Achievements

# Everything worth a trophy, in one table (LIST), each with the name its
# Steam achievement will use ("ACH_" + id in capitals). They're checked when
# something happens (Quest.notify passes every event on) and every so often
# while playing, at most once a second, and unlocked ones are saved as
# progress flags ("ach/<id>" = the day). When GodotSteam's "Steam" singleton
# is there, unlocks are passed on to Steam too. The Skills menu has a page
# for them.

const TIER_COLORS : Array[Color] = [Color(0.85, 0.55, 0.3), Color(0.82, 0.86, 0.92), Color(1.0, 0.82, 0.3)]
const TIER_NAMES : PackedStringArray = ["Bronze", "Silver", "Gold"]
const ICONS : Array[Texture2D] = [preload("res://world/achievements/icons/bronze.png"), preload("res://world/achievements/icons/silver.png"), preload("res://world/achievements/icons/gold.png")]
const LOCKED_ICON : Texture2D = preload("res://world/achievements/icons/locked.png")
const CHECK_EVERY_MS : int = 1000
# id, name, description, group, tier (0 bronze, 1 silver, 2 gold), hidden
# until unlocked, condition kind, value, second value.
const LIST : Array = [
	["first_catch", "First Bite", "Catch your first fish.", "Fishing", 0, false, "counter", "fish_caught", 1],
	["fish_100", "Hooked", "Catch 100 fish.", "Fishing", 0, false, "counter", "fish_caught", 100],
	["fish_1000", "Old Salt", "Catch 1,000 fish.", "Fishing", 1, false, "counter", "fish_caught", 1000],
	["fish_5000", "Living Legend", "Catch 5,000 fish.", "Fishing", 2, false, "counter", "fish_caught", 5000],
	["species_25", "Naturalist", "Find 25 kinds of fish.", "Fishing", 0, false, "species", 25, 0],
	["species_100", "Marine Biologist", "Find 100 kinds of fish.", "Fishing", 1, false, "species", 100, 0],
	["species_all", "Every Fish in the Sea", "Find every kind of fish.", "Fishing", 2, false, "species_all", 0, 0],
	["giant", "That's a Big One", "Catch a giant fish.", "Fishing", 0, false, "counter", "variant_giant", 1],
	["shiny", "Shimmer", "Catch a shiny fish.", "Fishing", 1, false, "counter", "variant_shiny", 1],
	["golden", "Midas Touch", "Catch a golden fish.", "Fishing", 2, false, "counter", "variant_golden", 1],
	["treasure_1", "X Marks the Spot", "Fish up a treasure chest.", "Fishing", 0, false, "counter", "treasure_found", 1],
	["treasure_50", "Treasure Hunter", "Fish up 50 treasure chests.", "Fishing", 1, false, "counter", "treasure_found", 50],
	["rare_1", "Lucky Find", "Get your first rare catch.", "Fishing", 0, false, "counter", "rare_drops", 1],
	["rare_all", "Beyond Luck", "Find every rare catch.", "Fishing", 2, false, "rares_all", 0, 0],
	["trophy_first", "Trophy Angler", "Catch your first trophy fish.", "Trophies", 0, false, "counter", "trophy_caught", 1],
	["trophy_gold", "Gold Standard", "Catch a gold trophy fish.", "Trophies", 1, false, "counter", "trophy_gold", 1],
	["trophy_diamond", "Flawless", "Catch a diamond trophy fish.", "Trophies", 2, false, "counter", "trophy_diamond", 1],
	["trophy_all", "Hall of Trophies", "Catch every trophy fish.", "Trophies", 2, false, "counter", "trophy_kinds", 13],
	["creature_1", "Sea Monster", "Beat your first sea creature.", "Hunting", 0, false, "counter", "creatures", 1],
	["creature_100", "Monster Hunter", "Beat 100 sea creatures.", "Hunting", 1, false, "counter", "creatures", 100],
	["bestiary_all", "Bestiary Complete", "Beat every kind of sea creature.", "Hunting", 2, false, "bestiary_all", 0, 0],
	["hunt_1", "Bounty Taken", "Finish a sea hunt.", "Hunting", 0, false, "counter", "hunts_done", 1],
	["hunt_boss", "Apex Predator", "Beat a tier IV hunt boss.", "Hunting", 1, false, "counter", "hunt_boss_4", 1],
	["hunt_25", "Scourge of the Deep", "Finish 25 sea hunts.", "Hunting", 2, false, "counter", "hunts_done", 25],
	["skill_10", "Getting Good", "Reach level 10 in a skill.", "Skills", 0, false, "any_skill", 10, 0],
	["skill_25", "Expert", "Reach level 25 in a skill.", "Skills", 1, false, "any_skill", 25, 0],
	["skill_50", "Master", "Reach level 50 in a skill.", "Skills", 2, false, "any_skill", 50, 0],
	["skills_all_10", "Jack of All Trades", "Reach level 10 in every skill.", "Skills", 1, false, "all_skills", 10, 0],
	["skills_all_25", "Renaissance Angler", "Reach level 25 in every skill.", "Skills", 2, false, "all_skills", 25, 0],
	["angler_10", "Rising Star", "Reach Angler Level 10.", "Skills", 0, false, "angler", 10, 0],
	["angler_30", "Seasoned", "Reach Angler Level 30.", "Skills", 1, false, "angler", 30, 0],
	["angler_60", "Legend of the Coast", "Reach Angler Level 60.", "Skills", 2, false, "angler", 60, 0],
	["tide_5", "Taking Root", "Grow 5 nodes on the Tide Tree.", "Skills", 0, false, "counter", "tide_nodes", 5],
	["tide_all", "Full Bloom", "Grow every node on the Tide Tree.", "Skills", 2, false, "tide_all", 0, 0],
	["chapter_2", "The Hermit's Secret", "Meet Old Silas.", "Story", 0, false, "chapter", 1, 0],
	["chapter_4", "Deep Trouble", "Win the Village Cup.", "Story", 0, false, "chapter", 3, 0],
	["chapter_6", "Frost and Fire", "Learn of the Four Tides.", "Story", 1, false, "chapter", 5, 0],
	["chapter_8", "The Rig", "Learn the truth about the storm.", "Story", 1, false, "chapter", 7, 0],
	["chapter_11", "Champion of the Seas", "Finish the story.", "Story", 2, false, "chapter", 10, 0],
	["quests_10", "Helping Hand", "Finish 10 quests.", "Story", 0, false, "quests", 10, 0],
	["quests_60", "Pillar of the Village", "Finish 60 quests.", "Story", 1, false, "quests", 60, 0],
	["quests_all", "Nothing Left Undone", "Finish every quest.", "Story", 2, false, "quests_all", 0, 0],
	["friend_1", "Friendly Face", "Reach 2 hearts with someone.", "Friends", 0, false, "hearts", 2, 1],
	["friend_5", "Part of the Village", "Reach 5 hearts with 5 villagers.", "Friends", 1, false, "hearts", 5, 5],
	["best_friend", "Best Friends", "Reach 10 hearts with someone.", "Friends", 1, false, "hearts", 10, 1],
	["friends_all", "Beloved", "Reach 8 hearts with 12 villagers.", "Friends", 2, false, "hearts", 8, 12],
	["gifts_50", "Thoughtful", "Give 50 gifts.", "Friends", 0, false, "counter", "gifts", 50],
	["gifts_loved", "Just What I Wanted", "Give 25 gifts someone loves.", "Friends", 1, false, "counter", "gifts_loved", 25],
	["harvest_100", "Green Thumb", "Harvest 100 crops.", "Farming", 0, false, "counter", "harvests", 100],
	["harvest_1000", "Breadbasket", "Harvest 1,000 crops.", "Farming", 1, false, "counter", "harvests", 1000],
	["medal_gold", "Blue Ribbon", "Win a gold medal at a contest.", "Farming", 1, false, "counter", "medal_gold", 1],
	["medals_25", "Contest Regular", "Win 25 contest medals.", "Farming", 2, false, "counter", "contests_medalled", 25],
	["forage_100", "Beachcomber", "Gather 100 things from forage spots.", "Foraging", 0, false, "counter", "forage", 100],
	["forage_2000", "Living off the Land", "Gather 2,000 things from forage spots.", "Foraging", 2, false, "counter", "forage", 2000],
	["dig_1", "Dig Dig Dig", "Dig up your first buried treasure.", "Foraging", 0, false, "counter", "digs", 1],
	["dig_100", "Mole", "Dig up 100 buried things.", "Foraging", 1, false, "counter", "digs", 100],
	["dig_legend", "Motherlode", "Dig up a legendary treasure.", "Foraging", 2, false, "counter", "dig_legendary", 1],
	["craft_100", "Tinkerer", "Craft 100 things.", "Crafting", 0, false, "counter", "crafted", 100],
	["craft_2000", "Workshop", "Craft 2,000 things.", "Crafting", 1, false, "counter", "crafted", 2000],
	["meals_50", "Well Fed", "Eat 50 meals.", "Crafting", 0, false, "counter", "meals", 50],
	["enchant_1", "Spark", "Enchant a rod.", "Crafting", 0, false, "counter", "enchants", 1],
	["enchant_max", "Arcane Angler", "Put a level V enchantment on a rod.", "Crafting", 2, false, "counter", "enchant_max", 1],
	["crew_1", "First Mate", "Hire a crew member.", "Economy", 0, false, "crew", 1, 0],
	["crew_full", "Full Crew", "Have 8 crew members working.", "Economy", 1, false, "crew", 8, 0],
	["crew_tier_7", "Veteran Crew", "Train a crew member to tier VII.", "Economy", 2, false, "crew_tier", 7, 0],
	["coins_10k", "Nest Egg", "Earn 10,000 coins from sales.", "Economy", 0, false, "counter", "coins_earned", 10000],
	["coins_250k", "Tycoon", "Earn 250,000 coins from sales.", "Economy", 1, false, "counter", "coins_earned", 250000],
	["coins_2m", "Harbor Baron", "Earn 2,000,000 coins from sales.", "Economy", 2, false, "counter", "coins_earned", 2000000],
	["bank_open", "Savings Account", "Open an account at the harbor bank.", "Economy", 0, false, "flag", "bank/open", 0],
	["bank_100k", "Money in the Bank", "Have 100,000 coins in the bank.", "Economy", 1, false, "bank", 100000, 0],
	["vault_max", "Vault Keeper", "Upgrade the vault all the way.", "Economy", 2, false, "flag", "bank/vault_max", 0],
	["power_50", "Trinket Collector", "Reach 50 Magical Power.", "Economy", 0, false, "power", 50, 0],
	["power_250", "Overflowing Pouch", "Reach 250 Magical Power.", "Economy", 2, false, "power", 250, 0],
	["vote", "Civic Duty", "Vote in a council election.", "Economy", 0, false, "counter", "votes", 1],
	["museum_10", "Patron", "Donate 10 things to the museum.", "Collections", 0, false, "counter", "museum_items", 10],
	["museum_80", "Curator's Friend", "Donate 80 things to the museum.", "Collections", 2, false, "counter", "museum_items", 80],
	["tiers_100", "Collector", "Reach 100 collection tiers.", "Collections", 1, false, "tiers", 100, 0],
	["complete_50", "Halfway There", "Reach 50% completion.", "Collections", 1, false, "completion", 50, 0],
	["complete_100", "Perfectionist", "Reach 100% completion.", "Collections", 2, false, "completion", 100, 0],
	["pearls_all", "Pearl Diver", "Find every lost pearl.", "Collections", 1, false, "pearls_all", 0, 0],
	["places_all", "Charted Every Sea", "Chart every place on the map.", "Collections", 1, false, "places_all", 0, 0],
	["festivals_4", "Festive", "Join all four festivals.", "Collections", 1, false, "festivals", 4, 0],
	["night_owl", "Night Owl", "Catch a fish between 3:00 and 4:00.", "Secrets", 0, true, "flag", "ach_night_owl", 0],
	["boot_collector", "Sole Survivor", "Fish up 50 old boots.", "Secrets", 0, true, "counter", "boots", 50],
	["broke", "Down to the Last Coin", "Spend down to fewer than 5 coins after earning 1,000.", "Secrets", 0, true, "flag", "ach_broke", 0],
]

static var lastCheck : int = -100000
static var cursor : int = -1
const SLICE : int = 12
static var byId : Dictionary = {}


static func key(id : String) -> String:
	return "ach/" + id

static func unlocked(progress : Progress, id : String) -> bool:
	return progress.has_flag(key(id))

static func steam_name(id : String) -> String:
	return "ACH_" + id.to_upper()

static func count_unlocked(progress : Progress) -> int:
	var count : int = 0
	for each in LIST:
		if unlocked(progress, each[0]):
			count += 1
	return count

static func groups() -> PackedStringArray:
	var list : PackedStringArray = PackedStringArray()
	for each in LIST:
		if not list.has(each[3]):
			list.append(each[3])
	return list

# Something happened. Some things unlock right away; everything else is
# checked at most once a second.
static func notify(player : Player, event : StringName, data : Variant = null, _extra : Variant = null) -> void:
	if not player or not player.progress:
		return
	if event == &"catch" and data is Fish:
		var cycle : DayNightCycle = DayNightCycle.find(player.get_tree())
		if cycle and cycle.time >= 3.0 and cycle.time < 4.0:
			player.progress.set_flag("ach_night_owl")
		if (data as Fish).species and (data as Fish).species.resource_path.ends_with("old_boot.tres"):
			player.progress.count("boots")
	check(player)

# Checks a slice of the list each time (all of it when forced), so it never
# costs more than a fraction of a millisecond.
static func check(player : Player, force : bool = false) -> void:
	var now : int = Time.get_ticks_msec()
	if not force and now - lastCheck < CHECK_EVERY_MS:
		return
	lastCheck = now
	var count : int = LIST.size() if force else SLICE
	for i in count:
		cursor = (cursor + 1) % LIST.size()
		var each : Array = LIST[cursor]
		if not unlocked(player.progress, each[0]) and met(player, each):
			unlock(player, each)

static func met(player : Player, each : Array) -> bool:
	var progress : Progress = player.progress
	var value : Variant = each[7]
	var other : Variant = each[8]
	match each[6]:
		"counter":
			return progress.counter(value) >= int(other)
		"flag":
			return progress.has_flag(value)
		"species":
			return player.journal.caught.size() >= int(value)
		"species_all":
			return player.journal.caught.size() >= Catalog.fish().size()
		"rares_all":
			for drop in RareDrops.all():
				if not progress.collected.has(drop.item):
					return false
			return true
		"bestiary_all":
			for creature in Catalog.creatures():
				if not progress.bestiary.has(creature):
					return false
			return true
		"any_skill":
			for skill in Skills.LIST:
				if Skills.level(player, skill) >= int(value):
					return true
			return false
		"all_skills":
			for skill in Skills.LIST:
				if Skills.level(player, skill) < int(value):
					return false
			return true
		"angler":
			return AnglerLevel.level(player) >= int(value)
		"tide_all":
			return progress.counter("tide_nodes") >= TideTree.NODES.size()
		"chapter":
			return progress.chapter >= int(value)
		"quests":
			return done_quests(progress) >= int(value)
		"quests_all":
			return done_quests(progress) >= Catalog.quests().size()
		"hearts":
			return Friendship.count_at(progress, int(value)) >= int(other)
		"crew":
			return progress.crew.size() >= int(value)
		"crew_tier":
			for flag in progress.flags:
				if String(flag).begins_with("crew_tier/") and String(flag).ends_with("/%d" % int(value)):
					return true
			return false
		"bank":
			return Bank.coins(progress) >= int(value)
		"power":
			return Equipment.magical_power(player) >= int(value)
		"tiers":
			var tiers : int = 0
			for thing in progress.collectionTiers:
				tiers += progress.collectionTiers[thing]
			return tiers >= int(value)
		"completion":
			return Collections.completion(player) >= float(value)
		"pearls_all":
			return Pearls.found(progress) >= Pearls.TOTAL
		"places_all":
			return player.atlas.unlocked.size() >= player.atlas.locations.size()
		"festivals":
			var seen : int = 0
			for event in GameEvent.all():
				if event.is_festival() and progress.has_flag("festival_seen/" + event.key()):
					seen += 1
			return seen >= int(value)
	return false

static func done_quests(progress : Progress) -> int:
	var done : int = 0
	for quest in progress.quests:
		if progress.quests[quest].done:
			done += 1
	return done

static func unlock(player : Player, each : Array) -> void:
	var cycle : DayNightCycle = DayNightCycle.find(player.get_tree())
	player.progress.set_flag(key(each[0]), cycle.day if cycle else 1)
	player.progress.count("achievements")
	steam_unlock(each[0])
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if board:
		board.post("Achievement: %s" % each[1], each[2], TIER_COLORS[each[4]], ICONS[each[4]])

static func steam_unlock(id : String) -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam : Object = Engine.get_singleton("Steam")
	steam.call("setAchievement", steam_name(id))
	steam.call("storeStats")

# Passes every unlocked achievement on to Steam, like after loading a save.
static func sync_steam(progress : Progress) -> void:
	if not Engine.has_singleton("Steam"):
		return
	for each in LIST:
		if unlocked(progress, each[0]):
			steam_unlock(each[0])
