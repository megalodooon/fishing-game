@tool
extends Counter
class_name Shop

# Sells its offers for coins and buys fish and goods from the bag, on a Buy
# and a Sell tab. A shop without offers only buys, one with a buy rate of 0
# only sells. Every day a few of its specials go on sale, some offers only
# stock a few a day, and some wait for a quest before they show up for sale.

const ALL_FISH : StringName = &"all_fish"
const MARKET : StringName = &"market"
const PRICE_COLOR : Color = Color(1.0, 0.9, 0.4)
const DIM_COLOR : Color = Color(0.58, 0.67, 0.78)
const BAD_COLOR : Color = Color(0.95, 0.38, 0.34)
const SALE_COLOR : Color = Color(0.56, 0.93, 0.44)

#------------------------#
@export var offers : Array[ShopOffer] = []
# More offers kept in their own file (see ShopStock), sold after these.
@export var stock : ShopStock
# Pays this share of what things are worth. 0 means it doesn't buy anything.
@export_range(0.0, 3.0, 0.05) var buyRate : float = 1.0
@export var buysFish : bool = true
# Everything else with a price, like crops.
@export var buysGoods : bool = true
@export var greeting : String = ""
# Opens on the selling side, for shops that mostly buy.
@export var startSelling : bool = false
# Fish prices follow the daily market (see Market).
@export var followsMarket : bool = true

@export_group("Daily sale")
# A few of these are on sale each day, cheaper than usual.
@export var specials : Array[ShopOffer] = []
@export var specialCount : int = 0
@export_range(0.0, 0.9, 0.05) var discount : float = 0.25
#------------------------#


func buys() -> bool:
	return buyRate > 0.0

func sells() -> bool:
	return not all_offers().is_empty() or (specialCount > 0 and not specials.is_empty())

func all_offers() -> Array[ShopOffer]:
	var list : Array[ShopOffer] = offers.duplicate()
	if stock:
		list.append_array(stock.offers)
	return list

func selling() -> bool:
	return not sells() or (tab == 1 and buys())

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Buy", "Sell"]) if sells() and buys() else PackedStringArray()

func opened(_player : Player) -> void:
	tab = 1 if sells() and buys() and startSelling else 0

func subtitle(_player : Player) -> String:
	if not greeting.is_empty():
		return greeting
	if buys() and not is_equal_approx(buyRate, 1.0):
		return "Pays %d%% for fish" % roundi(buyRate * 100.0)
	return ""

func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

# Today's sale picks, the same all day.
func todays_specials() -> Array[ShopOffer]:
	var pool : Array[ShopOffer] = []
	for offer in specials:
		if offer and offer.item:
			pool.append(offer)
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([today(), String(get_path()), "sale"])
	for i in range(pool.size() - 1, 0, -1):
		var j : int = random.randi_range(0, i)
		var swap : ShopOffer = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	return pool.slice(0, specialCount)

func is_special(offer : ShopOffer) -> bool:
	return specials.has(offer)

func price_of(offer : ShopOffer) -> int:
	return maxi(roundi(offer.cost() * (1.0 - discount)), 1) if is_special(offer) else offer.cost()

func stock_key() -> String:
	return "stock/" + String(get_path())

func bought_today(player : Player, offer : ShopOffer) -> int:
	var state : Dictionary = player.progress.get_flag(stock_key(), {})
	return state.get("bought", {}).get(offer, 0) if state.get("day", -1) == today() else 0

func stock_left(player : Player, offer : ShopOffer) -> int:
	var limit : int = offer.dailyStock if offer.dailyStock > 0 else (1 if is_special(offer) else 0)
	return limit - bought_today(player, offer) if limit > 0 else -1

func note_bought(player : Player, offer : ShopOffer) -> void:
	var state : Dictionary = player.progress.get_flag(stock_key(), {})
	var bought : Dictionary = state.get("bought", {}).duplicate() if state.get("day", -1) == today() else {}
	bought[offer] = bought.get(offer, 0) + 1
	player.progress.set_flag(stock_key(), {"day": today(), "bought": bought})

