extends RefCounted
class_name TrophyFishing

# Rolls trophy fish when a fish is landed (see TrophyFish): the tier comes
# from these odds, better with the Trophy tier luck stat, and a luck meter
# per fish makes a gold one certain after 100 catches without one and a
# diamond after 600. Counts the trophies for the lodge, the Angler Level and
# achievements.

const FOLDER : String = "res://world/trophy/fish"
const TIER_NAMES : PackedStringArray = ["Bronze", "Silver", "Gold", "Diamond"]
const TIER_COLORS : Array[Color] = [Color(0.85, 0.55, 0.3), Color(0.82, 0.86, 0.92), Color(1.0, 0.82, 0.3), Color(0.55, 0.95, 1.0)]
const SILVER : float = 0.25
const GOLD : float = 0.02
const DIAMOND : float = 0.002
const GOLD_PITY : int = 100
const DIAMOND_PITY : int = 600

static var cache : Array[TrophyFish] = []


static func all() -> Array[TrophyFish]:
	if cache.is_empty():
		for resource in Catalog.scan(FOLDER):
			if resource is TrophyFish:
				cache.append(resource)
		cache.sort_custom(func(a : TrophyFish, b : TrophyFish) -> bool: return a.chance > b.chance)
	return cache

# The tier to give (0 bronze to 3 diamond), moving the fish's luck meters.
static func roll_tier(player : Player, trophy : TrophyFish) -> int:
	var boost : float = 1.0 + player.stat(&"trophyLuck") * 0.01
	var pity : Dictionary = player.progress.pity
	var goldKey : String = "trophy/%s/gold" % trophy.key()
	var diamondKey : String = "trophy/%s/diamond" % trophy.key()
	var sinceGold : int = int(pity.get(goldKey, 0)) + 1
	var sinceDiamond : int = int(pity.get(diamondKey, 0)) + 1
	var tier : int = 0
	var pick : float = randf()
	if sinceDiamond >= DIAMOND_PITY or pick < DIAMOND * boost:
		tier = 3
	elif sinceGold >= GOLD_PITY or pick < GOLD * boost:
		tier = 2
	elif pick < SILVER * boost:
		tier = 1
	pity[goldKey] = 0 if tier >= 2 else sinceGold
	pity[diamondKey] = 0 if tier >= 3 else sinceDiamond
	return tier

# After a fish is landed: maybe a trophy comes up too. Returns the item, or
# null.
static func roll(player : Player, context : FishingContext, where : Biome) -> Item:
	var rod : RodItem = null
	var held : FishingRod = player.heldItem as FishingRod
	if held:
		rod = held.item as RodItem
	for trophy in all():
		if trophy.tiers.size() < 4 or not trophy.can_bite(context, where, rod):
			continue
		if randf() >= trophy.chance:
			continue
		var tier : int = roll_tier(player, trophy)
		var item : Item = trophy.tiers[tier]
		if not Counter.fits(player, item, 1):
			return null
		Counter.deliver(player, item, 1)
		var progress : Progress = player.progress
		progress.count("trophy_caught")
		if tier >= 2:
			progress.count("trophy_gold")
		if tier >= 3:
			progress.count("trophy_diamond")
		var flag : String = "trophy/%s/%d" % [trophy.key(), tier]
		if not progress.has_flag(flag):
			progress.set_flag(flag)
			if not progress.has_flag("trophy/" + trophy.key()):
				progress.set_flag("trophy/" + trophy.key())
				progress.count("trophy_kinds")
			AnglerLevel.forget()
		Achievements.notify(player, &"trophy", trophy, tier)
		Features.introduce(player, "trophies")
		var board : NoticeBoard = NoticeBoard.find(player.get_tree())
		if board:
			board.post("TROPHY! %s %s" % [TIER_NAMES[tier], trophy.displayName], "Odette at the Trophy Lodge will want to see this.", TIER_COLORS[tier], item.icon)
		return item
	return null

# How many (fish, tier) pairs have been caught, for the lodge's level.
static func tiers_caught(progress : Progress) -> int:
	var count : int = 0
	for trophy in all():
		for tier in 4:
			if progress.has_flag("trophy/%s/%d" % [trophy.key(), tier]):
				count += 1
	return count

static func best_tier(progress : Progress, trophy : TrophyFish) -> int:
	for tier in range(3, -1, -1):
		if progress.has_flag("trophy/%s/%d" % [trophy.key(), tier]):
			return tier
	return -1
