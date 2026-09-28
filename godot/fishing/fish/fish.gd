extends Item
class_name Fish

const HEAVY_BIAS : float = 1.6

#------------------------#
var species : FishData
var weight : float = 0.0
#------------------------#


# Lighter fish are more common than heavy ones.
static func caught(data : FishData) -> Fish:
	var fish : Fish = Fish.new()
	fish.species = data
	fish.displayName = data.displayName
	fish.icon = data.icon
	fish.rarity = data.rarity
	fish.weight = lerpf(data.weightRange.x, data.weightRange.y, pow(randf(), HEAVY_BIAS))
	return fish

# 0 for the lightest of its kind, 1 for the heaviest.
func heft() -> float:
	return clampf(inverse_lerp(species.weightRange.x, species.weightRange.y, weight), 0.0, 1.0) if species.weightRange.y > species.weightRange.x else 0.5

# The base price is what a fish of average weight sells for.
func price() -> int:
	var average : float = (species.weightRange.x + species.weightRange.y) * 0.5
	return maxi(roundi(species.basePrice * weight / average), 1) if average > 0.0 else species.basePrice

func details() -> PackedStringArray:
	var lines : PackedStringArray = super()
	lines.append_array(["Weight", weight_text(), "Price", "$%d" % price()])
	return lines

func weight_text() -> String:
	return "%.2fkg" % weight
