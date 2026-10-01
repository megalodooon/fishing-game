@tool
extends Counter
class_name TrophyLodge

# Odette's Trophy Lodge in the harbor (see TrophyFishing). The Trophies tab
# is the lodge's book: every trophy fish, where it lives, what it takes and
# the best tier caught. Fillet turns trophies in the bag into Trophy Scales,
# which the Prizes tab spends. Every few new tiers raise the lodge level,
# with a reward to claim.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const DIM : Color = Color(0.58, 0.67, 0.78)
const PRICE : Color = Color(1.0, 0.9, 0.4)
const SCALE : String = "res://items/trophy/trophy_scale.tres"
# Tiers caught needed for each lodge level, and its reward [item, amount].
const LEVELS : Array = [
	[4, ["res://items/trophy/trophy_scale.tres", 20]],
	[10, ["res://items/charms/trophy_hunter_1.tres", 1]],
	[18, ["res://items/tools/pouch_stitching_2.tres", 1]],
	[28, ["res://items/trophy/trophy_scale.tres", 150]],
	[40, ["res://items/rare/lucky_stone.tres", 1]],
	[52, ["res://fishing/rods/odettes_rod.tres", 1]],
]
# What the scales buy: [item path, amount, scales].
const PRIZES : Array = [
	["res://fishing/bait/trophy_bait.tres", 5, 12],
	["res://items/charms/trophy_hunter_1.tres", 1, 60],
	["res://items/charms/trophy_hunter_2.tres", 1, 240],
	["res://items/charms/trophy_hunter_3.tres", 1, 900],
	["res://items/enchanting/sea_essence.tres", 10, 40],
	["res://items/tools/pouch_stitching_3.tres", 1, 1200],
	["res://fishing/rods/odettes_rod.tres", 1, 2500],
]

enum Tab { TROPHIES, FILLET, PRIZES }


func intro_id() -> String:
	return "trophy_lodge"

func theme_name() -> String:
	return "wood"

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Trophies", "Fillet", "Prizes"])

func searchable() -> bool:
	return tab != Tab.FILLET

static func level(progress : Progress) -> int:
	var caught : int = TrophyFishing.tiers_caught(progress)
	var at : int = 0
	for i in LEVELS.size():
		if caught >= int(LEVELS[i][0]):
			at = i + 1
	return at

static func claimed(progress : Progress) -> int:
	return int(progress.get_flag("trophy/claimed", 0))

func subtitle(player : Player) -> String:
	var caught : int = TrophyFishing.tiers_caught(player.progress)
	var at : int = level(player.progress)
	var next : String = "max level" if at >= LEVELS.size() else "next at %d" % LEVELS[at][0]
	return "Lodge level %d: %d/%d tiers caught, %s" % [at, caught, TrophyFishing.all().size() * 4, next]

func pinned_rows(player : Player) -> Array[Dictionary]:
	if claimed(player.progress) < level(player.progress):
		return [{"value": &"claim", "text": "Claim lodge level %d reward" % (claimed(player.progress) + 1), "marked": true, "markColor": GOOD, "detail": "!", "detailColor": GOOD}]
	return []

func scale_item() -> Item:
	return load(SCALE) as Item

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	match tab:
		Tab.TROPHIES:
			for trophy in TrophyFishing.all():
				var best : int = TrophyFishing.best_tier(player.progress, trophy)
				list.append({"value": trophy, "icon": trophy.icon, "tint": Color.WHITE if best >= 0 else Color(0.15, 0.18, 0.24), "text": trophy.displayName if best >= 0 else "???", "detail": TrophyFishing.TIER_NAMES[best] if best >= 0 else "", "detailColor": TrophyFishing.TIER_COLORS[best] if best >= 0 else DIM})
		Tab.FILLET:
			for slot in player.inventory.trashSlot:
				var stack : Item = player.inventory.get_item(slot)
				if stack and stack.category == "Trophy Fish":
					list.append({"value": slot, "icon": stack.icon, "text": "%s x%d" % [stack.displayName, stack.amount], "detail": "+%d" % (fillet_value(stack) * stack.amount), "detailColor": PRICE})
		Tab.PRIZES:
			var have : int = player.inventory.count(scale_item())
			for prize in PRIZES:
				var thing : Item = load(prize[0]) as Item
				if thing:
					list.append({"value": prize, "icon": thing.icon, "tint": BaitCrafter.tint_of(thing), "text": thing.displayName if prize[1] <= 1 else "%s x%d" % [thing.displayName, prize[1]], "detail": "%d" % prize[2], "detailIcon": scale_item().icon if scale_item() else null, "detailColor": PRICE if have >= prize[2] else Color(0.95, 0.38, 0.34)})
	return list

