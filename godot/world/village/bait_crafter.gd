@tool
extends Counter
class_name BaitCrafter

# A crafting station: the workbench, the kitchen, the forge, a cauldron. Using
# it opens the recipe book there, so its recipes can be made (see Recipes).
# Without a recipe book in the scene it falls back on the counter menu with
# its own recipes list.

#------------------------#
@export var recipes : Array[BaitRecipe] = []
@export var note : String = "Bait goes to the tacklebox"
@export var verb : String = "craft"
# Which station this is. Empty works it out from its recipes.
@export var station : StringName = &""
#------------------------#


func subtitle(_player : Player) -> String:
	return note

func work_station() -> StringName:
	if not station.is_empty():
		return station
	var counts : Dictionary = {}
	for recipe in recipes:
		if recipe:
			var kind : StringName = Recipes.station_of(recipe)
			counts[kind] = counts.get(kind, 0) + 1
	var best : StringName = Recipes.HAND
	for kind in counts:
		if counts[kind] > counts.get(best, 0):
			best = kind
	return best

func interact(player : Player) -> void:
	var book : RecipeBookUI = RecipeBookUI.find(get_tree())
	if book:
		book.open_at(work_station(), player)
	else:
		super(player)

static func tint_of(item : Item) -> Color:
	return (item as Tackle).icon_tint() if item is Tackle else Color.WHITE

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for recipe in recipes:
		if recipe and recipe.result():
			var made : Item = recipe.result()
			if not recipe.unlocked(player.progress):
				list.append({"value": recipe, "icon": made.icon, "tint": Color(0.2, 0.25, 0.32), "text": "???", "search": "", "detail": "Locked", "detailColor": Color(0.58, 0.67, 0.78), "dim": true})
				continue
			var craftable : bool = recipe.can_craft(player.inventory)
			list.append({"value": recipe, "icon": made.icon, "tint": tint_of(made), "text": made.displayName, "detail": "x%d" % recipe.amount, "detailColor": Color(0.56, 0.93, 0.44) if craftable else Color(0.58, 0.67, 0.78), "dim": not craftable})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var recipe : BaitRecipe = value as BaitRecipe
	if not recipe or not recipe.result():
		return {}
	var made : Item = recipe.result()
	if not recipe.unlocked(player.progress):
		return {"title": "Unknown recipe", "icon": made.icon, "tint": Color(0.2, 0.25, 0.32), "text": recipe.lockedText if not recipe.lockedText.is_empty() else "Not learned yet.", "lines": [], "action": "Locked", "enabled": false}
	var details : Dictionary = Counter.item_info(made)
	var lines : Array = [["Makes", "%d" % recipe.amount]]
	for i in recipe.ingredients.size():
		var have : int = recipe.have(i, player.inventory)
		var need : int = recipe.needed(i)
		lines.append([BaitRecipe.ingredient_name(recipe.ingredients[i]), "%d/%d" % [mini(have, need), need], Color(0.56, 0.93, 0.44) if have >= need else Color(0.95, 0.38, 0.34)])
	lines.append_array(details.lines)
	details.lines = lines
	var owned : int = player.tacklebox.count(made) if made is Tackle and player.tacklebox else player.inventory.count(made)
	if owned > 0:
		details.lines.append(["In tacklebox" if made is Tackle else "In bag", "%d" % owned])
	details.enabled = recipe.can_craft(player.inventory)
	details.action = verb.capitalize() if details.enabled else "Missing ingredients"
	return details

func choose(player : Player, value : Variant) -> String:
	var recipe : BaitRecipe = value as BaitRecipe
	if not recipe or not recipe.unlocked(player.progress):
		return ""
	if not recipe.can_craft(player.inventory):
		return fail("Missing ingredients")
	if not recipe.craft(player.inventory, player.tacklebox):
		return fail("No room in the bag")
	Quest.notify(player, &"craft", recipe.result(), recipe.amount)
	Skills.add(player, Skills.COOKING if recipe.result() is Snack else Skills.FISHING, recipe.xp)
	player.progress.count("crafted", recipe.amount)
	if recipe.result() is Snack:
		player.progress.count("meals_cooked", recipe.amount)
	return ok("Made %d %s!" % [recipe.amount, recipe.result().displayName])

func theme_name() -> String:
	return "recipes"
