@tool
extends Counter
class_name DailyOrders

# The harbor's daily orders: three deliveries a day, fish the player already
# knows how to catch and goods they've come across, paid far above what the
# market pays. The same three all day, new ones every morning. Delivering all
# three in a day adds a crate on top. Taken from the fishmonger.

const COUNT : int = 3
const PAY : float = 2.4
const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)

#------------------------#
@export var bonus : Item
#------------------------#


func theme_name() -> String:
	return "paper"

func searchable() -> bool:
	return false

func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

func subtitle(player : Player) -> String:
	var done : int = delivered(player).count(true)
	return "Today's orders: %d/%d delivered" % [done, COUNT]

# Today's orders as [thing, amount], the same all day.
func orders(player : Player) -> Array:
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([today(), "orders"])
	var fish : Array[FishData] = []
	for data in player.journal.caught:
		if data.rarity and data.rarity.difficulty < 0.6:
			fish.append(data)
	if fish.is_empty():
		for data in Catalog.fish():
			if data.rarity and data.rarity.displayName == "Common" and player.journal.biome_names(data).has("Bramble Bay"):
				fish.append(data)
	fish.sort_custom(func(a : FishData, b : FishData) -> bool: return a.resource_path < b.resource_path)
	var goods : Array[Item] = []
	for thing in player.progress.collected:
		if thing is Item and (thing as Item).sellPrice > 0 and not thing is Tackle and not thing is TreasureChest and (thing as Item).stacks():
			goods.append(thing)
	goods.sort_custom(func(a : Item, b : Item) -> bool: return a.resource_path < b.resource_path)
	var list : Array = []
	for i in COUNT:
		if i == COUNT - 1 and not goods.is_empty():
			var item : Item = goods[random.randi_range(0, goods.size() - 1)]
			list.append([item, random.randi_range(2, 6)])
		elif not fish.is_empty():
			var data : FishData = fish[random.randi_range(0, fish.size() - 1)]
			var most : int = 4 if data.rarity.displayName == "Common" else 2
			list.append([data, random.randi_range(1, most)])
	return list

func delivered(player : Player) -> Array:
	var state : Dictionary = player.progress.orders
	if state.get("day", -1) != today():
		return [false, false, false]
	return state.get("done", [false, false, false])

func have(player : Player, thing : Resource) -> int:
	if thing is FishData:
		return player.inventory.count_where(func(item : Item) -> bool: return item is Fish and (item as Fish).species == thing)
	return player.inventory.count(thing as Item)

func reward(thing : Resource, amount : int) -> int:
	var worth : float = 0.0
	if thing is FishData:
		worth = (thing as FishData).basePrice
	elif thing is Item:
		worth = (thing as Item).sellPrice
	return maxi(roundi(worth * amount * PAY), 10)

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var done : Array = delivered(player)
	var all_orders : Array = orders(player)
	for i in all_orders.size():
		var thing : Resource = all_orders[i][0]
		var amount : int = all_orders[i][1]
		var finished : bool = done[i]
		var deliverable : bool = not finished and have(player, thing) >= amount
		list.append({"value": i, "icon": Collections.icon_of(thing), "text": "%d %s" % [amount, Collections.name_of(thing)], "detail": "Done" if finished else "$%d" % reward(thing, amount), "detailColor": GOOD if finished or deliverable else DIM, "dim": finished, "marked": deliverable})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var all_orders : Array = orders(player)
	if not value is int or value >= all_orders.size():
		return {"title": "No orders", "text": "Catch a few fish first. Orders ask for what you know."}
	var thing : Resource = all_orders[value][0]
	var amount : int = all_orders[value][1]
	var finished : bool = delivered(player)[value]
	var count : int = have(player, thing)
	var rarity : Rarity = Collections.rarity_of(thing)
	var lines : Array = [["Wanted", "%d" % amount], ["In your bag", "%d" % count, GOOD if count >= amount else BAD], ["Pays", "$%d" % reward(thing, amount), GOOD], ["Trading XP", "+%d" % roundi(reward(thing, amount) * 0.2)]]
	if bonus:
		lines.append(["All three today", bonus.displayName, GOOD])
	var where : PackedStringArray = Sources.fish_text(thing, player.journal) if thing is FishData else Sources.of(thing)
	var text : String = ("Found: " + where[0]) if not where.is_empty() else ""
	return {"title": Collections.name_of(thing), "color": rarity.color if rarity else Color.WHITE, "icon": Collections.icon_of(thing), "tag": "Harbor order", "text": text, "lines": lines, "action": "Delivered" if finished else ("Deliver" if count >= amount else "Not enough yet"), "enabled": not finished and count >= amount}

func choose(player : Player, value : Variant) -> String:
	var all_orders : Array = orders(player)
	if not value is int or value >= all_orders.size():
		return ""
	var done : Array = delivered(player).duplicate()
	if done[value]:
		return fail("Already delivered")
	var thing : Resource = all_orders[value][0]
	var amount : int = all_orders[value][1]
	if have(player, thing) < amount:
		return fail("Not enough yet")
	if thing is FishData:
		player.inventory.take_where(func(item : Item) -> bool: return item is Fish and (item as Fish).species == thing, amount)
	else:
		player.inventory.take(thing as Item, amount)
	var pay : int = reward(thing, amount)
	player.wallet.add(pay)
	Skills.add(player, Skills.TRADING, pay * 0.2)
	player.progress.count("orders")
	done[value] = true
	player.progress.orders = {"day": today(), "done": done}
	player.progress.emit_changed()
	if not done.has(false) and bonus and Counter.fits(player, bonus, 1):
		Counter.deliver(player, bonus, 1)
		notice("All orders delivered!", "A %s for your trouble." % bonus.displayName, GOOD, bonus.icon)
	return ok("Delivered! +$%d" % pay)
