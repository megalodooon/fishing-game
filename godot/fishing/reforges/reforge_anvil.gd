@tool
extends Counter
class_name ReforgeAnvil

# Reforges rods (see Reforge). Every rod in the bag is listed with its
# reforge; the card shows what it gives and what a new one costs. Reforging
# rolls a random reforge from the anvil's pool for coins, by the rod's
# rarity. A reforge stone in the bag gives its own reforge instead, and adds
# a row for it.

const COSTS : Dictionary = {"Common": 250, "Uncommon": 800, "Rare": 2500, "Legendary": 8000, "Trophy": 20000}
const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)

#------------------------#
# The stone picked for the next reforge, if any.
var stone : Item
#------------------------#


func theme_name() -> String:
	return "wood"

func searchable() -> bool:
	return false

func subtitle(_player : Player) -> String:
	return "New reforges for coins. Stones give their own."

func cost(rod : RodItem) -> int:
	return COSTS.get(rod.rarity.displayName if rod.rarity else "Common", 250)

func stones(player : Player) -> Array[Item]:
	var list : Array[Item] = []
	for each in Reforge.all():
		if each.stone and player.inventory.count(each.stone) > 0 and not list.has(each.stone):
			list.append(each.stone)
	return list

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var items : Array[Item] = player.inventory.items
	for slot in player.inventory.trashSlot:
		var rod : RodItem = items[slot] as RodItem
		if rod:
			list.append({"value": slot, "icon": rod.icon, "text": rod.displayName, "detail": rod.reforge.prefix if rod.reforge else "-", "detailColor": GOOD if rod.reforge else DIM})
	return list

func pinned_rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for each in stones(player):
		list.append({"value": each, "icon": each.icon, "text": "Use %s" % each.displayName, "detail": "x%d" % player.inventory.count(each), "marked": each == stone})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if value is Item:
		var found : Reforge = Reforge.for_stone(value)
		return {"title": (value as Item).displayName, "icon": (value as Item).icon, "tag": "Reforge stone", "text": "Pick it, then pick a rod: the rod gets the %s reforge and the stone is used up." % (found.prefix if found else "?"), "lines": [["Gives", found.prefix if found else "?", GOOD], ["Stats", found.summary() if found else "", GOOD]], "action": "Picked" if stone == value else "Pick this stone", "enabled": stone != value}
	var rod : RodItem = player.inventory.get_item(value) as RodItem if value is int else null
	if not rod:
		return {"title": "No rods", "text": "Rods in the bag show up here."}
	var details : Dictionary = Counter.item_info(rod)
	var lines : Array = [["Reforge", rod.reforge.prefix if rod.reforge else "None", GOOD if rod.reforge else DIM]]
	if rod.reforge:
		lines.append(["Gives", rod.reforge.summary(), GOOD])
	if stone:
		var found : Reforge = Reforge.for_stone(stone)
		lines.append(["Stone", "%s (%s)" % [stone.displayName, found.prefix if found else "?"], GOOD])
		details.action = "Reforge with the stone"
		details.enabled = player.can_move_slot(value)
	else:
		var price : int = cost(rod)
		lines.append(["Cost", "$%s" % UiKit.coins_text(price), GOOD if player.wallet.can_afford(price) else BAD])
		details.action = "Reforge for $%s" % UiKit.coins_text(price)
		details.enabled = player.wallet.can_afford(price) and player.can_move_slot(value)
	details.lines = lines + details.lines
	return details

func choose(player : Player, value : Variant) -> String:
	if value is Item:
		stone = null if stone == value else value
		return ok("Stone picked") if stone else ok("Stone put away")
	var rod : RodItem = player.inventory.get_item(value) as RodItem if value is int else null
	if not rod:
		return ""
	if not player.can_move_slot(value):
		return fail("Reel in first")
	var result : Reforge = null
	if stone:
		result = Reforge.for_stone(stone)
		if not result or player.inventory.count(stone) <= 0:
			stone = null
			return fail("No stone")
		player.inventory.take(stone, 1)
		if player.inventory.count(stone) <= 0:
			stone = null
	else:
		var price : int = cost(rod)
		if not player.wallet.spend(price):
			return fail("Not enough coins")
		result = Reforge.roll(rod.reforge)
	if not result:
		return fail("Nothing to roll")
	rod.apply_reforge(result)
	player.inventory.emit_changed()
	player.progress.count("reforges")
	Skills.add(player, Skills.TRADING, 15.0)
	return ok("%s!" % rod.displayName)
