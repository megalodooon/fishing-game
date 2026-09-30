extends RefCounted
class_name CharmPouch

# The charm pouch (like Skyblock's accessory bag): charms kept here work
# without taking bag space, and add Magical Power by rarity. Magical Power
# turns into luck, rare find and skill XP. Of every family only the best
# charm counts, in the pouch or the bag. The pouch grows with the Angler
# Level and pouch upgrades.

const POWER : Dictionary = {"Common": 3, "Uncommon": 5, "Rare": 8, "Legendary": 12, "Trophy": 16}
const BASE_SLOTS : int = 4
# Per point of Magical Power, in Stats units.
const PER_POWER : Dictionary = {&"luck": 0.12, &"rareFind": 0.15, &"xpBonus": 0.06}


# Worked out once per frame: stats are asked for many times a tick.
static var cacheFrame : int = -1
static var cachedCharms : Array[Charm] = []
static var cachedPower : int = 0

static func power_of(charm : Charm) -> int:
	return POWER.get(charm.rarity.displayName if charm.rarity else "Common", 3)

static func slots(player : Player) -> int:
	return BASE_SLOTS + player.progress.counter("pouch_slots") + AnglerLevel.pouch_bonus(player)

# The charms that count: the best of every family, from the pouch and the bag.
static func counted(player : Player) -> Array[Charm]:
	refresh(player)
	return cachedCharms

static func refresh(player : Player) -> void:
	var frame : int = Engine.get_process_frames() * 4 + Engine.get_physics_frames()
	if frame == cacheFrame:
		return
	cacheFrame = frame
	cachedCharms = gather(player)
	cachedPower = pouch_power(player)

# Forgets the cache, after the pouch or the bag changed.
static func dirty() -> void:
	cacheFrame = -1

static func gather(player : Player) -> Array[Charm]:
	var best : Dictionary = {}
	var all : Array[Item] = player.progress.charms.duplicate()
	all.append_array(player.inventory.items)
	for item in all:
		var charm : Charm = item as Charm
		if not charm:
			continue
		var key : String = charm.family_key()
		if not best.has(key) or (best[key] as Charm).tier < charm.tier:
			best[key] = charm.original()
	var list : Array[Charm] = []
	for key in best:
		list.append(best[key])
	return list

# Magical Power from the pouch, counting only each family's best charm.
static func magical_power(player : Player) -> int:
	refresh(player)
	return cachedPower

static func pouch_power(player : Player) -> int:
	var best : Dictionary = {}
	for item in player.progress.charms:
		var charm : Charm = item as Charm
		if charm:
			var key : String = charm.family_key()
			if not best.has(key) or (best[key] as Charm).tier < charm.tier:
				best[key] = charm
	var total : int = 0
	for key in best:
		total += power_of(best[key])
	return total

static func bonus(player : Player, stat : StringName) -> float:
	return PER_POWER.get(stat, 0.0) * magical_power(player)
