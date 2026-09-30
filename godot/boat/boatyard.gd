@tool
extends Counter
class_name Boatyard

# Marina's boatyard: every boat part (see BoatParts) with its next tier's
# cost in coins and materials. Building a tier takes the payment, raises the
# part and applies what it does at once (like the cargo hold's slots).

const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)


func subtitle(_player : Player) -> String:
	return "Upgrades are forever, and they add up."

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for part in BoatParts.ORDER:
		var level : int = BoatParts.tier(player.progress, part)
		var done : bool = BoatParts.maxed(player.progress, part)
		list.append({"value": part, "icon": BoatParts.icon(part), "text": BoatParts.PARTS[part][0], "detail": "Max" if done else "Tier %d" % (level + 1), "detailColor": GOOD if done else (Color(1.0, 0.9, 0.4) if can_build(player, part) else Color(0.58, 0.67, 0.78)), "dim": done})
	return list

func cost(part : StringName, level : int) -> Array:
	return BoatParts.tiers(part)[level]

func can_build(player : Player, part : StringName) -> bool:
	if BoatParts.maxed(player.progress, part):
		return false
	var tier : Array = cost(part, BoatParts.tier(player.progress, part))
	if not player.wallet.can_afford(tier[0]):
		return false
	for path in tier[1]:
		var item : Item = load(path) as Item
		if not item or player.inventory.count(item) < tier[1][path]:
			return false
	return true

func info(player : Player, value : Variant) -> Dictionary:
	if not value is StringName:
		return {}
	var part : StringName = value
	var level : int = BoatParts.tier(player.progress, part)
	var lines : Array = [["Built", BoatParts.tier_name(part, level)]]
	if BoatParts.maxed(player.progress, part):
		return {"title": BoatParts.PARTS[part][0], "icon": BoatParts.icon(part), "tag": "Fully upgraded", "text": BoatParts.PARTS[part][1], "lines": lines, "action": "Maxed", "enabled": false}
	var tier : Array = cost(part, level)
	lines.append(["Next", tier[3]])
	for stat in tier[2]:
		lines.append([Stats.name_of(stat), Stats.bonus_text(stat, tier[2][stat]), GOOD])
	if part == BoatParts.CARGO:
		lines.append(["Backpack", "+%d slots" % BoatParts.CARGO_SLOTS, GOOD])
	if part == BoatParts.SONAR:
		lines.append(["Fishing spots", "more, longer", GOOD])
	if part == BoatParts.CABIN and level == 0:
		lines.append(["Sleep", "anywhere at sea", GOOD])
	lines.append(["Coins", "$%d" % tier[0], GOOD if player.wallet.can_afford(tier[0]) else BAD])
	for path in tier[1]:
		var item : Item = load(path) as Item
		if item:
			var have : int = player.inventory.count(item)
			lines.append([item.displayName, "%d/%d" % [mini(have, tier[1][path]), tier[1][path]], GOOD if have >= tier[1][path] else BAD])
	var buildable : bool = can_build(player, part)
	return {"title": BoatParts.PARTS[part][0], "icon": BoatParts.icon(part), "tag": "Tier %d of %d" % [level + 1, BoatParts.tiers(part).size()], "text": BoatParts.PARTS[part][1], "lines": lines, "action": "Build" if buildable else "Missing materials", "enabled": buildable}

func choose(player : Player, value : Variant) -> String:
	if not value is StringName:
		return ""
	var part : StringName = value
	if not can_build(player, part):
		return fail("Missing materials")
	var tier : Array = cost(part, BoatParts.tier(player.progress, part))
	player.wallet.spend(tier[0])
	for path in tier[1]:
		player.inventory.take(load(path) as Item, tier[1][path])
	player.progress.boat[part] = BoatParts.tier(player.progress, part) + 1
	player.progress.emit_changed()
	BoatParts.apply(player)
	player.progress.count("boat_upgrades")
	notice("Boat upgraded!", "%s built." % tier[3], GOOD)
	return ok("Built the %s!" % tier[3])

func theme_name() -> String:
	return "wood"
