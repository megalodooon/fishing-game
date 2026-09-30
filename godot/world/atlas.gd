extends Resource
class_name Atlas

# Every place on the sea chart, which of them are unlocked and where the
# boat is. The farther a place is on the chart, the more energy and time the
# trip there takes.

#------------------------#
@export var locations : Array[Location] = []
# Where the game starts. Empty means the first location.
@export var current : Location
@export var unlocked : Array[Location] = []
# Where the boat sailed in from, so the chart shows it waiting on that side.
@export var previous : Location
# The chart scrolls sideways when it's wider than the screen. It grows on its
# own to fit places put beyond it.
@export var mapSize : Vector2 = Vector2(320, 92)

@export_group("Travel")
@export var energyPerPixel : float = 0.1
@export var minEnergy : float = 2.0
# In-game hours per chart pixel, rounded to 5 minutes.
@export var hoursPerPixel : float = 0.01
@export var minHours : float = 0.25

# Share taken off trips by the Travel discount stat, set by the chart.
var discount : float = 0.0
#------------------------#


func setup() -> void:
	unlocked = unlocked.duplicate()
	for location in locations:
		if location.startsUnlocked and not unlocked.has(location):
			unlocked.append(location)
	if not current and not locations.is_empty():
		current = locations[0]

func is_unlocked(location : Location) -> bool:
	return unlocked.has(location)

func distance(to : Location) -> float:
	return current.mapPosition.distance_to(to.mapPosition) if current else 0.0

func energy_cost(to : Location) -> float:
	if to == current or to.freeTravel:
		return 0.0
	return maxf(ceilf(distance(to) * energyPerPixel * trip_scale(to) * (1.0 - discount)), ceilf(minEnergy * trip_scale(to)))

func travel_hours(to : Location) -> float:
	if to == current:
		return 0.0
	return maxf(roundf(distance(to) * hoursPerPixel * trip_scale(to) * (1.0 - discount) * 12.0) / 12.0, roundf(minHours * trip_scale(to) * 12.0) / 12.0)

# The cheaper of the two ends' travel scales.
func trip_scale(to : Location) -> float:
	return minf(to.travelScale, current.travelScale if current else 1.0)

# What still stands in the way of unlocking it besides its coins, as pairs of
# what's needed and how far along it is.
func missing(location : Location, journal : Journal, progress : Progress = null) -> Array[PackedStringArray]:
	var needs : Array[PackedStringArray] = []
	if not Unlocks.skill_met(progress, location.requiredSkill, location.requiredLevel):
		needs.append(Unlocks.skill_need(progress, location.requiredSkill, location.requiredLevel))
	if not Unlocks.league_met(progress, location.requiredLeague):
		needs.append(Unlocks.league_need(location.requiredLeague))
	if location.requiredHull > 0 and BoatParts.tier(progress, BoatParts.HULL) < location.requiredHull:
		needs.append(PackedStringArray(["Needs a %s" % BoatParts.tier_name(BoatParts.HULL, location.requiredHull), "Boatyard"]))
	if not location.requiredFlag.is_empty() and not (progress and progress.has_flag(location.requiredFlag)):
		needs.append(PackedStringArray([location.requiredText if not location.requiredText.is_empty() else "Something first", "Not yet"]))
	if location.requiredBiome and journal:
		var fish : Array[FishData] = location.requiredBiome.fish
		var needed : int = location.requiredFish if location.requiredFish > 0 else fish.size()
		var found : int = journal.found_in(fish, location.requiredBiome)
		if found < needed:
			needs.append(PackedStringArray([location.requiredBiome.displayName + " fish", "%d/%d" % [found, needed]]))
	return needs

func can_unlock(location : Location, journal : Journal, wallet : Wallet, progress : Progress = null) -> bool:
	return not is_unlocked(location) and missing(location, journal, progress).is_empty() and wallet.can_afford(location.coinCost)

func unlock(location : Location, journal : Journal, wallet : Wallet, progress : Progress = null) -> bool:
	if not can_unlock(location, journal, wallet, progress):
		return false
	wallet.spend(location.coinCost)
	unlocked.append(location)
	emit_changed()
	return true

func arrive(location : Location) -> void:
	if location != current:
		previous = current
	current = location
	emit_changed()

# How wide the chart is, counting places put past its edge.
func chart_width() -> float:
	var width : float = mapSize.x
	for location in locations:
		width = maxf(width, location.mapPosition.x + 24.0)
	return width
