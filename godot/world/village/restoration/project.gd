extends Resource
class_name Project

# Something to fix up around the village, paid for at the restoration board
# with coins and materials. Finishing it sets its flag ("project/<file
# name>"), which buildings, shops and places can wait for. Some also give
# lasting bonuses (BONUSES).

const BONUSES : Dictionary = {
	"project/lamp_posts": {&"luck": 2.0},
	"project/lighthouse_lamp": {&"seaCreature": 0.5, &"luck": 2.0},
	"project/greenhouse": {&"harvestBonus": 10.0},
	"project/fountain": {&"luck": 3.0, &"sellBonus": 3.0},
	"project/market_hall": {&"sellBonus": 2.0},
	"project/festival_stage": {&"xpBonus": 5.0},
}


static func bonus(progress : Progress, stat : StringName) -> float:
	var total : float = 0.0
	for flag in BONUSES:
		if progress.has_flag(flag):
			total += BONUSES[flag].get(stat, 0.0)
	return total

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var coins : int = 0
@export var items : Array[Item] = []
@export var amounts : Array[int] = []
# What finishing it does, for the board.
@export var unlockText : String = ""
# Shown once these are done, and once this flag is set.
@export var requires : Array[Project] = []
@export var requiredFlag : String = ""
# What the board says about that flag while it's missing, like "Finish Reef Rumors".
@export var requiredText : String = ""
# A skill level needed before it can be funded.
@export var requiredSkill : StringName = &""
@export var requiredLevel : int = 0
#------------------------#


func key() -> String:
	return "project/" + resource_path.get_file().get_basename()

func done(progress : Progress) -> bool:
	return progress.has_flag(key())

func available(progress : Progress) -> bool:
	return missing(progress).is_empty()

# What still stands in the way, as pairs of what's needed and how far along.
func missing(progress : Progress) -> Array[PackedStringArray]:
	var needs : Array[PackedStringArray] = []
	for project in requires:
		if project and not project.done(progress):
			needs.append(PackedStringArray([project.displayName, "Restore first"]))
	if not Unlocks.skill_met(progress, requiredSkill, requiredLevel):
		needs.append(Unlocks.skill_need(progress, requiredSkill, requiredLevel))
	if not requiredFlag.is_empty() and not progress.has_flag(requiredFlag):
		needs.append(PackedStringArray([requiredText if not requiredText.is_empty() else "Something first", "Not yet"]))
	return needs

func amount(index : int) -> int:
	return amounts[index] if index < amounts.size() else 1

func affordable(player : Player) -> bool:
	if not player.wallet.can_afford(coins):
		return false
	for i in items.size():
		if items[i] and player.inventory.count(items[i]) < amount(i):
			return false
	return true

func pay(player : Player) -> bool:
	if done(player.progress) or not affordable(player):
		return false
	player.wallet.spend(coins)
	for i in items.size():
		if items[i]:
			player.inventory.take(items[i], amount(i))
	player.progress.set_flag(key())
	player.progress.count("projects")
	return true
