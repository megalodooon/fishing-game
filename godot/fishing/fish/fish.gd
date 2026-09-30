extends Item
class_name Fish

const HEAVY_BIAS : float = 1.6
# Keeps the lightest fish from shrinking to a speck in the hand.
const MIN_HELD_SCALE : float = 0.6
const HELD_SCENE : PackedScene = preload("res://fishing/fish/held_fish.tscn")

# Rare versions of a catch. Giants weigh more than their kind usually can,
# shiny and golden ones sell for much more. The journal counts each one found.
const NORMAL : int = 0
const GIANT : int = 1
const SHINY : int = 2
const GOLDEN : int = 3
const VARIANT_NAMES : PackedStringArray = ["", "Giant", "Shiny", "Golden"]
const VARIANT_CHANCE : PackedFloat32Array = [0.0, 0.025, 0.012, 0.0015]
const VARIANT_PRICE : PackedFloat32Array = [1.0, 1.0, 3.0, 8.0]
const VARIANT_COLORS : PackedColorArray = [Color.WHITE, Color(0.72, 1.0, 0.62), Color(0.62, 0.95, 1.0), Color(1.0, 0.84, 0.3)]

#------------------------#
var species : FishData
var weight : float = 0.0
var variant : int = NORMAL
#------------------------#


# Lighter fish are more common than heavy ones. weightBonus (0 and up) pulls
# catches toward the heavy end, luck makes the rare versions likelier.
static func caught(data : FishData, weightBonus : float = 0.0, luck : float = 1.0) -> Fish:
	var roll : float = pow(randf(), HEAVY_BIAS / (1.0 + maxf(weightBonus, 0.0)))
	var which : int = NORMAL
	for kind in [GOLDEN, SHINY, GIANT]:
		if randf() < VARIANT_CHANCE[kind] * luck:
			which = kind
			break
	var fish : Fish = restore(data, lerpf(data.weightRange.x, data.weightRange.y, roll), which)
	if which == GIANT:
		fish.weight = data.weightRange.y * randf_range(1.15, 1.7)
	return fish

static func restore(data : FishData, pounds : float, kind : int) -> Fish:
	var fish : Fish = Fish.new()
	fish.species = data
	fish.variant = kind
	fish.displayName = data.displayName if kind == NORMAL else "%s %s" % [VARIANT_NAMES[kind], data.displayName]
	fish.icon = data.icon
	fish.rarity = data.rarity
	fish.heldScene = HELD_SCENE
	fish.weight = pounds
	return fish

# 0 for the lightest of its kind, 1 for the heaviest.
func heft() -> float:
	return clampf(inverse_lerp(species.weightRange.x, species.weightRange.y, weight), 0.0, 1.0) if species.weightRange.y > species.weightRange.x else 0.5

# The base price is what a fish of average weight sells for.
func price() -> int:
	var average : float = (species.weightRange.x + species.weightRange.y) * 0.5
	var value : float = species.basePrice * weight / average if average > 0.0 else float(species.basePrice)
	return maxi(roundi(value * VARIANT_PRICE[variant]), 1)

# The species' held size at half its max weight, 1.5x that at the max weight.
func held_scale() -> float:
	if not species:
		return 1.0
	var byWeight : float = clampf(0.5 + weight / species.weightRange.y, MIN_HELD_SCALE, 1.5) if species.weightRange.y > 0.0 else 1.0
	return species.heldSize * byWeight

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	if variant != NORMAL:
		lines.append_array([VARIANT_NAMES[variant] + "!", ""])
	lines.append_array(["Weight", weight_text(), "Price", "$%d" % price()])
	return lines

func weight_text() -> String:
	return "%.2fkg" % weight if weight < 100.0 else "%.0fkg" % weight

func default_type() -> String:
	return "Fish"

func same_kind(other : Item) -> bool:
	return other == self
