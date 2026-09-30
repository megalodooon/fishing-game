extends Resource
class_name TrophyFish

# A trophy fish (like SkyBlock's Crimson Isle trophies): one per fishing
# ground, and it only comes up when its condition is met (a time, the
# weather, a perfect cast, a bait, grandpa's rod...). It's caught as a bronze,
# silver, gold or diamond one (see TrophyFishing), each its own item, and
# Odette at the Trophy Lodge fillets them for Trophy Scales.

enum Special { NONE, STARTER_ROD, EVENT, SUNDAY_NIGHT }

#------------------------#
@export var displayName : String = ""
@export var icon : Texture2D
@export_multiline var lore : String = ""
# Where it lives: catches on this ground's journal page count.
@export var biome : Biome
# What it takes, told to the player at the lodge.
@export var hint : String = ""
@export var hours : Vector2 = Vector2(0.0, 0.0)
@export var requirements : Array[FishRequirement] = []
@export var special : Special = Special.NONE
# The chance per fish landed while the condition is met, 0 to 1.
@export_range(0.0, 1.0, 0.001) var chance : float = 0.04
# One item per tier: bronze, silver, gold, diamond.
@export var tiers : Array[Item] = []
# Trophy Scales for filleting each tier.
@export var scales : PackedInt32Array = PackedInt32Array([4, 8, 16, 32])
#------------------------#


func key() -> String:
	return resource_path.get_file().get_basename()

func on_hour(time : float) -> bool:
	if time < 0.0 or is_equal_approx(fposmod(hours.x, 24.0), fposmod(hours.y, 24.0)):
		return true
	var from : float = fposmod(hours.x, 24.0)
	var to : float = fposmod(hours.y, 24.0)
	return (time >= from and time < to) if from < to else (time >= from or time < to)

# Whether it can come up for a catch landed here, like this.
func can_bite(context : FishingContext, where : Biome, rod : RodItem) -> bool:
	if not biome or not where or where.journal_page() != biome.journal_page():
		return false
	if not on_hour(context.time if context else -1.0):
		return false
	for requirement in requirements:
		if requirement and not requirement.met(context):
			return false
	match special:
		Special.STARTER_ROD:
			return rod != null and rod.original().resource_path.ends_with("starter_rod.tres")
		Special.EVENT:
			return context != null and not EventDirector.active(context.player.get_tree()).is_empty()
		Special.SUNDAY_NIGHT:
			return context != null and context.weekday == 6 and (context.time >= 20.0 or context.time < 4.0)
	return true
