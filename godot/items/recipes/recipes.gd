extends RefCounted
class_name Recipes

# The crafting rules every recipe shares. Each recipe is made at a station:
# hand recipes anywhere from the recipe book (R), the rest at their station
# in the world (the workbench, the kitchen, the forge, the cauldron), or
# anywhere once the station's portable kit is in the bag. Recipes are learned
# from collection tiers, skill levels and quests, and the book says which.

const HAND : StringName = &""
const WORKBENCH : StringName = &"workbench"
const KITCHEN : StringName = &"kitchen"
const FORGE : StringName = &"forge"
const CAULDRON : StringName = &"cauldron"
# Name, where it is and its icon, per station. The icons are preloaded:
# textures first loaded while a menu draws come out white.
const STATIONS : Dictionary = {
	HAND: ["By hand", "Anywhere", preload("res://ui/hub/icons/station_hand.png")],
	WORKBENCH: ["Workbench", "Your house, Bramblewick", preload("res://ui/hub/icons/station_workbench.png")],
	KITCHEN: ["Kitchen", "Smokehouse, Bramblewick", preload("res://ui/hub/icons/station_kitchen.png")],
	FORGE: ["Forge", "Brann's forge, Ember Isle", preload("res://ui/hub/icons/station_forge.png")],
	CAULDRON: ["Cauldron", "Auntie Moss, Mangrove Hollow", preload("res://ui/hub/icons/station_cauldron.png")],
}
# Carrying one of these works like standing at its station.
const KITS : Dictionary = {
	WORKBENCH: "res://items/tools/tinkers_kit.tres",
	KITCHEN: "res://items/tools/camp_stove.tres",
	FORGE: "res://items/tools/field_anvil.tres",
	CAULDRON: "res://items/tools/travel_cauldron.tres",
}
# The recipe book's tabs, in order.
const CATEGORIES : PackedStringArray = ["Bait", "Tackle", "Rods", "Charms", "Traps", "Tools", "Crew", "Food", "Potions", "Materials"]
const MAX_BATCH : int = 99

# How many recipes use each item, for tooltips.
static var uses : Dictionary = {}


static func station_of(recipe : BaitRecipe) -> StringName:
	if not recipe.station.is_empty():
		return recipe.station
	if recipe.resource_path.begins_with("res://items/snacks/"):
		return KITCHEN
	return HAND

static func station_name(station : StringName) -> String:
	return STATIONS.get(station, [String(station).capitalize()])[0]

static func station_place(station : StringName) -> String:
	return STATIONS.get(station, ["", ""])[1]

static func station_icon(station : StringName) -> Texture2D:
	return STATIONS.get(station, ["", "", null])[2]

static func category_of(recipe : BaitRecipe) -> String:
	if not recipe.category.is_empty():
		return recipe.category
	var made : Item = recipe.result()
	if made is Bait:
		return "Bait"
	if made is Tackle:
		return "Tackle"
	if made is RodItem:
		return "Rods"
	if made is Charm:
		return "Charms"
	if made is CrabPot:
		return "Traps"
	if made is CrewContract:
		return "Crew"
	if made and made.category == "Potion":
		return "Potions"
	if made is Snack:
		return "Food"
	if made and made.category == "Tool":
		return "Tools"
	return "Materials"

static func kit(station : StringName) -> Item:
	var path : String = KITS.get(station, "")
	return load(path) as Item if not path.is_empty() and ResourceLoader.exists(path) else null

# Whether the player can make station recipes right now: at the station, or
# carrying its kit.
static func can_use(player : Player, station : StringName, at : StringName) -> bool:
	if station == HAND or station == at:
		return true
	var tool : Item = kit(station)
	return tool != null and player.inventory.count(tool) > 0

# How many times the recipe can be made from what's in the bag.
static func batches(player : Player, recipe : BaitRecipe) -> int:
	var most : int = MAX_BATCH
	for i in recipe.ingredients.size():
		most = mini(most, floori(recipe.have(i, player.inventory) / float(maxi(recipe.needed(i), 1))))
	return most

