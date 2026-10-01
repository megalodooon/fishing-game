@tool
extends Counter
class_name CrewBoard

# The crew board by the house: the player's crew and what they've gathered
# (see Crew). The Crew tab collects, the Upgrade tab raises tiers for their
# materials, and the Hire tab takes the contracts in the bag.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)
const ALL : StringName = &"all"

enum Tab { CREW, UPGRADE, HIRE }


func intro_id() -> String:
	return "crew"

func theme_name() -> String:
	return "cork"

func searchable() -> bool:
	return false

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Crew", "Upgrade", "Hire"])

func opened(player : Player) -> void:
	Crew.work(player)

func subtitle(player : Player) -> String:
	return "%d/%d slots.%s" % [player.progress.crew.size(), Crew.slots(player), "" if Crew.slots(player) >= Crew.MAX_SLOTS else " New tiers open more."]

func contracts(player : Player) -> Array[int]:
	var list : Array[int] = []
	for slot in player.inventory.trashSlot:
		if player.inventory.items[slot] is CrewContract:
			list.append(slot)
	return list

func pinned_rows(player : Player) -> Array[Dictionary]:
	if tab != Tab.CREW:
		return []
	var total : int = 0
	for entry in player.progress.crew:
		total += entry.stored
	return [{"value": ALL, "text": "Collect everything", "detail": "%d" % total, "detailColor": GOOD if total > 0 else DIM, "dim": total == 0}]

func rows(player : Player) -> Array[Dictionary]:
	Crew.work(player)
	var list : Array[Dictionary] = []
	match tab:
		Tab.CREW, Tab.UPGRADE:
			for i in player.progress.crew.size():
				var entry : Dictionary = player.progress.crew[i]
				var member : CrewMember = entry.crew
				if not member:
					continue
				var detail : String = "%d/%d" % [entry.stored, member.storage(entry.tier)] if tab == Tab.CREW else ("Max" if entry.tier >= CrewMember.MAX_TIER else "-> %s" % Unlocks.roman(entry.tier + 1))
				var full : bool = entry.stored >= member.storage(entry.tier)
				list.append({"value": i, "icon": member.icon, "text": member.tier_name(entry.tier), "detail": detail, "detailColor": BAD if full and tab == Tab.CREW else (GOOD if can_upgrade(player, i) and tab == Tab.UPGRADE else DIM), "marked": entry.stored > 0 and tab == Tab.CREW})
			for i in range(player.progress.crew.size(), Crew.slots(player)):
				list.append({"value": -1 - i, "cross": true, "text": "Empty slot", "detail": "Hire", "dim": true})
		Tab.HIRE:
			for slot in contracts(player):
				var contract : CrewContract = player.inventory.items[slot]
				list.append({"value": slot, "icon": contract.icon, "text": contract.displayName, "detail": "Hire"})
	return list

func can_upgrade(player : Player, index : int) -> bool:
	var entry : Dictionary = player.progress.crew[index]
	var price : Array = (entry.crew as CrewMember).cost(entry.tier + 1)
	return not price.is_empty() and price[0] and player.inventory.count(price[0]) >= price[1]

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName:
		return {"title": "Collect everything", "text": "Moves everything your crew gathered into the bag, as much as fits.", "action": "Collect all", "enabled": true}
	if not value is int:
		return {}
	if value < 0:
		return {"title": "Empty slot", "text": "Craft a crew contract in the recipe book (R), then hire them on the Hire tab.", "lines": [["Slots", "%d/%d" % [player.progress.crew.size(), Crew.slots(player)]], ["New tiers reached", "%d" % Crew.unique_tiers(player)], ["Next slot at", "All open" if Crew.slots(player) >= Crew.MAX_SLOTS else "%d tiers" % ((floori(Crew.unique_tiers(player) / float(Crew.UNIQUE_PER_SLOT)) + 1) * Crew.UNIQUE_PER_SLOT)]]}
	if tab == Tab.HIRE:
		var contract : CrewContract = player.inventory.get_item(value) as CrewContract
		if not contract:
			return {}
		var shown : Dictionary = Counter.item_info(contract)
		var room : bool = player.progress.crew.size() < Crew.slots(player)
		shown.action = "Hire" if room else "No free slot"
		shown.enabled = room
		return shown
	var entry : Dictionary = player.progress.crew[value]
	var member : CrewMember = entry.crew
	var lines : Array = [["Gathers", member.product.displayName], ["Speed", "1 per %s" % Crew.hours_text(member.interval(entry.tier, Crew.speed(player)))], ["Holding", "%d/%d" % [entry.stored, member.storage(entry.tier)], BAD if entry.stored >= member.storage(entry.tier) else Color(0.94, 0.97, 1.0)]]
	var details : Dictionary = {"title": member.tier_name(entry.tier), "icon": member.icon, "tag": "Crew member", "text": member.description, "lines": lines}
	if tab == Tab.CREW:
		details.action = "Collect %d" % entry.stored
		details.enabled = entry.stored > 0
		return details
	var price : Array = member.cost(entry.tier + 1)
	if price.is_empty():
		details.action = "Top tier"
		details.enabled = false
		return details
	lines.append(["Next", "%s: 1 per %s" % [Unlocks.roman(entry.tier + 1), Crew.hours_text(member.interval(entry.tier + 1, Crew.speed(player)))], GOOD])
	var have : int = player.inventory.count(price[0])
	lines.append([price[0].displayName, "%d/%d" % [mini(have, price[1]), price[1]], GOOD if have >= price[1] else BAD])
	details.action = "Upgrade"
	details.enabled = have >= price[1]
	return details

func choose(player : Player, value : Variant) -> String:
	if value is StringName:
		var total : int = 0
		for i in player.progress.crew.size():
			total += Crew.collect(player, i)
		return ok("Collected %d!" % total) if total > 0 else fail("Nothing to collect")
	if not value is int or value < 0:
		return ""
	match tab:
		Tab.CREW:
			var got : int = Crew.collect(player, value)
			return ok("Collected %d!" % got) if got > 0 else fail("Nothing here, or the bag is full")
		Tab.UPGRADE:
			if not can_upgrade(player, value):
				return fail("Missing materials")
			var entry : Dictionary = player.progress.crew[value]
			var price : Array = (entry.crew as CrewMember).cost(entry.tier + 1)
			player.inventory.take(price[0], price[1])
			entry.tier += 1
			Crew.mark_tier(player, entry.crew, entry.tier)
			Skills.add(player, Skills.CRAFTING, 20.0 * entry.tier)
			player.progress.emit_changed()
			return ok("%s!" % (entry.crew as CrewMember).tier_name(entry.tier))
		Tab.HIRE:
			var contract : CrewContract = player.inventory.get_item(value) as CrewContract
			if not contract or not contract.crew:
				return ""
			if not Crew.hire(player, contract.crew):
				return fail("No free slot")
			player.inventory.take_one(value)
			return ok("%s hired!" % contract.crew.displayName)
	return ""
