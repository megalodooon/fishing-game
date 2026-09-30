extends Resource
class_name CrewMember

# Someone who works for the player at the crew board (like Skyblock's
# minions): they gather one material over time, even while the player is
# away or asleep, and keep it until collected. Hired with a contract (crafted
# in the recipe book), then upgraded at the board: the first tiers cost the
# raw material, the later ones its enchanted form. Every new tier reached
# (with any crew member) counts toward more crew slots. Files live in
# res://world/crew/members.

const FOLDER : String = "res://world/crew/members"
const MAX_TIER : int = 7
# What each tier costs to reach from the one before: raw for 2-3, enchanted after.
const RAW_COST : PackedInt32Array = [0, 0, 32, 64]
const ENCHANTED_COST : PackedInt32Array = [0, 0, 0, 0, 4, 8, 16, 32]

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var product : Item
@export var enchanted : Item
# In-game hours per item at tier I. Each tier is 15% faster.
@export var hours : float = 1.0
#------------------------#


static var cache : Array[CrewMember] = []
static var scanned : bool = false


static func all() -> Array[CrewMember]:
	if not scanned:
		scanned = true
		for resource in Catalog.scan(FOLDER):
			if resource is CrewMember:
				cache.append(resource)
	return cache

func key() -> String:
	return resource_path.get_file().get_basename()

func interval(tier : int, speed : float) -> float:
	return hours * pow(0.85, tier - 1) / maxf(1.0 + speed * 0.01, 0.1)

func storage(tier : int) -> int:
	return 24 + 16 * (tier - 1)

func tier_name(tier : int) -> String:
	return "%s %s" % [displayName, Unlocks.roman(tier)]

# What reaching a tier costs: [item, amount], or empty past the top.
func cost(tier : int) -> Array:
	if tier <= 1 or tier > MAX_TIER:
		return []
	if tier < RAW_COST.size():
		return [product, RAW_COST[tier]]
	return [enchanted if enchanted else product, ENCHANTED_COST[tier] if enchanted else ENCHANTED_COST[tier] * 32]
