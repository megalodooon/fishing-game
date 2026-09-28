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
# The hours it bites between, from x to y. Wraps past midnight when y is
# smaller than x. The same hour twice (like 0 to 24) means any time.
@export var hours : Vector2 = Vector2(0.0, 24.0)

@export_group("Catching")
@export_range(-1.0, 1.0) var difficultyOffset : float = 0.0
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

# Picks a rarity by the rarities' chances (only those that have fish biting
# at this time), then a fish of that rarity by spawn rate.
static func roll(pool : Array[FishData], time : float = -1.0) -> FishData:
	var chances : Dictionary[Rarity, float] = {}
	for data in pool:
		if data and data.rarity and data.spawnRate > 0.0 and data.bites_at(time):
			chances[data.rarity] = data.rarity.chance
	var chosen : Rarity = pick(chances)
	var rates : Dictionary[FishData, float] = {}
	for data in pool:
		if data and data.rarity == chosen and data.spawnRate > 0.0 and data.bites_at(time):
			rates[data] = data.spawnRate
	return pick(rates)

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
