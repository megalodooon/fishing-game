extends RefCounted
class_name FishingContext

# Everything a fish might care about before it bites: when, where, how good
# the cast was and what's on the rod.

#------------------------#
# The hour as a fraction, -1 without a clock.
var time : float = -1.0
var day : int = 1
# 0 for Monday up to 6 for Sunday, -1 without a clock.
var weekday : int = -1
var spot : FishingSpot
var score : int = 0
var baits : Array[Bait] = []
var pet : PetData
var petLevel : int = 0
var player : Player
var weather : int = Weather.State.CLEAR
# How much likelier rare, legendary and trophy fish are (fog, lucky meals).
var luck : float = 1.0
#------------------------#


static func make(who : Player, line : FishingRod, where : FishingSpot) -> FishingContext:
	var context : FishingContext = FishingContext.new()
	var cycle : DayNightCycle = DayNightCycle.find(who.get_tree())
	if cycle:
		context.time = cycle.time
		context.day = cycle.day
		context.weekday = cycle.weekday()
	context.spot = where
	context.score = line.castScore if line else 0
	context.player = who
	var sky : Weather = Weather.find(who.get_tree())
	if sky:
		context.weather = sky.state
	context.luck = Stats.of(who, &"luck")
	if who.progress and who.progress.activePet:
		context.pet = who.progress.activePet
		context.petLevel = who.progress.pet_level(context.pet)
	var rod : FishingRod = who.heldItem as FishingRod
	if rod:
		for part in rod.parts():
			if part is Bait:
				context.baits.append(part)
	return context

func has_bait(bait : Bait) -> bool:
	return baits.has(bait)
