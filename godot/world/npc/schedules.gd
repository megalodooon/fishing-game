extends RefCounted
class_name Schedules

# Where each villager is through the day, on their own island. A stop is
# [hour, room, point in the room, how]: from that hour until the next stop
# they walk there and stay. "inside" means they go in a building at that
# point and are out of sight; "sun" or "week" limits a stop to Sundays or
# the other days. Everyone walks at WALK_SPEED (pixels a second). A villager
# only follows their schedule on an island that has its rooms, so the same
# person standing somewhere else later in the story just stays put there.

const WALK_SPEED : float = 16.0
const PEOPLE : Dictionary = {
	# Bramblewick (village.tscn): no room means a point on the whole island;
	# MarketHall, Bank, HarborOffice, Museum and Tavern are insides.
	"pip": [[0.0, "", Vector2(250, 112), "inside"], [6.5, "", Vector2(392, 368), ""], [8.0, "HarborOffice", Vector2(96, 42), ""], [12.0, "", Vector2(420, 234), ""], [13.0, "HarborOffice", Vector2(96, 42), ""], [18.0, "", Vector2(392, 372), ""], [21.0, "", Vector2(250, 112), "inside"]],
	"gus": [[0.0, "", Vector2(318, 112), "inside"], [7.0, "MarketHall", Vector2(62, 40), ""], [18.0, "", Vector2(360, 238), ""], [20.5, "", Vector2(318, 112), "inside"]],
	"nora": [[0.0, "", Vector2(704, 162), "inside"], [8.0, "Museum", Vector2(136, 42), ""], [17.0, "", Vector2(310, 200), ""], [19.0, "", Vector2(704, 162), "inside"]],
	"vera": [[0.0, "", Vector2(704, 162), "inside"], [10.0, "", Vector2(440, 230), ""], [15.0, "", Vector2(560, 282), ""], [19.0, "", Vector2(704, 162), "inside"]],
	"rex": [[0.0, "", Vector2(250, 112), "inside"], [6.0, "", Vector2(414, 362), ""], [12.0, "", Vector2(240, 282), ""], [15.0, "", Vector2(404, 376), ""], [20.0, "", Vector2(250, 112), "inside"]],
	"hale": [[0.0, "", Vector2(70, 212), "inside"], [9.0, "", Vector2(276, 134), ""], [13.0, "", Vector2(560, 282), ""], [16.0, "", Vector2(472, 206), ""], [20.0, "", Vector2(70, 212), "inside"]],
	"marina": [[0.0, "", Vector2(318, 112), "inside"], [7.0, "", Vector2(626, 332), ""], [18.0, "", Vector2(332, 240), ""], [21.0, "", Vector2(318, 112), "inside"]],
	"bo": [[0.0, "", Vector2(250, 112), "inside"], [8.0, "", Vector2(150, 274), ""], [11.0, "", Vector2(420, 200), ""], [14.0, "", Vector2(384, 376), ""], [17.0, "", Vector2(160, 142), ""], [19.0, "", Vector2(250, 112), "inside"]],
	"barnaby": [[0.0, "", Vector2(70, 212), "inside"], [8.0, "Bank", Vector2(96, 40), ""], [17.0, "", Vector2(432, 240), "week"], [17.0, "", Vector2(392, 372), "sun"], [20.0, "", Vector2(70, 212), "inside"]],
	"odette": [[0.0, "", Vector2(704, 162), "inside"], [6.0, "", Vector2(664, 278), ""], [10.0, "", Vector2(640, 264), ""], [17.0, "", Vector2(388, 380), ""], [21.0, "", Vector2(704, 162), "inside"]],
	"wren": [[0.0, "Tavern", Vector2(96, 44), ""]],
	# The islands.
	"tilly": [[0.0, "Fields", Vector2(72, 104), "inside"], [6.0, "Fields", Vector2(60, 60), ""], [11.0, "Landing", Vector2(119, 62), ""], [14.0, "Orchard", Vector2(96, 76), ""], [18.0, "Landing", Vector2(100, 66), ""], [21.0, "Fields", Vector2(72, 104), "inside"]],
	"silas": [[0.0, "Landing", Vector2(116, 40), "inside"], [5.0, "Lagoon", Vector2(34, 80), ""], [10.0, "Landing", Vector2(116, 48), ""], [16.0, "Lagoon", Vector2(44, 72), ""], [21.0, "Landing", Vector2(116, 40), "inside"]],
	"luma": [[0.0, "Lighthouse", Vector2(124, 62), ""], [8.0, "Lighthouse", Vector2(96, 70), ""], [14.0, "Landing", Vector2(112, 66), ""], [20.0, "Lighthouse", Vector2(124, 62), ""]],
	"moss": [[0.0, "Landing", Vector2(119, 42), "inside"], [7.0, "Bayou", Vector2(100, 56), ""], [12.0, "Landing", Vector2(100, 66), ""], [20.0, "Landing", Vector2(119, 42), "inside"]],
	"brann": [[0.0, "Landing", Vector2(112, 40), "inside"], [6.0, "Landing", Vector2(104, 64), ""], [18.0, "Springs", Vector2(70, 52), ""], [22.0, "Landing", Vector2(112, 40), "inside"]],
	"mara": [[0.0, "Springs", Vector2(60, 44), "inside"], [7.0, "Springs", Vector2(28, 50), ""], [14.0, "Springs", Vector2(88, 70), ""], [17.0, "Springs", Vector2(28, 50), ""], [22.0, "Springs", Vector2(60, 44), "inside"]],
	"opal": [[0.0, "Landing", Vector2(116, 42), "inside"], [6.0, "Lagoon", Vector2(60, 80), ""], [11.0, "Landing", Vector2(104, 66), ""], [19.0, "Landing", Vector2(116, 42), "inside"]],
	"grim": [[0.0, "Landing", Vector2(112, 88), ""], [9.0, "TidePools", Vector2(100, 70), ""], [15.0, "Landing", Vector2(112, 88), ""]],
	"yuki": [[0.0, "Icefield", Vector2(130, 106), "inside"], [7.0, "Landing", Vector2(100, 66), ""], [13.0, "Icefield", Vector2(80, 70), ""], [18.0, "Landing", Vector2(100, 66), ""], [21.0, "Icefield", Vector2(130, 106), "inside"]],
}


static func has(id : String) -> bool:
	return PEOPLE.has(id)

# The stop that applies at this time: [hour, room, point, how].
static func stop_at(id : String, day : int, time : float) -> Array:
	var sunday : bool = Calendar.weekday(day) == 6
	var chosen : Array = []
	for stop in PEOPLE.get(id, []):
		var how : String = stop[3]
		if (how == "sun" and not sunday) or (how == "week" and sunday):
			continue
		if float(stop[0]) <= time:
			chosen = stop
	if chosen.is_empty():
		var list : Array = PEOPLE.get(id, [])
		return list[0] if not list.is_empty() else []
	return chosen

static func inside(stop : Array) -> bool:
	return not stop.is_empty() and stop[3] == "inside"
