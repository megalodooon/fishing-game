@tool
extends Counter
class_name Aquarium

# The village aquarium. Every tank asks for some fish. Giving it the last one
# restores it: it pays out and opens the building that was waiting for it.

const BACK : StringName = &"back"

#------------------------#
@export var tanks : Array[AquariumTank] = []
@export var doneColor : Color = Color(0.56, 0.93, 0.44)

var tank : AquariumTank
#------------------------#


func opened(_player : Player) -> void:
	tank = null

func subtitle(player : Player) -> String:
	if tank:
		return "%d of %d fish given" % [player.progress.donated(tank).size(), tank.needed()]
	var done : int = 0
	for each in tanks:
		if player.progress.tank_done(each):
			done += 1
	return "%d of %d tanks restored" % [done, tanks.size()]

func holds(player : Player, data : FishData) -> bool:
	return player.inventory.count_where(func(item : Item) -> bool: return item is Fish and (item as Fish).species == data) > 0

func pinned_rows(_player : Player) -> Array[Dictionary]:
	if tank:
		return [{"value": BACK, "text": "< All tanks"}]
	return []

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	if not tank:
		for each in tanks:
			if not each.requiredFlag.is_empty() and not player.progress.has_flag(each.requiredFlag):
				continue
			var done : bool = player.progress.tank_done(each)
			list.append({"value": each, "icon": each.icon, "text": each.displayName, "detail": "Done" if done else "%d/%d" % [player.progress.donated(each).size(), each.needed()], "detailColor": doneColor if done else Color(0.58, 0.67, 0.78), "marked": done})
		return list
	for data in tank.fish:
		var given : bool = player.progress.has_donated(tank, data)
		var known : bool = player.journal == null or player.journal.is_found(data)
		var inBag : bool = holds(player, data)
		list.append({"value": data, "icon": data.icon, "tint": Color.WHITE if known else Color(0.0, 0.0, 0.0, 0.6), "text": data.displayName if known else "???", "detail": "Given" if given else ("In bag" if inBag else ""), "detailColor": doneColor if given or inBag else Color(0.58, 0.67, 0.78), "marked": given, "dim": given})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if value is AquariumTank:
		var each : AquariumTank = value
		var lines : Array = [["Fish", "%d/%d" % [player.progress.donated(each).size(), each.needed()]]]
		if not each.opens.is_empty():
			lines.append(["Opens", each.opens])
		if each.rewardCoins > 0:
			lines.append(["Reward", "$%d" % each.rewardCoins])
		return {"title": each.displayName, "icon": each.icon, "text": each.description, "lines": lines, "action": "Restored" if player.progress.tank_done(each) else "See its fish", "enabled": true}
	if value is FishData and tank:
		var data : FishData = value
		var known : bool = player.journal == null or player.journal.is_found(data)
		var given : bool = player.progress.has_donated(tank, data)
		var inBag : bool = holds(player, data)
		var lines : Array = [["Rarity", data.rarity.displayName if data.rarity else "-"]]
		if player.journal:
			var places : PackedStringArray = player.journal.biome_names(data)
			if not places.is_empty() and known:
				lines.append(["Where", places[0]])
		return {"title": data.displayName if known else "???", "color": data.rarity.color if data.rarity and known else Color.WHITE, "icon": data.icon, "tint": Color.WHITE if known else Color(0.0, 0.0, 0.0, 0.6), "text": data.description if known else "Not caught yet.", "lines": lines, "action": "Given" if given else ("Give one" if inBag else "Bring one in your bag"), "enabled": not given and inBag}
	if value is StringName and value == BACK:
		return {"title": "All tanks", "text": "Back to the list of tanks."}
	return {}

func choose(player : Player, value : Variant) -> String:
	if value is AquariumTank:
		tank = value
		return ""
	if value is StringName and value == BACK:
		tank = null
		return ""
	if not value is FishData or not tank:
		return ""
	var data : FishData = value
	if player.progress.has_donated(tank, data):
		return fail("Already given")
	if player.progress.tank_done(tank):
		return fail("Tank is full")
	if player.inventory.take_where(func(item : Item) -> bool: return item is Fish and (item as Fish).species == data, 1).is_empty():
		return fail("Not in your bag")
	if player.progress.donate(tank, data):
		if tank.rewardCoins > 0:
			player.wallet.add(tank.rewardCoins)
		notice("%s restored!" % tank.displayName, ("%s is open now." % tank.opens if not tank.opens.is_empty() else "The aquarium thanks you.") + (" +$%d" % tank.rewardCoins if tank.rewardCoins > 0 else ""), doneColor, tank.icon)
		return ok("Tank restored!")
	return ok("Gave %s!" % data.displayName)

func theme_name() -> String:
	return "glass"
