extends Resource
class_name PetData

# A pet from the pet shop. The active one walks (or flies) along beside the
# player and gives its buffs. Pets grow with the fish caught while they're
# out: every level makes their buffs stronger.

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var sprite : Texture2D
@export var flies : bool = false
# Lights up at night, like a lantern.
@export var glows : bool = false
@export var glowColor : Color = Color(0.6, 1.0, 0.9)
@export var price : int = 1000
# Fish caught with it out to reach each level after the first.
@export var levelCatches : PackedInt32Array = PackedInt32Array([25, 75])
# How much stronger its buffs get per level after the first.
@export_range(0.0, 2.0, 0.05) var levelStrength : float = 0.5

@export_group("Buffs at level 1")
# Multipliers. 1 changes nothing.
@export_range(0.1, 4.0, 0.05) var biteSpeed : float = 1.0
@export_range(0.1, 4.0, 0.05) var castEnergy : float = 1.0
@export_range(0.1, 4.0, 0.05) var walkSpeed : float = 1.0
# How much likelier each rarity bites.
@export var rarityBoost : Dictionary[Rarity, float] = {}
# Stats that add up, in Stats units (percent points), like treasure 1.5.
@export var bonuses : Dictionary[StringName, float] = {}
#------------------------#


func level_for(catches : int) -> int:
	var level : int = 1
	for needed in levelCatches:
		if catches >= needed:
			level += 1
	return level

func max_level() -> int:
	return levelCatches.size() + 1

# A level 1 multiplier grown to this level.
func scaled(value : float, level : int) -> float:
	return 1.0 + (value - 1.0) * (1.0 + levelStrength * (level - 1))

func stat(property : StringName, level : int) -> float:
	var value : Variant = get(property)
	return scaled(value, level) if value is float else 1.0

func bonus(which : StringName, level : int) -> float:
	return bonuses.get(which, 0.0) * (1.0 + levelStrength * (level - 1))

func boost(data : FishData, level : int) -> float:
	return scaled(rarityBoost.get(data.rarity, 1.0), level)

# Its buffs as label and value pairs, at this level.
func buff_lines(level : int) -> Array:
	var lines : Array = []
	for pair in [["Bite speed", &"biteSpeed"], ["Cast energy", &"castEnergy"], ["Walk speed", &"walkSpeed"]]:
		var value : float = stat(pair[1], level)
		if not is_equal_approx(value, 1.0):
			lines.append([pair[0], "x%.2f" % value])
	for each in rarityBoost:
		lines.append([each.displayName + " fish", "x%.2f" % scaled(rarityBoost[each], level)])
	for which in bonuses:
		lines.append([Stats.name_of(which), Stats.bonus_text(which, bonus(which, level))])
	return lines
