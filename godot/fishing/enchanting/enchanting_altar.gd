@tool
extends Counter
class_name EnchantingAltar

# The enchanting altar (see Enchanting): lists every enchantment for the rod
# in hand, its level on that rod and what the next level costs. Picking one
# puts the next level on.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)


func intro_id() -> String:
	return "enchanting"

func theme_name() -> String:
	return "glass"

func searchable() -> bool:
	return false

# The rod in hand, made its own copy first so enchanting never touches the
# shared original.
func rod(player : Player) -> RodItem:
	var held : RodItem = Enchanting.held_rod(player)
	if not held:
		return null
	if held == held.original() and player.heldSlot >= 0:
		var copy : RodItem = held.unique() as RodItem
		player.inventory.items[player.heldSlot] = copy
		(player.heldItem as FishingRod).item = copy
		player.inventory.emit_changed()
		held = copy
	return held

func subtitle(player : Player) -> String:
	var held : RodItem = Enchanting.held_rod(player)
	var essence : Item = load(Enchanting.ESSENCE) as Item
	var have : int = player.inventory.count(essence) if essence else 0
	return "%s. %d Sea Essence" % ["Enchanting your " + held.displayName if held else "Hold a rod to enchant it", have]

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var held : RodItem = Enchanting.held_rod(player)
	if not held:
		return list
	for each in Enchanting.LIST:
		var at : int = Enchanting.level(held, each[0])
		var why : String = Enchanting.blocked(player, held, each[0])
		list.append({"value": each[0], "text": "%s %s" % [each[1], Enchanting.ROMAN[at]] if at > 0 else each[1], "detail": "MAX" if at >= int(each[4]) else "%d" % Enchanting.ESSENCE_COST[at + 1], "detailColor": Enchanting.COLOR if why.is_empty() else DIM, "marked": at > 0, "markColor": Enchanting.COLOR, "dim": not why.is_empty()})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var held : RodItem = Enchanting.held_rod(player)
	if not held or not value is String:
		return {"title": "The altar hums", "text": "Hold the rod you want to enchant, then come back. Sea Essence comes from sea creatures, sea hunts, buried treasure and the museum."}
	var each : Array = Enchanting.entry(value)
	var at : int = Enchanting.level(held, value)
	var lines : Array = [["Now", Stats.bonus_text(each[2], float(each[3]) * at) if at > 0 else "-"]]
	if at < int(each[4]):
		var next : int = at + 1
		var essence : Item = load(Enchanting.ESSENCE) as Item
		lines.append(["Level %s" % Enchanting.ROMAN[next], Stats.bonus_text(each[2], float(each[3]) * next), GOOD])
		lines.append(["Sea Essence", "%d/%d" % [player.inventory.count(essence), Enchanting.ESSENCE_COST[next]], GOOD if player.inventory.count(essence) >= Enchanting.ESSENCE_COST[next] else BAD])
		lines.append(["Coins", "$%s" % UiKit.coins_text(Enchanting.COIN_COST[next]), GOOD if player.wallet.can_afford(Enchanting.COIN_COST[next]) else BAD])
		lines.append(["Alchemy", "%d" % Enchanting.ALCHEMY_NEEDED[next], GOOD if Skills.level(player, Skills.ALCHEMY) >= Enchanting.ALCHEMY_NEEDED[next] else BAD])
	var why : String = Enchanting.blocked(player, held, value)
	return {"title": each[1], "color": Enchanting.COLOR, "text": each[5], "lines": lines, "action": "Enchant" if at < int(each[4]) else "Maxed", "enabled": why.is_empty()}

func choose(player : Player, value : Variant) -> String:
	if not value is String:
		return ""
	var target : RodItem = rod(player)
	if not target:
		return fail("Hold a rod first")
	var why : String = Enchanting.blocked(player, target, value)
	if not why.is_empty():
		return fail(why)
	Enchanting.enchant(player, target, value)
	return ok("%s %s!" % [Enchanting.entry(value)[1], Enchanting.ROMAN[Enchanting.level(target, value)]])
