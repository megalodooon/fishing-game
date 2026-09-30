extends Resource
class_name GameEvent

# Something on the calendar. Festivals come once a year in their season, like
# the Gift Tide in winter; happenings repeat (every few days or on a weekday),
# like the traveling merchant or the fishing derby. While one runs: its fish
# can bite anywhere (fishChance of all bites), every catch can bring up its
# drops, its pickups wait beside a couple of forage spots on every island,
# its stats help the player, its contest counts (see Contests) and its host
# sets up a stall in the village square, paid in coins or the event's own
# things (see ShopOffer.currency). Events live in res://world/events as .tres
# files; see Calendar for the dates.

const FOLDER : String = "res://world/events"

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var color : Color = Color(1.0, 0.85, 0.35)
# 0 spring, 1 summer, 2 autumn, 3 winter.
@export_range(0, 3) var season : int = 0
# Days of the season it runs, from x to y (1 to Calendar.SEASON_DAYS), for
# festivals.
@export var days : Vector2i = Vector2i(7, 8)
# Happenings instead repeat: weekly on this weekday (0 Monday), or every this
# many days from firstDay of the year, for length days.
@export_range(-1, 6) var weekday : int = -1
# Only on the calendar once this progress flag is set (like a building being
# restored), so happenings turn up as the story introduces them.
@export var requiredFlag : String = ""
@export var every : int = 0
@export var firstDay : int = 1
@export var length : int = 1
# Hours of the day it's on, from x to y, wrapping past midnight. The same hour
# twice means all day.
@export var hours : Vector2 = Vector2(0.0, 0.0)

@export_group("Fishing")
# Its fish, on their own journal page (the Festivals bookmark).
@export var page : Biome
# How many bites are its fish instead of the usual ones, 0 to 1.
@export_range(0.0, 1.0, 0.01) var fishChance : float = 0.15
# Things any catch can bring up while it's on, with their chance each (0-1).
@export var drops : Array[Item] = []
@export var dropChances : PackedFloat32Array = PackedFloat32Array()
# Sea creatures that join every sea while it's on.
@export var creatures : Array[SeaCreature] = []

@export_group("Pickups")
# Lying around the islands, a few per screen, new ones every day.
@export var pickup : Item
@export var pickupsPerRoom : int = 2
@export var pickupArt : Texture2D

@export_group("Effects")
# Added to the player's stats while it runs, in the units Stats uses.
@export var stats : Dictionary[StringName, float] = {}
# A contest held while it runs: "derby" (heaviest of a featured fish) or
# "harvest" (most of a featured crop). See Contests.
@export var contest : StringName = &""

@export_group("Host")
# Who runs the stall (a Cast id) and what their stall sells.
@export var host : String = ""
@export var shopTitle : String = ""
@export var shop : Array[ShopOffer] = []
# When above 0, the stall only has this many of its offers each visit, a
# different pick every time (like a traveling merchant).
@export var specialCount : int = 0
@export var startText : String = ""
@export var endText : String = ""
#------------------------#


static var cache : Array[GameEvent] = []
static var scanned : bool = false


static func all() -> Array[GameEvent]:
	if not scanned:
		scanned = true
		for resource in Catalog.scan(FOLDER):
			if resource is GameEvent:
				cache.append(resource)
		cache.sort_custom(func(a : GameEvent, b : GameEvent) -> bool: return a.first_day() < b.first_day())
	return cache

func key() -> String:
	return resource_path.get_file().get_basename()

func is_festival() -> bool:
	return weekday < 0 and every <= 0

# The first and last day of the year it runs (the first time, for happenings).
func first_day() -> int:
	if weekday >= 0:
		return weekday + 1
	if every > 0:
		return firstDay
	return season * Calendar.SEASON_DAYS + days.x

func last_day() -> int:
	if weekday >= 0:
		return weekday + 1
	if every > 0:
		return firstDay + length - 1
	return season * Calendar.SEASON_DAYS + days.y

func unlocked() -> bool:
	if requiredFlag.is_empty():
		return true
	var tree : SceneTree = Engine.get_main_loop() as SceneTree
	var player : Player = Player.find(tree) if tree else null
	return player != null and player.progress != null and player.progress.has_flag(requiredFlag)

func on_day(day : int) -> bool:
	if not unlocked():
		return false
	if weekday >= 0:
		return Calendar.weekday(day) == weekday
	var inYear : int = Calendar.day_of_year(day)
	if every > 0:
		return posmod(inYear - firstDay, every) < length
	return inYear >= first_day() and inYear <= last_day()

# Days left of this run, counting today (for the HUD badge).
func days_left(day : int) -> int:
	var left : int = 0
	while left < Calendar.YEAR_DAYS and on_day(day + left):
		left += 1
	return left

func on_hour(time : float) -> bool:
	if is_equal_approx(fposmod(hours.x, 24.0), fposmod(hours.y, 24.0)):
		return true
	var from : float = fposmod(hours.x, 24.0)
	var to : float = fposmod(hours.y, 24.0)
	return (time >= from and time < to) if from < to else (time >= from or time < to)

func active(day : int, time : float) -> bool:
	return on_day(day) and on_hour(time)

func hours_text() -> String:
	if is_equal_approx(fposmod(hours.x, 24.0), fposmod(hours.y, 24.0)):
		return "All day"
	return "%s-%s" % [Building.hour_text(hours.x), Building.hour_text(hours.y)]

func dates_text() -> String:
	if weekday >= 0:
		return "Every %s" % DayNightCycle.WEEKDAYS[weekday]
	if every > 0:
		return "Every %d days" % every if length <= 1 else "Every %d days, for %d" % [every, length]
	var name : String = Calendar.SEASONS[season]
	return "%s %d" % [name, days.x] if days.x == days.y else "%s %d-%d" % [name, days.x, days.y]

# Rolls its drops for one catch.
func roll_drops(luck : float) -> Array[Item]:
	var got : Array[Item] = []
	for i in drops.size():
		var chance : float = dropChances[i] if i < dropChances.size() else 0.1
		if drops[i] and randf() < minf(chance * luck, 1.0):
			got.append(drops[i])
	return got
