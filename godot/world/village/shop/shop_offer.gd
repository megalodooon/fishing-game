extends Resource
class_name ShopOffer

# Something for sale: the item, how many come at once and what they cost. It
# can wait for a progress flag (like a quest) before it's for sale, and can
# run out for the day.

#------------------------#
@export var item : Item
@export var amount : int = 1
# 0 uses the item's shop price (Item.shop_price), the same in every shop.
@export var price : int = 0
# Paid in this item instead of coins when set, like gifts at the Gift Tide stall.
@export var currency : Item
# How many can be bought a day. 0 means as many as you like.
@export var dailyStock : int = 0
@export var requiredFlag : String = ""
# Why it's locked, like "Finish Reef Rumors".
@export var lockedText : String = ""
# A skill level needed before it's for sale, like better tackle at Fishing 10.
@export var requiredSkill : StringName = &""
@export var requiredLevel : int = 0
#------------------------#


# The price as text, like "$120" or "12 Wrapped Gifts".
func price_text(total : int) -> String:
	if currency:
		return "%d %s" % [total, currency.displayName]
	return "$%s" % UiKit.coins_text(total)

func can_pay(player : Player, total : int) -> bool:
	if currency:
		return player.inventory.count(currency) >= total
	return player.wallet.can_afford(total)

func pay(player : Player, total : int) -> bool:
	if not can_pay(player, total):
		return false
	if currency:
		player.inventory.take(currency, total)
	else:
		player.wallet.spend(total)
	return true

func label() -> String:
	return item.displayName if amount <= 1 else "%s x%d" % [item.displayName, amount]

func unlocked(player : Player) -> bool:
	return (requiredFlag.is_empty() or player.progress.has_flag(requiredFlag)) and Unlocks.skill_met(player.progress, requiredSkill, requiredLevel)

# What it costs: its own price, or the item's shop price for the amount.
func cost() -> int:
	return price if price > 0 else item.shop_price() * amount