func will_buy(item : Item, player : Player) -> bool:
	if not item or item.price() <= 0 or not player.can_move_slot(player.inventory.items.find(item)):
		return false
	return (item is Fish and buysFish) or (not item is Fish and buysGoods)

func offer_for(item : Item, player : Player = null) -> int:
	var bonus : float = 1.0 + (player.stat(&"sellBonus") * 0.01 if player else 0.0)
	return maxi(roundi(item.price() * buyRate * bonus * demand(item)), 1)

func demand(item : Item) -> float:
	return Market.factor((item as Fish).species, today()) if followsMarket and item is Fish else 1.0

func fish_total(player : Player) -> int:
	var total : int = 0
	for item in player.inventory.items.slice(0, player.inventory.trashSlot):
		if item is Fish and will_buy(item, player):
			total += offer_for(item, player)
	return total

func pinned_rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	if selling() and buysFish and followsMarket:
		list.append({"value": MARKET, "text": "Market today", "detail": "", "icon": null})
	if selling() and buysFish:
		var total : int = fish_total(player)
		list.append({"value": ALL_FISH, "text": "Sell all fish", "detail": "$%d" % total, "detailColor": PRICE_COLOR if total > 0 else DIM_COLOR, "dim": total == 0})
	return list

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	if selling():
		var items : Array[Item] = player.inventory.items
		for slot in player.inventory.trashSlot:
			var item : Item = items[slot]
			if will_buy(item, player):
				var label : String = item.displayName if item.amount <= 1 else "%s x%d" % [item.displayName, item.amount]
				list.append({"value": slot, "icon": item.icon, "text": label, "detail": "$%d" % offer_for(item, player), "detailColor": PRICE_COLOR})
		return list
	for offer in todays_specials():
		list.append(offer_row(player, offer))
	for offer in all_offers():
		if offer and offer.item:
			list.append(offer_row(player, offer))
	return list

func offer_row(player : Player, offer : ShopOffer) -> Dictionary:
	var tint : Color = (offer.item as Tackle).icon_tint() if offer.item is Tackle else Color.WHITE
	if not offer.unlocked(player):
		var needs : String = "Fishing %d" % offer.requiredLevel if offer.requiredSkill == Skills.FISHING else "Locked"
		if not offer.requiredSkill.is_empty() and offer.requiredSkill != Skills.FISHING:
			needs = "%s %d" % [Skills.NAMES.get(offer.requiredSkill, ""), offer.requiredLevel]
		return {"value": offer, "icon": offer.item.icon, "tint": tint, "text": offer.label(), "search": offer.item.displayName, "detail": needs, "detailColor": BAD_COLOR, "dim": true}
	var price : int = price_of(offer)
	var left : int = stock_left(player, offer)
	var detail : String = "Sold out" if left == 0 else (price_short(offer, price))
	var currencyIcon : Texture2D = offer.currency.icon if offer.currency and left != 0 else null
	var color : Color = DIM_COLOR if left == 0 else (PRICE_COLOR if offer.can_pay(player, price) else BAD_COLOR)
	var text : String = offer.label()
	if is_special(offer):
		text = "Sale! " + text
	return {"value": offer, "icon": offer.item.icon, "tint": tint, "text": text, "search": offer.label(), "detail": detail, "detailIcon": currencyIcon, "detailColor": color, "dim": left == 0, "marked": is_special(offer) and left != 0}

