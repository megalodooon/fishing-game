extends RefCounted
class_name SkillRewards

# What each skill level brings, gathered from the content itself: places,
# recipes, quests, shop stock and village projects waiting for that level, sea
# creatures and rare catches that start showing up, extra hearts, plus the
# coins every level pays. The skills menu shows it as a track, so the next
# goal is always in sight. New content with a requiredSkill shows up here on
# its own.

const PLACE : Texture2D = preload("res://ui/hub/icons/unlock_place.png")
const RECIPE : Texture2D = preload("res://ui/hub/icons/unlock_recipe.png")
const SHOP : Texture2D = preload("res://ui/hub/icons/unlock_shop.png")
const PERK : Texture2D = preload("res://ui/hub/icons/unlock_perk.png")
const HEART : Texture2D = preload("res://ui/hub/icons/unlock_heart.png")
const FISH : Texture2D = preload("res://ui/hub/icons/unlock_fish.png")
# Coins paid for reaching a level: this times the level.
const COINS_PER_LEVEL : int = 8

# Per skill: level -> Array of [icon, text].
static var tracks : Dictionary = {}
# Per skill: its milestone levels, sorted once.
static var sorted : Dictionary = {}
static var built : bool = false


static func at(skill : StringName, level : int) -> Array:
	build()
	return tracks.get(skill, {}).get(level, [])

# The levels with something besides perks and coins, in order.
static func milestones(skill : StringName) -> Array[int]:
	build()
	if not sorted.has(skill):
		var list : Array[int] = []
		list.assign(tracks.get(skill, {}).keys())
		list.sort()
		sorted[skill] = list
	return sorted[skill]

static func add(skill : StringName, level : int, icon : Texture2D, text : String) -> void:
	if skill.is_empty() or level <= 1:
		return
	if not tracks.has(skill):
		tracks[skill] = {}
	if not tracks[skill].has(level):
		tracks[skill][level] = []
	tracks[skill][level].append([icon, text])

static func build() -> void:
	if built:
		return
	built = true
	for location in Catalog.locations():
		add(location.requiredSkill, location.requiredLevel, PLACE, "Sail to %s" % location.displayName)
	for recipe in Catalog.recipes():
		if recipe.result():
			add(recipe.requiredSkill, recipe.requiredLevel, RECIPE, "Recipe: %s" % recipe.result().displayName)
	for quest in Catalog.quests():
		add(quest.requiredSkill, quest.requiredLevel, PERK, "Quest: %s" % quest.title)
	for project in Catalog.projects():
		add(project.requiredSkill, project.requiredLevel, SHOP, "Restore: %s" % project.displayName)
	for stock in ShopStock.all():
		for offer in stock.offers:
			if offer and offer.item:
				add(offer.requiredSkill, offer.requiredLevel, SHOP, "%s sells %s" % [stock.shopName, offer.item.displayName])
	for creature in Catalog.creatures():
		add(Skills.FISHING, creature.minFishing, HEART, "Sea creature: %s" % creature.displayName)
	for drop in RareDrops.all():
		add(Skills.FISHING, drop.minFishing, FISH, "Rare catch: %s" % drop.item.displayName)
	for at_level in Skills.HEART_LEVELS:
		add(Skills.HUNTING, at_level, HEART, "+1 heart in fights")

# Everything a level gives, perks and coins included, for tooltips.
static func lines(skill : StringName, level : int) -> PackedStringArray:
	var list : PackedStringArray = PackedStringArray()
	for perk in Skills.PERKS.get(skill, []):
		list.append(Stats.perk_line(perk[0], perk[1]))
	list.append("+$%d" % (COINS_PER_LEVEL * level))
	for reward in at(skill, level):
		list.append(reward[1])
	return list
