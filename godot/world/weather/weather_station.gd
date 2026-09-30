@tool
extends Counter
class_name WeatherStation

# Stormwatch's weather station: pay to set tomorrow's weather wherever the
# boat is. The order is kept in progress ("weather_order") and the Weather
# node follows it for that whole day.

const STATES : Array = [[Weather.State.CLEAR, "Clear skies"], [Weather.State.RAIN, "Rain"], [Weather.State.FOG, "Fog"]]

#------------------------#
@export var price : int = 600
#------------------------#


func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

func order(player : Player) -> Dictionary:
	return player.progress.get_flag("weather_order", {})

func subtitle(player : Player) -> String:
	var ordered : Dictionary = order(player)
	if ordered.get("day", -1) == today() + 1:
		return "Tomorrow: %s (ordered)" % Weather.NAMES[ordered.state]
	return "Order tomorrow's weather for $%d" % price

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var weather : Weather = Weather.find(get_tree())
	for entry in STATES:
		var ordered : bool = order(player).get("day", -1) == today() + 1 and order(player).get("state", -1) == entry[0]
		list.append({"value": entry[0], "icon": weather.icon(entry[0]) if weather else null, "text": entry[1], "detail": "Ordered" if ordered else "$%d" % price, "detailColor": Color(0.56, 0.93, 0.44) if ordered else Color(1.0, 0.9, 0.4), "marked": ordered})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if not value is int:
		return {}
	var weather : Weather = Weather.find(get_tree())
	return {"title": Weather.NAMES[value], "icon": weather.icon(value) if weather else null, "text": "The station seeds the clouds tonight. Tomorrow brings %s all day, wherever you sail." % Weather.NAMES[value].to_lower(), "lines": [["Effect", weather.effect_text(value) if weather else ""], ["Price", "$%d" % price]], "action": "Order for $%d" % price, "enabled": player.wallet.can_afford(price)}

func choose(player : Player, value : Variant) -> String:
	if not value is int:
		return ""
	if not player.wallet.spend(price):
		return fail("Not enough coins")
	player.progress.set_flag("weather_order", {"day": today() + 1, "state": value})
	return ok("Tomorrow: %s" % Weather.NAMES[value])

func theme_name() -> String:
	return "tin"