# A price short enough for a list row.
func price_short(offer : ShopOffer, price : int) -> String:
	return "%d" % price if offer.currency else "$%s" % UiKit.coins_text(price)

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName and value == MARKET:
		var lines : Array = []
		for pair in Market.hot(player.journal, today()):
			lines.append([pair[0].displayName, "x%.1f" % pair[1], Color(0.56, 0.93, 0.44)])
		return {"title": "Market today", "text": "Fish in demand pay more today. Tomorrow the market moves on." if not lines.is_empty() else "Nothing you've caught is in demand today.", "lines": lines}
	if value is StringName:
		var total : int = fish_total(player)
		return {"title": "Sell all fish", "text": "Sells every fish in the bag at once.", "lines": [["Total", "$%d" % total]], "action": "Sell all", "enabled": total > 0}
	if value is int:
		var item : Item = player.inventory.get_item(value)
		if not selling() or not will_buy(item, player):
			return {}
		var details : Dictionary = Counter.item_info(item)
		if not is_equal_approx(demand(item), 1.0):
			details.lines.append(["Demand", "x%.1f" % demand(item), SALE_COLOR if demand(item) > 1.0 else BAD_COLOR])
		details.lines.append(["Offer", "$%d" % offer_for(item, player), PRICE_COLOR])
		details.action = "Sell one" if item.amount > 1 else "Sell"
		return details
	var offer : ShopOffer = value as ShopOffer
	if not offer or not offer.item:
		return {}
	if not offer.unlocked(player):
		var locked : Dictionary = Counter.item_info(offer.item)
		if not Unlocks.skill_met(player.progress, offer.requiredSkill, offer.requiredLevel):
			var need : PackedStringArray = Unlocks.skill_need(player.progress, offer.requiredSkill, offer.requiredLevel)
			locked.lines.append(["Needs", need[0], BAD_COLOR])
			locked.lines.append(["You", need[1], BAD_COLOR])
		elif not offer.lockedText.is_empty():
			locked.lines.append([offer.lockedText, "", BAD_COLOR])
		locked.action = "Locked"
		locked.enabled = false
		return locked
	var shown : Dictionary = Counter.item_info(offer.item)
	var price : int = price_of(offer)
	if is_special(offer):
		shown.lines.append(["Usually", offer.price_text(offer.cost()), DIM_COLOR])
		shown.lines.append(["Sale", "-%d%%" % roundi(discount * 100.0), SALE_COLOR])
	shown.lines.append(["Price", offer.price_text(price), PRICE_COLOR])
	if offer.currency:
		shown.lines.append(["You have", "%d" % player.inventory.count(offer.currency)])
	var left : int = stock_left(player, offer)
	if left >= 0:
		shown.lines.append(["Left today", "%d" % left])
	var owned : int = Counter.count_owned(player, offer.item)
	if owned > 0:
		shown.lines.append(["You have", "%d" % owned])
	shown.enabled = left != 0 and offer.can_pay(player, price)
	shown.action = "Sold out" if left == 0 else ("Buy for %s" % offer.price_text(price) if offer.can_pay(player, price) else ("Not enough %s" % (offer.currency.displayName if offer.currency else "coins")))
	return shown

func choose(player : Player, value : Variant) -> String:
	if value is StringName and value == MARKET:
		return ""
	if value is StringName:
		var total : int = 0
		for slot in player.inventory.trashSlot:
			var item : Item = player.inventory.items[slot]
			if item is Fish and will_buy(item, player):
				total += offer_for(item, player)
				player.inventory.items[slot] = null
		if total == 0:
			return fail("No fish to sell")
		player.inventory.emit_changed()
		player.wallet.add(total)
		sold(player, total)
		return ok("Sold for $%d!" % total)
	if value is int:
		var item : Item = player.inventory.get_item(value)
		if not selling() or not will_buy(item, player):
			return ""
		var price : int = offer_for(item, player)
		player.inventory.take_one(value)
		player.wallet.add(price)
		sold(player, price)
		return ok("Sold for $%d!" % price)
	var offer : ShopOffer = value as ShopOffer
	if not offer:
		return ""
	if not offer.unlocked(player):
		return fail("Not for sale yet")
	if stock_left(player, offer) == 0:
		return fail("Sold out for today")
	var cost : int = price_of(offer)
	if not offer.can_pay(player, cost):
		return fail("Not enough %s" % (offer.currency.displayName if offer.currency else "coins"))
	if not Counter.fits(player, offer.item, offer.amount):
		return fail("No room in the bag")
	offer.pay(player, cost)
	Counter.deliver(player, offer.item, offer.amount)
	if stock_left(player, offer) > 0:
		note_bought(player, offer)
	return ok("Got %s!" % offer.label())

func sold(player : Player, coins : int) -> void:
	Quest.notify(player, &"sell", coins)
	Skills.add(player, Skills.TRADING, coins * 0.1)
	player.progress.count("coins_earned", coins)

func theme_name() -> String:
	return "wood"
