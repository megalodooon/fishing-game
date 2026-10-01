@tool
extends Counter
class_name MuseumCounter

# The museum wing's donation desk (see Museum). The Donate tab lists what in
# the bag the museum still wants; the Collection tab shows every wing, with
# the pieces still missing as silhouettes. Milestone rewards are claimed from
# the pinned row.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const DIM : Color = Color(0.58, 0.67, 0.78)

enum Tab { DONATE, COLLECTION }


func intro_id() -> String:
	return "museum"

func theme_name() -> String:
	return "glass"

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Donate", "Collection"])

func subtitle(player : Player) -> String:
	var at : int = Museum.reached(player.progress)
	var next : String = "all milestones reached" if at >= Museum.MILESTONES.size() else "next milestone at %d" % Museum.MILESTONES[at][0]
	return "%d museum points, %s" % [Museum.points(player.progress), next]

func pinned_rows(player : Player) -> Array[Dictionary]:
	if Museum.claimed(player.progress) < Museum.reached(player.progress):
		return [{"value": &"claim", "text": "Claim milestone %d" % (Museum.claimed(player.progress) + 1), "marked": true, "markColor": GOOD, "detail": "!", "detailColor": GOOD}]
	return []

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	if tab == Tab.DONATE:
		for slot in player.inventory.trashSlot:
			var item : Item = player.inventory.get_item(slot)
			if item and Museum.wing_of(item) >= 0 and not Museum.donated(player.progress, item):
				list.append({"value": slot, "icon": item.icon, "text": item.displayName, "detail": "+%d" % Museum.points_of(item), "detailColor": Museum.COLOR})
		return list
	for wing in Museum.WINGS.size():
		var section : Array[Dictionary] = []
		var done : int = 0
		var total : int = 0
		for item in Museum.pieces():
			if Museum.wing_of(item) != wing:
				continue
			total += 1
			var have : bool = Museum.donated(player.progress, item)
			if have:
				done += 1
			section.append({"value": item, "icon": item.icon, "tint": Color.WHITE if have else Color(0.12, 0.14, 0.2), "text": item.displayName if have else "???", "detail": "Donated" if have else "", "detailColor": GOOD, "dim": not have})
		list.append({"header": true, "text": "%s %d/%d" % [Museum.WINGS[wing], done, total]})
		list.append_array(section)
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName:
		var reward : Array = Museum.MILESTONES[Museum.claimed(player.progress)][1]
		var thing : Item = load(reward[0]) as Item
		return {"title": "Milestone %d" % (Museum.claimed(player.progress) + 1), "icon": thing.icon if thing else null, "text": "Nora is thrilled with the collection.", "lines": [["Reward", thing.displayName if reward[1] <= 1 else "%s x%d" % [thing.displayName, reward[1]], GOOD]], "action": "Claim", "enabled": true}
	if value is int:
		var item : Item = player.inventory.get_item(value)
		if not item:
			return {}
		var details : Dictionary = Counter.item_info(item)
		details.lines.append(["Museum points", "+%d" % Museum.points_of(item), Museum.COLOR])
		details.action = "Donate"
		return details
	if value is Item:
		var item : Item = value
		var have : bool = Museum.donated(player.progress, item)
		if have:
			var details : Dictionary = Counter.item_info(item)
			details.lines.append(["Museum points", "%d" % Museum.points_of(item), Museum.COLOR])
			return details
		var hints : PackedStringArray = Sources.of(item)
		return {"title": "Not donated yet", "icon": item.icon, "tint": Color(0.12, 0.14, 0.2), "text": "\n".join(hints.slice(0, 2)) if not hints.is_empty() else "Keep exploring.", "lines": [["Museum points", "%d" % Museum.points_of(item), DIM]]}
	return {}

func choose(player : Player, value : Variant) -> String:
	if value is StringName:
		var reward : Array = Museum.MILESTONES[Museum.claimed(player.progress)][1]
		var thing : Item = load(reward[0]) as Item
		if not Counter.fits(player, thing, reward[1]):
			return fail("No room in the bag")
		Counter.deliver(player, thing, reward[1])
		player.progress.set_flag("museum_claimed", Museum.claimed(player.progress) + 1)
		return ok("Claimed %s!" % thing.displayName)
	if value is int:
		var item : Item = player.inventory.get_item(value)
		var label : String = item.displayName if item else ""
		if Museum.donate(player, value):
			return ok("%s donated!" % label)
		return fail("The museum has one already")
	return ""
