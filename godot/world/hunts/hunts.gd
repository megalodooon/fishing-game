extends RefCounted
class_name Hunts

# Sea hunts (like SkyBlock's slayer quests), taken at the hunters' board in
# the harbor. A hunt picks a family of sea creatures and a tier: beating
# creatures of that family fills its hunt meter, and once it's full the
# family's boss can take the bait anywhere (a boss is tougher at higher
# tiers). Beating it pays Sea Essence, coins, its trophy part and hunt XP;
# every family's hunt level raises fight damage. One hunt at a time.
# Saved as progress flags: "hunt/active" and "hunt/xp/<family>".

const COLOR : Color = Color(0.95, 0.4, 0.35)
const ROMAN : PackedStringArray = ["", "I", "II", "III", "IV"]
const COST : PackedInt32Array = [0, 600, 3500, 14000, 45000]
const HUNTING_NEEDED : PackedInt32Array = [0, 2, 9, 17, 26]
const METER : PackedInt32Array = [0, 150, 700, 2200, 6500]
const ESSENCE : PackedInt32Array = [0, 8, 22, 55, 140]
const HUNT_XP : PackedInt32Array = [0, 40, 120, 320, 800]
# Hunt XP for each family's hunt level, and the damage every level adds.
const LEVELS : PackedInt32Array = [0, 100, 350, 900, 2000, 4000]
const DAMAGE_PER_LEVEL : float = 3.0
const BOSS_BITE : float = 0.35
# id: name, creature styles, boss, boss part, color.
const FAMILIES : Dictionary = {
	"reef": ["Reef Hunt", [&"reef", &""], "res://world/hunts/bosses/reef_tyrant.tres", "res://items/hunts/tyrant_fang.tres", Color(1.0, 0.55, 0.45)],
	"sludge": ["Sludge Hunt", [&"sludge"], "res://world/hunts/bosses/sludge_titan.tres", "res://items/hunts/titan_core.tres", Color(0.6, 0.8, 0.35)],
	"frost": ["Frost Hunt", [&"frost"], "res://world/hunts/bosses/frostmaw.tres", "res://items/hunts/frostmaw_pearl.tres", Color(0.6, 0.85, 1.0)],
	"ember": ["Ember Hunt", [&"ember"], "res://world/hunts/bosses/magma_colossus.tres", "res://items/hunts/colossus_ember.tres", Color(1.0, 0.55, 0.2)],
	"deep": ["Deep Hunt", [&"abyss", &"storm", &"ghost"], "res://world/hunts/bosses/drowned_king.tres", "res://items/hunts/drowned_crown.tres", Color(0.6, 0.5, 1.0)],
}

static var bossCopy : SeaCreature
static var bossBase : SeaCreature


static func active(progress : Progress) -> Dictionary:
	return progress.get_flag("hunt/active", {})

static func family_of(creature : SeaCreature) -> String:
	for id in FAMILIES:
		if (FAMILIES[id][1] as Array).has(creature.style):
			return id
	return ""

static func hunt_xp(progress : Progress, family : String) -> int:
	return int(progress.get_flag("hunt/xp/" + family, 0))

static func hunt_level(progress : Progress, family : String) -> int:
	var xp : int = hunt_xp(progress, family)
	var at : int = 0
	for i in range(1, LEVELS.size()):
		if xp >= LEVELS[i]:
			at = i
	return at

static func damage_bonus(progress : Progress) -> float:
	var total : int = 0
	for id in FAMILIES:
		total += hunt_level(progress, id)
	return total * DAMAGE_PER_LEVEL

static func highest_done(progress : Progress, family : String) -> int:
	return int(progress.get_flag("hunt/done/" + family, 0))

# Why a hunt can't be started, or nothing.
static func blocked(player : Player, family : String, tier : int) -> String:
	if not active(player.progress).is_empty():
		return "Finish the hunt you're on first"
	if tier > 1 and highest_done(player.progress, family) < tier - 1:
		return "Beat tier %s first" % ROMAN[tier - 1]
	if Skills.level(player, Skills.HUNTING) < HUNTING_NEEDED[tier]:
		return "Needs Hunting %d" % HUNTING_NEEDED[tier]
	if not player.wallet.can_afford(COST[tier]):
		return "Needs $%s" % UiKit.coins_text(COST[tier])
	return ""

