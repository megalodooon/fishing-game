extends Resource
class_name SeaCreature

# Something bigger than a fish that sometimes takes the bait instead (the Sea
# creature chance stat). Hooking one starts a fight minigame. Beating it pays
# out coins, Hunting XP and its drops, and counts in the bestiary.

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var rarity : Rarity
# Fishing level needed before it shows up at all.
@export var minFishing : int = 1
@export_range(0.0, 100.0, 0.01, "or_greater") var spawnRate : float = 1.0
@export var hours : Vector2 = Vector2(0.0, 24.0)
@export var requirements : Array[FishRequirement] = []
# Shown in big letters when it bites.
@export var announce : String = ""

@export_group("Fight")
# The fight minigame. Empty picks one of the catch state's boss games.
@export var fight : PackedScene
@export_range(0.0, 1.0) var difficulty : float = 0.4
# Scales its health in duel fights and how long bullet fights last.
@export_range(0.25, 4.0, 0.05) var toughness : float = 1.0
# Which attack set it uses, like "ember", "frost", "abyss", "storm" or "reef".
@export var style : StringName = &""

@export_group("Rewards")
@export var coins : Vector2i = Vector2i(10, 30)
@export var xp : float = 40.0
@export var drops : Array[Item] = []
# Per drop: the chance (0-1) and the amount range.
@export var dropChances : PackedFloat32Array = PackedFloat32Array()
@export var dropAmounts : Array[Vector2i] = []
#------------------------#


func bites_at(time : float) -> bool:
	if time < 0.0 or is_equal_approx(fposmod(hours.x, 24.0), fposmod(hours.y, 24.0)):
		return true
	var from : float = fposmod(hours.x, 24.0)
	var to : float = fposmod(hours.y, 24.0)
	return (time >= from and time < to) if from < to else (time >= from or time < to)

func can_appear(context : FishingContext, fishingLevel : int) -> bool:
	if fishingLevel < minFishing or not bites_at(context.time if context else -1.0):
		return false
	for requirement in requirements:
		if requirement and not (context and requirement.met(context)):
			return false
	return true

static func roll(pool : Array[SeaCreature], context : FishingContext, fishingLevel : int) -> SeaCreature:
	var weights : Dictionary = {}
	for creature in pool:
		if creature and creature.spawnRate > 0.0 and creature.can_appear(context, fishingLevel):
			weights[creature] = creature.spawnRate * (creature.rarity.chance if creature.rarity else 1.0)
	return FishData.pick(weights) if not weights.is_empty() else null

# What it drops this time, as [item, amount] pairs. Luck raises the chances.
func roll_drops(luck : float) -> Array:
	var got : Array = []
	for i in drops.size():
		var chance : float = dropChances[i] if i < dropChances.size() else 1.0
		if drops[i] and randf() < minf(chance * (luck if chance < 1.0 else 1.0), 1.0):
			var span : Vector2i = dropAmounts[i] if i < dropAmounts.size() else Vector2i.ONE
			got.append([drops[i], randi_range(span.x, span.y)])
	return got

func drop_lines() -> Array:
	var lines : Array = []
	for i in drops.size():
		if drops[i]:
			var chance : float = dropChances[i] if i < dropChances.size() else 1.0
			lines.append([drops[i].displayName, "always" if chance >= 1.0 else "%s%%" % String.num(chance * 100.0, 1)])
	return lines
