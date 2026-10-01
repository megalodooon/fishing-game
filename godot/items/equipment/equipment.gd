extends RefCounted
class_name Equipment

# What the player wears: a hat, gear and two charms. Worn things are out of
# the bag (Progress.equipment) and add their stats; nothing in the bag
# counts. Two charms of the same family can't be worn together. Every charm
# ever found also adds Magical Power for good (the charm collection), which
# turns into a little luck, rare find and skill XP, so collecting them still
# pays without carrying them around.
#
# Some hats and gear do something special (UNIQUES): those are worked out
# here too, with the conditions they need (rain, night...).

const SLOTS : PackedStringArray = ["hat", "gear", "charm1", "charm2"]
const SLOT_NAMES : Dictionary = {"hat": "Hat", "gear": "Gear", "charm1": "Charm", "charm2": "Charm"}
const POWER : Dictionary = {"Common": 3, "Uncommon": 5, "Rare": 8, "Legendary": 12, "Trophy": 16}
# Per point of Magical Power, in Stats units.
const PER_POWER : Dictionary = {&"luck": 0.05, &"rareFind": 0.06, &"xpBonus": 0.03}
# What special hats and gear do, by id.
const UNIQUES : Dictionary = {
	&"storm_fisher": "Rain makes fish bite twice as eagerly.",
	&"lantern": "At night: fish bite faster and sea creatures come closer.",
	&"captain": "Trips on the sea chart take half the time.",
	&"oilskin": "Casting in the rain costs a third less energy.",
	&"diver": "Treasure chests from the deep hold one more thing.",
	&"night_owl": "Stay up two hours later before passing out.",
}

# Worked out once a frame, as stats are asked for all the time.
static var cacheFrame : int = -1
static var cachedPower : int = 0


static func worn(player : Player, slot : String) -> Item:
	return player.progress.equipment.get(slot) as Item if player and player.progress else null

static func worn_items(player : Player) -> Array[Item]:
	var list : Array[Item] = []
	if player and player.progress:
		for slot in SLOTS:
			var item : Item = player.progress.equipment.get(slot) as Item
			if item:
				list.append(item)
	return list

# The slot a thing would go in (a free charm slot first), or "".
static func slot_for(player : Player, item : Item) -> String:
	if item is Gear:
		return "hat" if (item as Gear).slot == Gear.Slot.HAT else "gear"
	if item is Charm:
		var charm : Charm = item
		# A charm of the same family takes that one's place.
		for slot in ["charm1", "charm2"]:
			var other : Charm = worn(player, slot) as Charm
			if other and other.family_key() == charm.family_key():
				return slot
		for slot in ["charm1", "charm2"]:
			if not worn(player, slot):
				return slot
		return "charm1"
	return ""

static func can_wear(item : Item) -> bool:
	return item is Gear or item is Charm

# Puts on what's in this bag slot; whatever was worn there goes back into it.
static func equip(player : Player, bagSlot : int) -> bool:
	var item : Item = player.inventory.get_item(bagSlot)
	if not item or not can_wear(item):
		return false
	var slot : String = slot_for(player, item)
	var old : Item = worn(player, slot)
	player.inventory.items[bagSlot] = old
	player.progress.equipment[slot] = item
	changed(player)
	if bagSlot == player.heldSlot:
		player.equip(player.heldSlot)
	player.say("Wearing %s" % item.displayName, Color(0.56, 0.93, 0.44))
	return true

# Takes it off into the bag. Returns whether there was room.
static func unequip(player : Player, slot : String) -> bool:
	var item : Item = worn(player, slot)
	if not item:
		return false
	var free : int = player.inventory.first_free()
	if free < 0:
		player.say("bag full", Color(0.95, 0.38, 0.34))
		return false
	player.inventory.items[free] = item
	player.progress.equipment.erase(slot)
	changed(player)
	return true

static func changed(player : Player) -> void:
	cacheFrame = -1
	player.inventory.emit_changed()
	player.progress.emit_changed()
	player.refresh_energy_max()

# What everything worn adds to a stat, special effects included.
static func bonus(player : Player, stat : StringName) -> float:
	var total : float = PER_POWER.get(stat, 0.0) * magical_power(player)
	for item in worn_items(player):
		var stats : Dictionary = item.get("stats") if item.get("stats") != null else {}
		total += float(stats.get(stat, 0.0))
	total += unique_bonus(player, stat)
	return total

static func has(player : Player, effect : StringName) -> bool:
	for item in worn_items(player):
		if item is Gear and (item as Gear).unique_effect == effect:
			return true
	return false

# The special effects that are stats under conditions.
static func unique_bonus(player : Player, stat : StringName) -> float:
	var total : float = 0.0
	var tree : SceneTree = player.get_tree()
	var weather : Weather = Weather.find(tree) if tree else null
	var wet : bool = weather != null and weather.state == Weather.State.RAIN
	var hour : float = DayNightCycle.now(tree) if tree else 12.0
	var night : bool = hour >= 20.0 or hour < 5.0
	match stat:
		&"biteSpeed":
			if wet and has(player, &"storm_fisher"):
				total += 15.0
			if night and has(player, &"lantern"):
				total += 10.0
		&"seaCreature":
			if night and has(player, &"lantern"):
				total += 1.0
		&"castEnergy":
			if wet and has(player, &"oilskin"):
				total -= 33.0
		&"stayUp":
			if has(player, &"night_owl"):
				total += 2.0
	return total

# Magical Power from every charm ever found: each family counts once, at the
# best one found.
static func magical_power(player : Player) -> int:
	if not player or not player.progress:
		return 0
	var frame : int = Engine.get_process_frames()
	if frame == cacheFrame:
		return cachedPower
	cacheFrame = frame
	var best : Dictionary = {}
	for thing in player.progress.collected:
		var charm : Charm = thing as Charm
		if charm and int(player.progress.collected[thing]) > 0:
			var key : String = charm.family_key()
			if not best.has(key) or (best[key] as Charm).tier < charm.tier:
				best[key] = charm
	var total : int = 0
	for key in best:
		var charm : Charm = best[key]
		total += POWER.get(charm.rarity.displayName if charm.rarity else "Common", 3)
	cachedPower = total
	return total

static func power_of(charm : Charm) -> int:
	return POWER.get(charm.rarity.displayName if charm.rarity else "Common", 3)
