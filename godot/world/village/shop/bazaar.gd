@tool
extends Counter
class_name Bazaar

# The Market Hall's bazaar (like Skyblock's): every material, crop and
# enchanted material the player has come across, bought and sold here at any
# time. Prices drift a little every day, the same all day. Buying cheap things
# comes in eights. Things never found yet aren't traded, so the bazaar grows
# with the player's collections.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)
const PRICE : Color = Color(1.0, 0.9, 0.4)
# Categories traded, by the item's category, in list order.
const SECTIONS : Array = [
	["Materials", ["Material", "Upgrade Material", "Forage", "Refined", "Creature Drop", "Junk"]],
	["Enchanted", ["Enchanted Material"]],
	["Farming", ["Crop", "Seed"]],
	["Fish goods", ["Fish Product"]],
]
const BULK_UNDER : int = 60
const BULK : int = 8
const SELL_SHARE : float = 0.9

enum Tab { BUY, SELL }

static var tradedCache : Array[Item] = []


func theme_name() -> String:
	return "wood"

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Buy", "Sell"])

func subtitle(_player : Player) -> String:
	return "Everything you've found, bought and sold any time"

func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

static func section_of(item : Item) -> int:
	for i in SECTIONS.size():
		if SECTIONS[i][1].has(item.type_name()):
			return i
	return -1

static func traded() -> Array[Item]:
	if tradedCache.is_empty():
		for item in Catalog.items():
			if item.stacks() and item.sellPrice > 0 and section_of(item) >= 0:
				tradedCache.append(item)
	return tradedCache

func drift(item : Item) -> float:
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([today(), item.resource_path, "bazaar"])
	return snappedf(random.randf_range(0.85, 1.2), 0.01)

func buy_price(item : Item) -> int:
	return maxi(roundi(item.shop_price() * drift(item)), 1)

func sell_price(item : Item, player : Player) -> int:
	return maxi(floori(item.sellPrice * drift(item) * SELL_SHARE * (1.0 + player.stat(&"sellBonus") * 0.01)), 1)

func batch(item : Item) -> int:
	return BULK if buy_price(item) < BULK_UNDER else 1

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var known : Dictionary = player.progress.collected
	for s in SECTIONS.size():
		var section : Array[Dictionary] = []
		for item in traded():
			if section_of(item) != s:
				continue
			if tab == Tab.BUY:
				if known.has(item):
					var amount : int = batch(item)
					section.append({"value": item, "icon": item.icon, "text": item.displayName if amount == 1 else "%s x%d" % [item.displayName, amount], "detail": "$%s" % UiKit.coins_text(buy_price(item) * amount), "detailColor": PRICE if player.wallet.can_afford(buy_price(item) * amount) else BAD})
			else:
				var have : int = player.inventory.count(item)
				if have > 0:
					section.append({"value": item, "icon": item.icon, "text": "%s x%d" % [item.displayName, have], "detail": "$%s" % UiKit.coins_text(sell_price(item, player) * have), "detailColor": PRICE})
		if not section.is_empty():
			list.append({"header": true, "text": SECTIONS[s][0]})
			list.append_array(section)
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var item : Item = value as Item
	if not item:
		return {"title": "Nothing to trade", "text": "Materials you find show up here to buy, and sell here whenever you like." if tab == Tab.BUY else "Nothing in the bag the bazaar buys."}
	var details : Dictionary = Counter.item_info(item)
	var change : float = drift(item)
	details.lines = [["Buy", "$%s each" % UiKit.coins_text(buy_price(item))], ["Sell", "$%s each" % UiKit.coins_text(sell_price(item, player))], ["Today", "%+d%%" % roundi((change - 1.0) * 100.0), GOOD if change < 1.0 else BAD], ["You have", "%d" % player.inventory.count(item)]]
	if tab == Tab.BUY:
		var cost : int = buy_price(item) * batch(item)
		details.action = "Buy %d for $%s" % [batch(item), UiKit.coins_text(cost)]
		details.enabled = player.wallet.can_afford(cost)
	else:
		var have : int = player.inventory.count(item)
		details.action = "Sell %d for $%s" % [have, UiKit.coins_text(sell_price(item, player) * have)]
		details.enabled = have > 0
	return details

func choose(player : Player, value : Variant) -> String:
	var item : Item = value as Item
	if not item:
		return ""
	if tab == Tab.BUY:
		var amount : int = batch(item)
		var cost : int = buy_price(item) * amount
		if not player.wallet.can_afford(cost):
			return fail("Not enough coins")
		if not Counter.fits(player, item, amount):
			return fail("No room in the bag")
		player.wallet.spend(cost)
		Counter.deliver(player, item, amount)
		return ok("Bought %d %s" % [amount, item.displayName])
	var have : int = player.inventory.count(item)
	if have <= 0:
		return fail("None left")
	var pay : int = sell_price(item, player) * have
	player.inventory.take(item, have)
	player.wallet.add(pay)
	Quest.notify(player, &"sell", pay)
	Skills.add(player, Skills.TRADING, pay * 0.1)
	player.progress.count("coins_earned", pay)
	return ok("Sold for $%s!" % UiKit.coins_text(pay))
