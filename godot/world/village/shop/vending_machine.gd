@tool
extends Counter
class_name VendingMachine

# Stocks a few different things every day, picked from its offers, with at
# least some snacks for energy among them. Each can be bought once, then it's
# sold out until tomorrow.

#------------------------#
@export var offers : Array[ShopOffer] = []
@export var snacks : Array[ShopOffer] = []
@export var slots : int = 3
# How many of the day's slots always hold a snack.
@export var snackSlots : int = 1
#------------------------#


func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

# The same picks all day long, new ones tomorrow.
func stock() -> Array[ShopOffer]:
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([today(), String(get_path())])
	var food : Array[ShopOffer] = shuffled(snacks, random)
	var rest : Array[ShopOffer] = shuffled(offers, random)
	var picks : Array[ShopOffer] = []
	for i in mini(snackSlots, food.size()):
		picks.append(food[i])
	rest.append_array(food.slice(picks.size()))
	for offer in rest:
		if picks.size() >= slots:
			break
		picks.append(offer)
	return picks

func shuffled(list : Array[ShopOffer], random : RandomNumberGenerator) -> Array[ShopOffer]:
	var pool : Array[ShopOffer] = []
	for offer in list:
		if offer and offer.item:
			pool.append(offer)
	for i in range(pool.size() - 1, 0, -1):
		var j : int = random.randi_range(0, i)
		var swap : ShopOffer = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	return pool

func state_key() -> String:
	return "vending/" + String(get_path())

func sold(player : Player) -> Array:
	var state : Dictionary = player.progress.get_flag(state_key(), {})
	return state.get("sold", []) if state.get("day", -1) == today() else []

func subtitle(_player : Player) -> String:
	return "Restocks every morning"

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var gone : Array = sold(player)
	var picks : Array[ShopOffer] = stock()
	for i in picks.size():
		var offer : ShopOffer = picks[i]
		var out : bool = gone.has(i)
		var afford : bool = player.wallet.can_afford(offer.cost())
		list.append({"value": i, "icon": offer.item.icon, "tint": (offer.item as Tackle).icon_tint() if offer.item is Tackle else Color.WHITE, "text": offer.label(), "detail": "Sold" if out else "$%d" % offer.cost(), "detailColor": Color(0.58, 0.67, 0.78) if out or not afford else Color(1.0, 0.9, 0.4), "dim": out})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var picks : Array[ShopOffer] = stock()
	if not value is int or value >= picks.size():
		return {}
	var offer : ShopOffer = picks[value]
	var details : Dictionary = Counter.item_info(offer.item)
	details.lines.append(["Price", "$%d" % offer.cost()])
	var out : bool = sold(player).has(value)
	details.action = "Sold out" if out else ("Buy for $%d" % offer.cost() if player.wallet.can_afford(offer.cost()) else "Not enough coins")
	details.enabled = not out and player.wallet.can_afford(offer.cost())
	return details

func choose(player : Player, value : Variant) -> String:
	var picks : Array[ShopOffer] = stock()
	if not value is int or value >= picks.size():
		return ""
	var offer : ShopOffer = picks[value]
	var gone : Array = sold(player).duplicate()
	if gone.has(value):
		return fail("Sold out")
	if not player.wallet.can_afford(offer.cost()):
		return fail("Not enough coins")
	if not Counter.fits(player, offer.item, offer.amount):
		return fail("No room in the bag")
	player.wallet.spend(offer.cost())
	Counter.deliver(player, offer.item, offer.amount)
	gone.append(value)
	player.progress.set_flag(state_key(), {"day": today(), "sold": gone})
	return ok("Got %s!" % offer.label())

func theme_name() -> String:
	return "tin"