# Makes it up to times over. Returns how many were made.
static func craft(player : Player, recipe : BaitRecipe, times : int) -> int:
	var made : int = 0
	for i in times:
		if not recipe.can_craft(player.inventory) or not recipe.craft(player.inventory, player.tacklebox):
			break
		made += 1
	if made > 0:
		var result : Item = recipe.result()
		# The Crafting perk sometimes makes an extra batch for free.
		var extra : int = 0
		for i in made:
			if randf() * 100.0 < player.stat(&"craftBonus"):
				extra += 1
		if extra > 0:
			if result is Tackle:
				player.tacklebox.add(result, recipe.amount * extra)
			else:
				player.inventory.give(result, recipe.amount * extra)
			player.say("Double craft!", Color(0.56, 0.93, 0.44))
		Quest.notify(player, &"craft", result, recipe.amount * made)
		# Artisan, fully grown: double crafting XP.
		Skills.add(player, skill_for(result), recipe.xp * made * (2.0 if TideTree.has(player, "artisan") else 1.0))
		player.progress.count("crafted", recipe.amount * made)
		if result is Snack:
			player.progress.count("meals_cooked", recipe.amount * made)
		player.progress.set_flag("crafted/" + recipe.resource_path.get_file().get_basename())
	return made

# The skill a craft trains: cooking for food, alchemy for potions, crafting
# for everything else.
static func skill_for(result : Item) -> StringName:
	if result and result.category == "Potion":
		return Skills.ALCHEMY
	if result is Snack:
		return Skills.COOKING
	return Skills.CRAFTING

# How the recipe is learned, for locked ones.
static func unlock_text(recipe : BaitRecipe, progress : Progress) -> String:
	if not recipe.lockedText.is_empty() and not recipe.requiredFlag.is_empty() and not (progress and progress.has_flag(recipe.requiredFlag)):
		return recipe.lockedText
	var parts : PackedStringArray = PackedStringArray()
	if not recipe.requiredFlag.is_empty() and not (progress and progress.has_flag(recipe.requiredFlag)):
		parts.append(flag_text(recipe.requiredFlag))
	if not Unlocks.skill_met(progress, recipe.requiredSkill, recipe.requiredLevel):
		parts.append("Reach %s %d" % [Skills.NAMES.get(recipe.requiredSkill, String(recipe.requiredSkill)), recipe.requiredLevel])
	return ". ".join(parts) + "." if not parts.is_empty() else "Not learned yet."

# A progress flag in words, like "Frost Crystal collection III".
static func flag_text(flag : String) -> String:
	var parts : PackedStringArray = flag.split("/")
	if parts.size() == 3 and parts[0] == "collection":
		for thing in Catalog.things():
			if thing.resource_path.get_file().get_basename() == parts[1]:
				return "%s collection %s" % [Collections.name_of(thing), Unlocks.roman(int(parts[2]))]
		return "%s collection %s" % [parts[1].capitalize(), Unlocks.roman(int(parts[2]))]
	if parts.size() == 2 and parts[0] == "quest":
		for quest in Catalog.quests():
			if quest.key() == flag:
				return "Finish \"%s\"" % quest.title
	if parts.size() == 2 and parts[0] == "league":
		return "Win the %s" % Unlocks.LEAGUES[clampi(int(parts[1]) - 1, 0, Unlocks.LEAGUES.size() - 1)]
	if parts.size() == 2 and parts[0] == "project":
		for project in Catalog.projects():
			if project.key() == flag:
				return "Restore the %s" % project.displayName
	if parts.size() >= 2 and parts[0] == "event":
		return "During %s" % parts[1].capitalize()
	return "Something first"

# How many recipes an item goes into.
static func used_in(item : Item) -> int:
	if uses.is_empty():
		for recipe in Catalog.recipes():
			for ingredient in recipe.ingredients:
				if ingredient is Item:
					uses[ingredient] = uses.get(ingredient, 0) + 1
		uses[null] = 0
	return uses.get(item.original(), 0) if item else 0
