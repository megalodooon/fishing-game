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

# A fund anyone in the world chips into (a world flag, so a friend's coins
# count too). With two players it costs half as much again.
# ponytail: last write wins if both chip in the same instant; fine for 2 players.
func fund_key() -> String:
	return "world/fund/" + resource_path.get_file().get_basename()

func cost_scale(progress : Progress) -> float:
	return 1.5 if NetSession.players_in_world(progress) >= 2 else 1.0

func coin_cost(progress : Progress) -> int:
	return roundi(coins * cost_scale(progress))

func item_cost(progress : Progress, index : int) -> int:
	return ceili(amount(index) * cost_scale(progress))

func funded(progress : Progress) -> Dictionary:
	return progress.get_flag(fund_key(), {})

func coins_left(progress : Progress) -> int:
	return maxi(coin_cost(progress) - int(funded(progress).get("coins", 0)), 0)

func item_left(progress : Progress, index : int) -> int:
	return maxi(item_cost(progress, index) - int(funded(progress).get(str(index), 0)), 0)

# Whether the player has anything left to put in.
func affordable(player : Player) -> bool:
	if coins_left(player.progress) > 0 and player.wallet.coins > 0:
		return true
	for i in items.size():
		if items[i] and item_left(player.progress, i) > 0 and player.inventory.count(items[i]) > 0:
			return true
	return false

func complete(progress : Progress) -> bool:
	if coins_left(progress) > 0:
		return false
	for i in items.size():
		if items[i] and item_left(progress, i) > 0:
			return false
	return true

# Puts in all the coins and materials the player can, up to what's left.
# Returns whether that finished it.
func pay(player : Player) -> bool:
	if done(player.progress) or not affordable(player):
		return false
	var fund : Dictionary = funded(player.progress).duplicate()
	var give : int = mini(coins_left(player.progress), player.wallet.coins)
	player.wallet.spend(give)
	fund["coins"] = int(fund.get("coins", 0)) + give
	for i in items.size():
		if items[i]:
			var part : int = mini(item_left(player.progress, i), player.inventory.count(items[i]))
			if part > 0:
				player.inventory.take(items[i], part)
				fund[str(i)] = int(fund.get(str(i), 0)) + part
	player.progress.set_flag(fund_key(), fund)
	if not complete(player.progress):
		return false
	player.progress.set_flag(key())
	player.progress.count("projects")
	return true
