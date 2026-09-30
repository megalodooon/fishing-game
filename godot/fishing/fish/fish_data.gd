extends Resource
class_name FishData


#------------------------#
@export var displayName : String = ""
@export var icon : Texture2D
@export var rarity : Rarity
@export_multiline var description : String = ""
@export_range(0.0, 100.0, 0.01, "or_greater") var spawnRate : float = 1.0
@export var weightRange : Vector2 = Vector2(0.5, 1.0)
@export var basePrice : int = 10
# How big the species looks in the hand at half its max weight.
@export_range(0.1, 3.0, 0.05) var heldSize : float = 1.0
# The hours it bites between, from x to y. Wraps past midnight when y is
# smaller than x. The same hour twice (like 0 to 24) means any time.
@export var hours : Vector2 = Vector2(0.0, 24.0)
# Everything else that has to be true before it bites, like a weekday, a
# bait or a perfect cast. Meant for trophy fish.
@export var requirements : Array[FishRequirement] = []
# How often it bites while its requirements are met, in place of sharing its
# rarity's chance with the other fish of that rarity. Below 0 it shares.
@export_range(-1.0, 100.0, 0.01, "or_greater") var chance : float = -1.0

@export_group("Catching")
@export_range(-1.0, 1.0) var difficultyOffset : float = 0.0
# The attack set in boss fights, like "ember" or "frost" (see BossMinigame).
@export var style : StringName = &""
@export var minigames : Array[PackedScene] = []
#------------------------#


func difficulty() -> float:
	return clampf((rarity.difficulty if rarity else 0.0) + difficultyOffset, 0.0, 1.0)

func any_time() -> bool:
	return is_equal_approx(fposmod(hours.x, 24.0), fposmod(hours.y, 24.0))

# A time below 0 means there's no clock, so everything bites.
func bites_at(time : float) -> bool:
	if time < 0.0 or any_time():
		return true
	var from : float = fposmod(hours.x, 24.0)
	var to : float = fposmod(hours.y, 24.0)
	return (time >= from and time < to) if from < to else (time >= from or time < to)

func hours_text() -> String:
	if any_time():
		return "Any time"
	return "%02d:%02d-%02d:%02d" % [floori(fposmod(hours.x, 24.0)), roundi(fmod(hours.x, 1.0) * 60.0), floori(fposmod(hours.y, 24.0)), roundi(fmod(hours.y, 1.0) * 60.0)]

func weight_range_text() -> String:
	return "%.2f-%.2fkg" % [weightRange.x, weightRange.y] if weightRange.x < 1.0 else "%.1f-%.1fkg" % [weightRange.x, weightRange.y]

func can_bite(context : FishingContext) -> bool:
	if not bites_at(context.time if context else -1.0):
		return false
	for requirement in requirements:
		if requirement and not (context and requirement.met(context)):
			return false
	return true

# What its requirements ask for, one line each.
func requirement_lines() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	for requirement in requirements:
		if requirement:
			lines.append(requirement.describe())
	return lines

# Each rarity bites by its chance, shared by its fish that are biting right
# now by spawn rate. Fish with their own chance don't share. Bait on the rod
# makes some rarities or fish likelier.
static func roll(pool : Array[FishData], context : FishingContext = null) -> FishData:
	var forced : Array[FishData] = Dev.forced_fish(pool)
	if not forced.is_empty():
		return forced.pick_random()
	var biting : Array[FishData] = []
	var rates : Dictionary[Rarity, float] = {}
	for data in pool:
		if data and data.rarity and data.spawnRate > 0.0 and data.can_bite(context):
			biting.append(data)
			if data.chance < 0.0:
				rates[data.rarity] = rates.get(data.rarity, 0.0) + data.spawnRate
	var weights : Dictionary[FishData, float] = {}
	for data in biting:
		var weight : float = data.chance if data.chance >= 0.0 else data.rarity.chance * data.spawnRate / rates[data.rarity]
		if context:
			for bait in context.baits:
				weight *= bait.boost(data)
			if context.pet:
				weight *= context.pet.boost(data, context.petLevel)
			if data.rarity.difficulty >= 0.5:
				weight *= context.luck
		weights[data] = weight
	return pick(weights)

static func pick(weights : Dictionary) -> Variant:
	var total : float = 0.0
	for key in weights:
		total += weights[key]
	var left : float = randf() * total
	var last : Variant = null
	for key in weights:
		last = key
		left -= weights[key]
		if left < 0.0:
			return key
	return last
