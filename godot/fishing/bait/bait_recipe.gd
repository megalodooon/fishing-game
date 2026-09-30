extends Resource
class_name BaitRecipe

# What a crafter (the bait crafter, the smokehouse kitchen) makes. An
# ingredient is an Item (that item), a FishData (a fish of that species) or a
# Rarity (any fish of that rarity), with the count at the same index in counts.
# Bait and other tackle go into the tacklebox, everything else into the bag.

#------------------------#
@export var bait : Tackle
# Made instead of bait when set, like a cooked meal.
@export var output : Item
@export var amount : int = 5
@export var ingredients : Array[Resource] = []
@export var counts : Array[int] = []
# Only shown (as ???) until this progress flag is set, like a collection tier.
@export var requiredFlag : String = ""
@export var lockedText : String = ""
# Skill XP for making it: cooking for meals, trading for the rest.
@export var xp : float = 5.0
# Where it's made (see Recipes.STATIONS). Hand recipes are made anywhere
# from the recipe book, the rest at their station or with its portable kit.
@export var station : StringName = &""
# The recipe book's tab. Empty picks one from what it makes.
@export var category : String = ""
# A skill level needed to learn it, on top of the flag.
@export var requiredSkill : StringName = &""
@export var requiredLevel : int = 0
#------------------------#


func unlocked(progress : Progress) -> bool:
	return (requiredFlag.is_empty() or (progress != null and progress.has_flag(requiredFlag))) and Unlocks.skill_met(progress, requiredSkill, requiredLevel)

func result() -> Item:
	return output if output else bait

func needed(index : int) -> int:
	return counts[index] if index < counts.size() else 1

func fits(ingredient : Resource, item : Item) -> bool:
	if ingredient is Item:
		return item.same_kind(ingredient)
	if item is Fish:
		return (item as Fish).species == ingredient or (ingredient is Rarity and item.rarity == ingredient)
	return false

func tester(ingredient : Resource) -> Callable:
	return func(item : Item) -> bool: return fits(ingredient, item)

func have(index : int, inventory : Inventory) -> int:
	return inventory.count_where(tester(ingredients[index]))

func can_craft(inventory : Inventory) -> bool:
	for i in ingredients.size():
		if have(i, inventory) < needed(i):
			return false
	return result() != null

func craft(inventory : Inventory, box : Tacklebox) -> bool:
	if not can_craft(inventory):
		return false
	var tackle : Tackle = result() as Tackle
	if not tackle and inventory.room_for(output) < amount:
		return false
	for i in ingredients.size():
		inventory.take_where(tester(ingredients[i]), needed(i))
	if tackle:
		box.add(tackle, amount)
	else:
		inventory.give(output, amount)
	return true

static func ingredient_name(ingredient : Resource) -> String:
	if ingredient is Item:
		return (ingredient as Item).displayName
	if ingredient is FishData:
		return (ingredient as FishData).displayName
	if ingredient is Rarity:
		return "Any %s fish" % (ingredient as Rarity).displayName.to_lower()
	return "?"

static func ingredient_icon(ingredient : Resource) -> Texture2D:
	if ingredient is Item:
		return (ingredient as Item).icon
	if ingredient is FishData:
		return (ingredient as FishData).icon
	return null