# Scales for one of these trophies.
func fillet_value(stack : Item) -> int:
	for trophy in TrophyFishing.all():
		var tier : int = trophy.tiers.find(stack.original())
		if tier >= 0:
			return trophy.scales[tier]
	return 0

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName:
		var reward : Array = LEVELS[claimed(player.progress)][1]
		var thing : Item = load(reward[0]) as Item
		return {"title": "Lodge level %d" % (claimed(player.progress) + 1), "icon": thing.icon if thing else null, "text": "Odette has a prize for your progress.", "lines": [["Reward", thing.displayName if reward[1] <= 1 else "%s x%d" % [thing.displayName, reward[1]], GOOD]], "action": "Claim", "enabled": true}
	if value is TrophyFish:
		var trophy : TrophyFish = value
		var best : int = TrophyFishing.best_tier(player.progress, trophy)
		var lines : Array = [["Where", trophy.biome.displayName if trophy.biome else "?"], ["Needs", trophy.hint]]
		for tier in 4:
			var got : bool = player.progress.has_flag("trophy/%s/%d" % [trophy.key(), tier])
			lines.append([TrophyFishing.TIER_NAMES[tier], "Caught" if got else "-", TrophyFishing.TIER_COLORS[tier] if got else DIM])
		var sinceGold : int = int(player.progress.pity.get("trophy/%s/gold" % trophy.key(), 0))
		lines.append(["Gold luck meter", "%d/%d" % [sinceGold, TrophyFishing.GOLD_PITY]])
		return {"title": trophy.displayName if best >= 0 else "Unknown trophy", "icon": trophy.icon, "tint": Color.WHITE if best >= 0 else Color(0.15, 0.18, 0.24), "text": trophy.lore if best >= 0 else "Odette has heard of it. Try the conditions below.", "lines": lines}
	if value is int:
		var stack : Item = player.inventory.get_item(value)
		if not stack:
			return {}
		var details : Dictionary = Counter.item_info(stack)
		details.action = "Fillet %d for %d scales" % [stack.amount, fillet_value(stack) * stack.amount]
		return details
	if value is Array:
		var thing : Item = load(value[0]) as Item
		var details : Dictionary = Counter.item_info(thing)
		var have : int = player.inventory.count(scale_item())
		details.lines.append(["Price", "%d scales" % value[2], PRICE if have >= value[2] else Color(0.95, 0.38, 0.34)])
		details.action = "Buy"
		details.enabled = have >= value[2]
		return details
	return {}

func choose(player : Player, value : Variant) -> String:
	if value is StringName:
		var reward : Array = LEVELS[claimed(player.progress)][1]
		var thing : Item = load(reward[0]) as Item
		if not Counter.fits(player, thing, reward[1]):
			return fail("No room in the bag")
		Counter.deliver(player, thing, reward[1])
		player.progress.set_flag("trophy/claimed", claimed(player.progress) + 1)
		return ok("Claimed %s!" % thing.displayName)
	if value is int:
		var stack : Item = player.inventory.get_item(value)
		if not stack:
			return ""
		var earned : int = fillet_value(stack) * stack.amount
		var amount : int = stack.amount
		player.inventory.items[value] = null
		player.inventory.emit_changed()
		Counter.deliver(player, scale_item(), earned)
		player.progress.count("trophies_filleted", amount)
		Skills.add(player, Skills.FISHING, earned * 2.0)
		return ok("+%d Trophy Scales" % earned)
	if value is Array:
		var thing : Item = load(value[0]) as Item
		if player.inventory.count(scale_item()) < value[2]:
			return fail("Not enough scales")
		if not Counter.fits(player, thing, value[1]):
			return fail("No room in the bag")
		player.inventory.take(scale_item(), value[2])
		Counter.deliver(player, thing, value[1])
		return ok("Bought %s" % thing.displayName)
	return ""
