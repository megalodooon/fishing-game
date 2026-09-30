@tool
extends Counter
class_name TournamentDesk

# The tournament hall's desk: this week's target and standings, entering, the
# results once the week is over, and a prize shop that takes tickets.

const ENTER : StringName = &"enter"
const TARGET : StringName = &"target"
const RESULTS : StringName = &"results"
const TICKET_COLOR : Color = Color(1.0, 0.8, 0.35)

#------------------------#
@export var prizes : Array[ShopOffer] = []
#------------------------#


func tournament() -> Tournament:
	return Tournament.find(get_tree())

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["This week", "Prize shop"])

func subtitle(player : Player) -> String:
	var cup : Tournament = tournament()
	if not cup or not cup.open():
		return "The hall is closed for now."
	return "%s - %d ticket%s" % [Tournament.LEAGUES[cup.league()], player.progress.tickets, "" if player.progress.tickets == 1 else "s"]

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var cup : Tournament = tournament()
	if not cup or not cup.open():
		return list
	if tab == 1:
		for offer in prizes:
			if offer and offer.item:
				var afford : bool = player.progress.tickets >= offer.price
				list.append({"value": offer, "icon": offer.item.icon, "text": offer.label(), "detail": "%dT" % offer.price, "detailColor": TICKET_COLOR if afford else Color(0.95, 0.38, 0.34)})
		return list
	var entry : Dictionary = cup.state()
	var species : FishData = entry.species
	if species:
		list.append({"value": TARGET, "icon": species.icon, "text": species.displayName, "detail": "Target", "detailColor": TICKET_COLOR})
	if cup.past_deadline() and not entry.done:
		list.append({"value": RESULTS, "text": "Results are in!", "detail": "", "marked": true})
	elif not entry.entered and not cup.past_deadline():
		list.append({"value": ENTER, "text": "Enter", "detail": "$%d" % cup.fee(), "detailColor": Color(1.0, 0.9, 0.4)})
	var place : int = 1
	for row in cup.standings(entry, cup.past_deadline()):
		list.append({"value": "row%d" % place, "text": "%d. %s" % [place, row[0]], "detail": "%.2fkg" % row[1] if row[1] < 100.0 else "%.0fkg" % row[1], "detailColor": Color(0.56, 0.93, 0.44) if row[2] else Color(0.58, 0.67, 0.78), "marked": row[2]})
		place += 1
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var cup : Tournament = tournament()
	if not cup or not cup.open():
		return {"title": "Tournament Hall", "text": "Tournaments start again once the hall is restored. Ask around the village.", "lines": []}
	if value is ShopOffer:
		var offer : ShopOffer = value
		var shown : Dictionary = Counter.item_info(offer.item)
		shown.lines.append(["Price", "%d tickets" % offer.price, TICKET_COLOR])
		shown.enabled = player.progress.tickets >= offer.price
		shown.action = "Trade" if shown.enabled else "Not enough tickets"
		return shown
	var entry : Dictionary = cup.state()
	var species : FishData = entry.species
	var lines : Array = [["League", Tournament.LEAGUES[entry.league]], ["Entry fee", "$%d" % cup.fee()], ["Deadline", "Saturday 18:00"]]
	if species:
		lines.append(["Weighs", species.weight_range_text()])
		var where : PackedStringArray = player.journal.biome_names(species)
		if not where.is_empty():
			lines.append(["Found in", where[0]])
	if entry.entered:
		lines.append(["Your best", "%.2fkg" % entry.best if entry.best > 0.0 else "Nothing yet", Color(0.56, 0.93, 0.44)])
	lines.append(["1st prize", "$%d + 3T" % roundi(Tournament.PRIZE_COINS[0] * Tournament.LEAGUE_SCALE[entry.league])])
	var details : Dictionary = {"title": "Biggest %s wins" % (species.displayName if species else "fish"), "icon": species.icon if species else null, "color": species.rarity.color if species and species.rarity else Color.WHITE, "tag": Tournament.LEAGUES[entry.league], "text": "Catch the heaviest one you can before Saturday 18:00. Only fish caught after entering count.", "lines": lines}
	if value == RESULTS:
		details.action = "See results"
	elif value == ENTER:
		details.action = "Enter for $%d" % cup.fee()
		details.enabled = player.wallet.can_afford(cup.fee())
	return details

func choose(player : Player, value : Variant) -> String:
	var cup : Tournament = tournament()
	if not cup or not cup.open():
		return ""
	if value is ShopOffer:
		var offer : ShopOffer = value
		if player.progress.tickets < offer.price:
			return fail("Not enough tickets")
		if not Counter.fits(player, offer.item, offer.amount):
			return fail("No room in the bag")
		player.progress.tickets -= offer.price
		Counter.deliver(player, offer.item, offer.amount)
		player.progress.emit_changed()
		return ok("Got %s!" % offer.label())
	if value == ENTER:
		return ok("You're in! Good luck.") if cup.enter() else fail("Can't enter now")
	if value == RESULTS:
		var text : String = cup.settle(cup.state())
		notice("Tournament results", text, TICKET_COLOR)
		return ok("Results in!")
	return ""

func theme_name() -> String:
	return "leather_blue"
