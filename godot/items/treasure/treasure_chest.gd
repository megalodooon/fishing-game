extends Item
class_name TreasureChest

# Sometimes reeled up along with a catch (the Treasure chance stat). Opened by
# clicking with it held: it pays out coins and a few rolls on its loot table,
# heavier chests roll more and better. See pick() for which chest comes up.

const TIERS : PackedStringArray = [
	"res://items/treasure/driftwood_crate.tres",
	"res://items/treasure/iron_chest.tres",
	"res://items/treasure/golden_chest.tres",
	"res://items/treasure/ancient_coffer.tres",
	"res://items/treasure/leviathan_hoard.tres",
]
# How likely each tier is before the sea's treasure tier and luck shift it.
const ODDS : PackedFloat32Array = [70.0, 22.0, 6.5, 1.3, 0.2]

#------------------------#
@export var coins : Vector2i = Vector2i(10, 40)
@export var rolls : Vector2i = Vector2i(1, 2)
@export var loot : Array[Item] = []
@export var lootWeights : PackedFloat32Array = PackedFloat32Array()
@export var lootAmounts : Array[Vector2i] = []
@export var openColor : Color = Color(1.0, 0.86, 0.36)
#------------------------#


func default_type() -> String:
	return "Treasure"

# A chest for a catch in a sea of this treasure tier (0 near home, up to 4 in
# the deep), with luck pushing toward the better ones.
static func pick(seaTier : int, luck : float) -> TreasureChest:
	var weights : Dictionary = {}
	for i in TIERS.size():
		var odds : float = ODDS[i] * (1.0 + seaTier * 0.6 * i) * (luck if i > 0 else 1.0)
		if i == TIERS.size() - 1 and seaTier < 3:
			odds = 0.0
		weights[i] = odds
	var which : int = FishData.pick(weights)
	return load(TIERS[which]) as TreasureChest

func use(player : Player) -> bool:
	if player.heldSlot < 0:
		return false
	var got : Array = open_loot()
	for pair in got:
		if not Counter.fits(player, pair[0], pair[1]):
			player.say("bag full", Color(0.95, 0.38, 0.34))
			return true
	player.inventory.take_one(player.heldSlot)
	var money : int = randi_range(coins.x, coins.y)
	player.wallet.add(money)
	var names : PackedStringArray = PackedStringArray(["$%d" % money])
	for pair in got:
		Counter.deliver(player, pair[0], pair[1])
		names.append(pair[0].displayName if pair[1] <= 1 else "%s x%d" % [pair[0].displayName, pair[1]])
	player.progress.count("treasure_opened")
	player.say("+$%d" % money, openColor)
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if board:
		board.post(displayName + " opened!", ", ".join(names), openColor, icon)
	return true

func open_loot() -> Array:
	var got : Array = []
	var weights : Dictionary = {}
	for i in loot.size():
		if loot[i]:
			weights[i] = lootWeights[i] if i < lootWeights.size() else 1.0
	if weights.is_empty():
		return got
	for roll in randi_range(rolls.x, rolls.y):
		var index : int = FishData.pick(weights)
		var span : Vector2i = lootAmounts[index] if index < lootAmounts.size() else Vector2i.ONE
		got.append([loot[index], randi_range(span.x, span.y)])
	return got

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Coins", "$%d-%d" % [coins.x, coins.y], "Rolls", "%d-%d" % [rolls.x, rolls.y]])
	lines.append_array(super())
	return lines