static func start(player : Player, family : String, tier : int) -> bool:
	if not blocked(player, family, tier).is_empty():
		return false
	player.wallet.spend(COST[tier])
	player.progress.set_flag("hunt/active", {"family": family, "tier": tier, "meter": 0, "boss": false})
	return true

static func cancel(player : Player) -> void:
	player.progress.flags.erase("hunt/active")
	player.progress.emit_changed()

# A creature was beaten: fills the meter of a hunt on its family.
static func notify(player : Player, event : StringName, data : Variant) -> void:
	if event != &"beat" or not data is SeaCreature:
		return
	var hunt : Dictionary = active(player.progress)
	if hunt.is_empty() or hunt.boss or family_of(data) != hunt.family:
		return
	hunt.meter = int(hunt.meter) + roundi((data as SeaCreature).xp)
	if int(hunt.meter) >= METER[int(hunt.tier)]:
		hunt.boss = true
		var board : NoticeBoard = NoticeBoard.find(player.get_tree())
		var boss : SeaCreature = load(FAMILIES[hunt.family][2]) as SeaCreature
		if board and boss:
			board.post("The %s stirs..." % boss.displayName, "Your %s is ready. Keep fishing: the boss can take the bait anywhere." % FAMILIES[hunt.family][0], COLOR, boss.icon)
	player.progress.set_flag("hunt/active", hunt)

# The boss to bite now, made tougher for the hunt's tier, or null.
static func boss_bite(player : Player) -> SeaCreature:
	var hunt : Dictionary = active(player.progress)
	if hunt.is_empty() or not hunt.boss or randf() >= BOSS_BITE:
		return null
	var base : SeaCreature = load(FAMILIES[hunt.family][2]) as SeaCreature
	if not base:
		return null
	var tier : int = int(hunt.tier)
	bossBase = base
	bossCopy = base.duplicate() as SeaCreature
	bossCopy.displayName = "%s %s" % [base.displayName, ROMAN[tier]]
	bossCopy.toughness = base.toughness * (1.0 + 0.45 * (tier - 1))
	bossCopy.difficulty = minf(base.difficulty + 0.07 * (tier - 1), 0.95)
	bossCopy.coins = base.coins * tier
	bossCopy.xp = base.xp * tier
	bossCopy.announce = "BOSS: the %s!" % bossCopy.displayName
	return bossCopy

static func is_boss(creature : SeaCreature) -> bool:
	return creature != null and creature == bossCopy

# The boss fight ended. Pays out on a win and ends the hunt.
static func boss_fought(player : Player, won : bool) -> void:
	var hunt : Dictionary = active(player.progress)
	if hunt.is_empty() or not won:
		return
	var tier : int = int(hunt.tier)
	var family : String = hunt.family
	var names : PackedStringArray = PackedStringArray()
	var essence : Item = load(Enchanting.ESSENCE) as Item
	if essence:
		Counter.deliver(player, essence, ESSENCE[tier])
		names.append("%d Sea Essence" % ESSENCE[tier])
	var part : Item = load(FAMILIES[family][3]) as Item
	var parts : int = [0, 1, 2, 4, 8][tier]
	if part and Counter.fits(player, part, parts):
		Counter.deliver(player, part, parts)
		names.append("%s x%d" % [part.displayName, parts])
	var before : int = hunt_level(player.progress, family)
	player.progress.set_flag("hunt/xp/" + family, hunt_xp(player.progress, family) + HUNT_XP[tier])
	player.progress.set_flag("hunt/done/" + family, maxi(highest_done(player.progress, family), tier))
	player.progress.count("hunts_done")
	player.progress.count("hunt_boss_%d" % tier)
	player.progress.flags.erase("hunt/active")
	AnglerLevel.forget()
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if board:
		board.post("Hunt complete!", "%s %s: %s" % [FAMILIES[family][0], ROMAN[tier], ", ".join(names)], COLOR, part.icon if part else null)
		if hunt_level(player.progress, family) > before:
			board.post("%s level %d" % [FAMILIES[family][0], hunt_level(player.progress, family)], "+%d%% fight damage" % roundi(DAMAGE_PER_LEVEL), COLOR)
