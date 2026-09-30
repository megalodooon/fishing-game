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
	# Bramblewick (village.tscn): Pier, Square, Home, Lane, Harbor.
	"pip": [[0.0, "Lane", Vector2(40, 92), "inside"], [6.5, "Pier", Vector2(104, 56), ""], [9.0, "Square", Vector2(112, 80), ""], [12.0, "Lane", Vector2(44, 96), ""], [13.5, "Pier", Vector2(119, 68), ""], [18.0, "Square", Vector2(160, 94), ""], [21.0, "Lane", Vector2(40, 92), "inside"]],
	"gus": [[0.0, "Square", Vector2(32, 50), "inside"], [7.0, "Square", Vector2(50, 60), ""], [18.0, "Pier", Vector2(134, 82), ""], [20.0, "Square", Vector2(32, 50), "inside"]],
	"nora": [[0.0, "Square", Vector2(96, 50), "inside"], [8.0, "Square", Vector2(122, 58), ""], [12.0, "Square", Vector2(170, 88), "sun"], [17.0, "Pier", Vector2(72, 94), ""], [19.0, "Square", Vector2(96, 50), "inside"]],
	"vera": [[0.0, "Pier", Vector2(24, 60), "inside"], [10.0, "Square", Vector2(160, 72), ""], [15.0, "Harbor", Vector2(120, 70), ""], [19.0, "Pier", Vector2(24, 60), "inside"]],
	"rex": [[0.0, "Lane", Vector2(28, 50), "inside"], [6.0, "Pier", Vector2(108, 96), ""], [12.0, "Lane", Vector2(30, 58), ""], [15.0, "Pier", Vector2(150, 96), ""], [20.0, "Lane", Vector2(28, 50), "inside"]],
	"hale": [[0.0, "Home", Vector2(163, 68), "inside"], [9.0, "Home", Vector2(140, 82), ""], [13.0, "Harbor", Vector2(60, 74), ""], [16.0, "Home", Vector2(116, 96), ""], [20.0, "Home", Vector2(163, 68), "inside"]],
	"marina": [[0.0, "Lane", Vector2(114, 46), "inside"], [7.0, "Lane", Vector2(140, 56), ""], [18.0, "Lane", Vector2(58, 94), ""], [21.0, "Lane", Vector2(114, 46), "inside"]],
	"bo": [[0.0, "Lane", Vector2(68, 50), "inside"], [8.0, "Lane", Vector2(84, 60), ""], [11.0, "Square", Vector2(176, 90), ""], [14.0, "Pier", Vector2(62, 84), ""], [17.0, "Home", Vector2(40, 80), ""], [19.0, "Lane", Vector2(68, 50), "inside"]],
	"barnaby": [[0.0, "Harbor", Vector2(40, 54), "inside"], [8.0, "Harbor", Vector2(54, 60), ""], [17.0, "Square", Vector2(140, 84), "week"], [17.0, "Pier", Vector2(128, 50), "sun"], [20.0, "Harbor", Vector2(40, 54), "inside"]],
	"odette": [[0.0, "Harbor", Vector2(104, 52), "inside"], [6.0, "Harbor", Vector2(140, 90), ""], [10.0, "Harbor", Vector2(122, 60), ""], [17.0, "Pier", Vector2(90, 100), ""], [21.0, "Harbor", Vector2(104, 52), "inside"]],
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
