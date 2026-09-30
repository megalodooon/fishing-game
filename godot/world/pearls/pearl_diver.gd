@tool
extends Counter
class_name PearlDiver

# Trades the lost pearls found around the world (see Pearls) for blessings:
# every five pearls buy the next one, in order, and they last forever.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const DIM : Color = Color(0.58, 0.67, 0.78)


func subtitle(player : Player) -> String:
	return "%d/%d pearls found" % [Pearls.found(player.progress), Pearls.TOTAL]

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var claimed : int = Pearls.claimed(player.progress)
	for i in Pearls.BLESSINGS.size():
		var blessing : Array = Pearls.BLESSINGS[i]
		var text : String = "%s %s" % [Stats.bonus_text(blessing[0], blessing[1]), Stats.name_of(blessing[0])]
		var need : int = (i + 1) * Pearls.PER_BLESSING
		if i < claimed:
			list.append({"value": i, "text": text, "detail": "Blessed", "detailColor": GOOD, "dim": true})
		elif i == claimed:
			list.append({"value": i, "text": text, "detail": "%d pearls" % need, "detailColor": GOOD if Pearls.claimable(player.progress) > 0 else DIM, "marked": Pearls.claimable(player.progress) > 0})
		else:
			list.append({"value": i, "text": "???", "detail": "%d pearls" % need, "detailColor": DIM, "dim": true})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if not value is int:
		return {}
	var i : int = value
	var claimed : int = Pearls.claimed(player.progress)
	var need : int = (i + 1) * Pearls.PER_BLESSING
	var lines : Array = [["Pearls needed", "%d" % need], ["Pearls found", "%d" % Pearls.found(player.progress)]]
	if i > claimed:
		return {"title": "A later blessing", "text": "Claim the ones before it first.", "lines": lines}
	var blessing : Array = Pearls.BLESSINGS[i]
	var details : Dictionary = {"title": "%s %s" % [Stats.bonus_text(blessing[0], blessing[1]), Stats.name_of(blessing[0])], "tag": "Blessing %d" % (i + 1), "text": "Pearls glint where no one looks: under piers, behind rocks, at the end of paths. Each island hides a few.", "lines": lines}
	if i < claimed:
		details.action = "Blessed"
		details.enabled = false
	else:
		details.enabled = Pearls.claimable(player.progress) > 0
		details.action = "Receive blessing" if details.enabled else "Find more pearls"
	return details

func choose(player : Player, value : Variant) -> String:
	if not value is int or value != Pearls.claimed(player.progress) or Pearls.claimable(player.progress) <= 0:
		return fail("Not yet")
	player.progress.set_flag("pearl_blessings", Pearls.claimed(player.progress) + 1)
	player.refresh_energy_max()
	return ok("Blessed!")

func theme_name() -> String:
	return "glass"
