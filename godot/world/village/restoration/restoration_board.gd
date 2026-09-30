@tool
extends Counter
class_name RestorationBoard

# The village's restoration board. Lists the projects that are open, what
# each costs and what it brings back, and pays for them. The subtitle keeps
# count of how much of the village is fixed up.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)

#------------------------#
@export var projects : Array[Project] = []
#------------------------#


func finished(player : Player) -> int:
	var count : int = 0
	for project in projects:
		if project and project.done(player.progress):
			count += 1
	return count

func subtitle(player : Player) -> String:
	return "Village restored: %d/%d projects" % [finished(player), projects.size()]

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var later : Array[Dictionary] = []
	for project in projects:
		if not project:
			continue
		if project.done(player.progress):
			later.append({"value": project, "icon": project.icon, "text": project.displayName, "detail": "Done", "detailColor": GOOD, "dim": true})
		elif project.available(player.progress):
			list.append({"value": project, "icon": project.icon, "text": project.displayName, "detail": "$%d" % project.coins, "detailColor": Color(1.0, 0.9, 0.4) if project.affordable(player) else DIM, "marked": project.affordable(player)})
		else:
			var needs : Array[PackedStringArray] = project.missing(player.progress)
			later.append({"value": project, "icon": project.icon, "tint": Color(1.0, 1.0, 1.0, 0.45), "text": project.displayName, "detail": needs[0][0] if not needs.is_empty() else "Later", "detailColor": BAD, "dim": true})
	list.append_array(later)
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var project : Project = value as Project
	if not project:
		return {}
	if not project.done(player.progress) and not project.available(player.progress):
		var locked : Array = []
		for need in project.missing(player.progress):
			locked.append(["Needs", need[0], BAD])
			locked.append(["You", need[1], BAD])
		if not project.unlockText.is_empty():
			locked.append(["Brings back", project.unlockText, GOOD])
		return {"title": project.displayName, "icon": project.icon, "tag": "Not ready yet", "text": project.description, "lines": locked, "action": "Locked", "enabled": false}
	var lines : Array = []
	if not project.unlockText.is_empty():
		lines.append(["Brings back", project.unlockText, GOOD])
	lines.append(["Coins", "$%d" % project.coins, GOOD if player.wallet.can_afford(project.coins) else BAD])
	for i in project.items.size():
		var item : Item = project.items[i]
		if item:
			var have : int = player.inventory.count(item)
			lines.append([item.displayName, "%d/%d" % [mini(have, project.amount(i)), project.amount(i)], GOOD if have >= project.amount(i) else BAD])
	var details : Dictionary = {"title": project.displayName, "icon": project.icon, "tag": "Restoration project", "text": project.description, "lines": lines}
	if project.done(player.progress):
		details.action = "Restored"
		details.enabled = false
	else:
		details.enabled = project.affordable(player)
		details.action = "Fund it" if details.enabled else "Missing materials"
	return details

func choose(player : Player, value : Variant) -> String:
	var project : Project = value as Project
	if not project or not project.available(player.progress):
		return ""
	if not project.pay(player):
		return fail("Missing materials")
	notice("%s restored!" % project.displayName, project.unlockText, GOOD, project.icon)
	return ok("Restored!")

func theme_name() -> String:
	return "cork"
