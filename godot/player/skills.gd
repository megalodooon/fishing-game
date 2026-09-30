extends RefCounted
class_name Skills

# Nine skills that level up from 1 to 50 as they earn XP, each with a small
# perk per level (see perks). XP comes from what the skill is about: catching,
# harvesting, cooking, sailing, fighting sea creatures, selling, gathering on
# the islands, crafting and brewing.

const FISHING : StringName = &"fishing"
const FARMING : StringName = &"farming"
const COOKING : StringName = &"cooking"
const SAILING : StringName = &"sailing"
const HUNTING : StringName = &"hunting"
const TRADING : StringName = &"trading"
const FORAGING : StringName = &"foraging"
const CRAFTING : StringName = &"crafting"
const ALCHEMY : StringName = &"alchemy"
const LIST : Array[StringName] = [FISHING, FARMING, COOKING, SAILING, HUNTING, TRADING, FORAGING, CRAFTING, ALCHEMY]
const NAMES : Dictionary = {FISHING: "Fishing", FARMING: "Farming", COOKING: "Cooking", SAILING: "Sailing", HUNTING: "Hunting", TRADING: "Trading", FORAGING: "Foraging", CRAFTING: "Crafting", ALCHEMY: "Alchemy"}
const COLORS : Dictionary = {
	FISHING: Color(0.45, 0.78, 1.0), FARMING: Color(0.56, 0.9, 0.4), COOKING: Color(1.0, 0.66, 0.36),
	SAILING: Color(0.55, 0.95, 0.9), HUNTING: Color(0.95, 0.45, 0.42), TRADING: Color(1.0, 0.88, 0.36),
	FORAGING: Color(0.75, 0.6, 0.35), CRAFTING: Color(0.75, 0.75, 0.85), ALCHEMY: Color(0.75, 0.5, 1.0),
}
# XP from level n to n+1 is base * n^CURVE.
const BASE : Dictionary = {FISHING: 25.0, FARMING: 15.0, COOKING: 15.0, SAILING: 10.0, HUNTING: 20.0, TRADING: 15.0, FORAGING: 12.0, CRAFTING: 15.0, ALCHEMY: 15.0}
const CURVE : float = 1.9
const MAX_LEVEL : int = 50
# Per level: the stat it raises and by how much (percent points or share).
const PERKS : Dictionary = {
	FISHING: [[&"seaCreature", 0.2], [&"luck", 0.01]],
	FARMING: [[&"harvestBonus", 2.0]],
	COOKING: [[&"foodPower", 2.0]],
	SAILING: [[&"travelDiscount", 1.0]],
	HUNTING: [[&"damage", 2.0]],
	TRADING: [[&"sellBonus", 1.0]],
	FORAGING: [[&"forageBonus", 2.0]],
	CRAFTING: [[&"craftBonus", 1.0]],
	ALCHEMY: [[&"potionPower", 2.0]],
}
# Extra hearts in sea creature and boss fights at these Hunting levels.
const HEART_LEVELS : PackedInt32Array = [10, 25, 40]


static func step(skill : StringName, from : int) -> float:
	return BASE.get(skill, 20.0) * pow(float(from), CURVE)

# Total XP needed to reach a level (level 1 needs none).
static func total_for(skill : StringName, goal : int) -> float:
	var total : float = 0.0
	for n in range(1, goal):
		total += step(skill, n)
	return total

# Per skill, the last XP asked about and its level. Stats ask for levels
# every physics tick, and XP rarely changes between them.
static var lastLevels : Dictionary = {}

static func level_of(skill : StringName, earned : float) -> int:
	var last : Array = lastLevels.get(skill, [])
	if not last.is_empty() and last[0] == earned:
		return last[1]
	var reached : int = count_levels(skill, earned)
	lastLevels[skill] = [earned, reached]
	return reached

static func count_levels(skill : StringName, earned : float) -> int:
	var reached : int = 1
	var needed : float = step(skill, 1)
	while reached < MAX_LEVEL and earned >= needed:
		earned -= needed
		reached += 1
		needed = step(skill, reached)
	return reached

# How far into the current level, 0 to 1.
static func level_progress(skill : StringName, earned : float) -> float:
	var reached : int = level_of(skill, earned)
	if reached >= MAX_LEVEL:
		return 1.0
	return clampf((earned - total_for(skill, reached)) / step(skill, reached), 0.0, 1.0)

static func xp(player : Player, skill : StringName) -> float:
	return player.progress.skills.get(skill, 0.0)

static func level(player : Player, skill : StringName) -> int:
	return level_of(skill, xp(player, skill))

# A stat raised by skill perks, in the stat's own units.
static func bonus(player : Player, stat : StringName) -> float:
	var total : float = 0.0
	for skill in PERKS:
		for perk in PERKS[skill]:
			if perk[0] == stat:
				total += perk[1] * (level(player, skill) - 1)
	if stat == &"hearts":
		for at in HEART_LEVELS:
			if level(player, HUNTING) >= at:
				total += 1.0
	return total

static func perk_text(skill : StringName) -> String:
	var parts : PackedStringArray = PackedStringArray()
	for perk in PERKS.get(skill, []):
		parts.append(Stats.perk_line(perk[0], perk[1]))
	if skill == HUNTING:
		parts.append("+1 heart at 10, 25, 40")
	return ", ".join(parts) + " per level"

# Adds XP (raised by the xpBonus stat) and announces level ups.
static func add(player : Player, skill : StringName, amount : float) -> void:
	if not player or not player.progress or amount <= 0.0:
		return
	var gained : float = amount * (1.0 + Stats.of(player, &"xpBonus") * 0.01)
	var before : int = level(player, skill)
	player.progress.skills[skill] = xp(player, skill) + gained
	var after : int = level(player, skill)
	player.xp_gained.emit(skill, gained)
	if after > before:
		var coins : int = 0
		for reached in range(before + 1, after + 1):
			coins += SkillRewards.COINS_PER_LEVEL * reached
		if player.wallet:
			player.wallet.add(coins)
		player.progress.emit_changed()
		player.skill_up.emit(skill, after)
