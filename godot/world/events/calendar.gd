extends RefCounted
class_name Calendar

# The year: four seasons of one week each, so every season has its own
# tournament week and Sunday market, and a festival (see GameEvent). Day 1 is
# the Monday that starts spring.

const SEASON_DAYS : int = 7
const SEASONS : PackedStringArray = ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_COLORS : Array[Color] = [Color(0.56, 0.86, 0.46), Color(1.0, 0.8, 0.3), Color(0.95, 0.55, 0.25), Color(0.7, 0.86, 1.0)]
const YEAR_DAYS : int = SEASON_DAYS * 4


static func day_of_year(day : int) -> int:
	return posmod(day - 1, YEAR_DAYS) + 1

static func year(day : int) -> int:
	@warning_ignore("integer_division")
	return (day - 1) / YEAR_DAYS + 1

static func season(day : int) -> int:
	@warning_ignore("integer_division")
	return (day_of_year(day) - 1) / SEASON_DAYS

static func day_of_season(day : int) -> int:
	return posmod(day_of_year(day) - 1, SEASON_DAYS) + 1

static func season_name(day : int) -> String:
	return SEASONS[season(day)]

# Like "Spring 3, Year 1".
static func date_text(day : int) -> String:
	return "%s %d, Year %d" % [season_name(day), day_of_season(day), year(day)]

# The events running on a day (at any hour).
static func events_on(day : int) -> Array[GameEvent]:
	var list : Array[GameEvent] = []
	for event in GameEvent.all():
		if event.on_day(day):
			list.append(event)
	return list

# The events running right now.
static func active(tree : SceneTree) -> Array[GameEvent]:
	var list : Array[GameEvent] = []
	var cycle : DayNightCycle = DayNightCycle.find(tree)
	if not cycle:
		return list
	for event in GameEvent.all():
		if event.active(cycle.day, cycle.time):
			list.append(event)
	return list

# Days until an event next starts, 0 while it runs today.
static func days_until(event : GameEvent, day : int) -> int:
	for ahead in YEAR_DAYS + 1:
		if event.on_day(day + ahead):
			return ahead
	return YEAR_DAYS
