extends RefCounted
class_name Calendar

# The year: four seasons of two weeks each (56 days). Every season has one
# festival in its middle, and smaller happenings come round all year (see
# GameEvent): the traveling merchant, contests, meteor nights, spawning runs.
# Every week has a tournament on Saturday and the market and the council vote
# on Sunday, and every villager has a birthday (see Friendship). Day 1 is the
# Monday that starts spring.

const SEASON_DAYS : int = 14
const SEASONS : PackedStringArray = ["Spring", "Summer", "Autumn", "Winter"]
const SEASON_COLORS : Array[Color] = [Color(0.56, 0.86, 0.46), Color(1.0, 0.8, 0.3), Color(0.95, 0.55, 0.25), Color(0.7, 0.86, 1.0)]
const YEAR_DAYS : int = SEASON_DAYS * 4
const WEEKLY_COLOR : Color = Color(0.62, 0.7, 0.8)
const BIRTHDAY_COLOR : Color = Color(1.0, 0.55, 0.7)

# Event stat bonuses by stat for the hour they were worked out (they only
# change when the hour does).
static var bonusHour : int = -1
static var bonuses : Dictionary = {}


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

static func weekday(day : int) -> int:
	return posmod(day - 1, 7)

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

# The next festivals and happenings from a day on: [event, days away], the
# soonest first, each once.
static func upcoming(day : int, count : int, festivals_only : bool = false) -> Array:
	var list : Array = []
	for event in GameEvent.all():
		if festivals_only and not event.is_festival():
			continue
		var wait : int = days_until(event, day)
		if wait < YEAR_DAYS:
			list.append([event, wait])
	list.sort_custom(func(a : Array, b : Array) -> bool: return a[1] < b[1])
	return list.slice(0, count)

# Everything on a day, for the calendar: festivals and happenings, the weekly
# fixtures and birthdays. Each is {name, color, icon, hours, text, kind, event,
# who}; kind is "festival", "happening", "weekly" or "birthday".
static func entries_on(day : int) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for event in events_on(day):
		list.append({"name": event.displayName, "color": event.color, "icon": event.icon, "hours": event.hours_text(), "text": event.description, "kind": "festival" if event.is_festival() else "happening", "event": event, "who": event.host})
	match weekday(day):
		5:
			list.append({"name": "Tournament", "color": WEEKLY_COLOR, "icon": null, "hours": "Results at 18:00", "text": "The week's tournament closes. Enter at the Tournament Hall any day before.", "kind": "weekly", "event": null, "who": "hale"})
		6:
			list.append({"name": "Sunday market", "color": WEEKLY_COLOR, "icon": null, "hours": "7:00-17:00", "text": "Extra stalls in the square, with rare bait, charms and farm goods.", "kind": "weekly", "event": null, "who": ""})
			list.append({"name": "Council vote", "color": WEEKLY_COLOR, "icon": null, "hours": "All day", "text": "Last day to vote for next week's council seat at the ballot box.", "kind": "weekly", "event": null, "who": ""})
	for who in Friendship.BIRTHDAYS:
		if Friendship.BIRTHDAYS[who] == day_of_year(day):
			list.append({"name": "%s's birthday" % Friendship.short_name(who), "color": BIRTHDAY_COLOR, "icon": null, "hours": "All day", "text": "A gift today means eight times as much.", "kind": "birthday", "event": null, "who": who})
	return list

# What the events running now add to a stat, in its units (see Stats).
static func bonus(tree : SceneTree, stat : StringName) -> float:
	var cycle : DayNightCycle = DayNightCycle.find(tree)
	if not cycle:
		return 0.0
	var hour : int = cycle.day * 24 + floori(cycle.time)
	if hour != bonusHour:
		bonusHour = hour
		bonuses.clear()
		for event in active(tree):
			for key in event.stats:
				bonuses[key] = bonuses.get(key, 0.0) + event.stats[key]
	return bonuses.get(stat, 0.0)
