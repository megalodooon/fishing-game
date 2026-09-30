extends Item
class_name ForageTool

# A foraging tool: carried in the bag, it lets the player gather from spots
# that need its tier (see ForageSpot), adds to every gathering and makes the
# rare finds more likely. Only the best one carried counts.

const NAMES : PackedStringArray = ["bare hands", "Iron Sickle", "Coral Knife", "Tidecutter"]

#------------------------#
@export_range(1, 3) var tier : int = 1
@export var yieldBonus : int = 1
@export var rareBoost : float = 1.25
#------------------------#


static func best(player : Player) -> ForageTool:
	var found : ForageTool = null
	for item in player.inventory.items:
		var tool : ForageTool = item as ForageTool
		if tool and (not found or tool.tier > found.tier):
			found = tool
	return found

static func best_tier(player : Player) -> int:
	var tool : ForageTool = best(player)
	return tool.tier if tool else 0

static func name_for(level : int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]

func default_type() -> String:
	return "Foraging Tool"

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Tier", "%d" % tier, "Extra per gathering", "+%d" % yieldBonus, "Rare finds", "x%s" % String.num(rareBoost, 2), "Works from the bag", ""])
	lines.append_array(super())
	return lines
