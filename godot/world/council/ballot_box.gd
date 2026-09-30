@tool
extends Counter
class_name BallotBox

# The Harbor Council's ballot box in the square: shows who holds the seat this
# week and their perk, and takes the player's vote for next week.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const DIM : Color = Color(0.58, 0.67, 0.78)


func theme_name() -> String:
	return "paper"

func searchable() -> bool:
	return false

func shows_coins() -> bool:
	return false

func week_now() -> int:
	return Council.week(Council.today(get_tree()))

func subtitle(player : Player) -> String:
	var seat : Array = Council.current(get_tree(), player.progress)
	return "This week: %s, %s" % [Cast.name_of(seat[0]), seat[1]]

func pinned_rows(player : Player) -> Array[Dictionary]:
	var seat : Array = Council.current(get_tree(), player.progress)
	return [{"value": &"seat", "icon": Cast.portrait(seat[0]), "text": "Now: " + seat[1], "detail": "", "marked": true, "markColor": GOOD}]

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = [{"header": true, "text": "Next week's vote"}]
	var voted : String = player.progress.get_flag("vote/%d" % (week_now() + 1), "")
	for candidate in Council.ballot(week_now() + 1):
		list.append({"value": candidate[0], "icon": Cast.portrait(candidate[0]), "text": Cast.name_of(candidate[0]), "detail": "Voted" if voted == candidate[0] else "", "detailColor": GOOD, "marked": voted == candidate[0]})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName:
		var seat : Array = Council.current(get_tree(), player.progress)
		return {"title": seat[1], "icon": Cast.portrait(seat[0]), "tag": "%s holds the seat" % Cast.name_of(seat[0]), "text": "The council's perk helps everyone all week. Vote for next week below.", "lines": [["Perk", Council.perk_text(seat), GOOD]]}
	for candidate in Council.ballot(week_now() + 1):
		if candidate[0] == value:
			var voted : bool = player.progress.get_flag("vote/%d" % (week_now() + 1), "") == value
			return {"title": Cast.name_of(candidate[0]), "icon": Cast.portrait(candidate[0]), "tag": candidate[1], "text": "If they win, their perk runs all next week.", "lines": [["Perk", Council.perk_text(candidate), GOOD]], "action": "Voted" if voted else "Vote", "enabled": not voted}
	return {}

func choose(player : Player, value : Variant) -> String:
	if value is String:
		Council.vote(player.progress, week_now() + 1, value)
		return ok("Voted for %s!" % Cast.name_of(value))
	return ""
