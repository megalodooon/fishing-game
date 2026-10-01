extends RefCounted
class_name BoatParts

# Boat upgrades built at the Boatyard, each part in tiers. A tier costs coins
# and materials and adds its stats on top of the ones before it. Some parts do
# more than stats: the cargo hold adds backpack slots, the cabin lets the
# player sleep aboard, the sonar brings more fishing spots and the hull opens
# the far seas (Location.requiredHull).

const HULL : StringName = &"hull"
const SAILS : StringName = &"sails"
const CARGO : StringName = &"cargo"
const SONAR : StringName = &"sonar"
const LANTERN : StringName = &"lantern"
const WINCH : StringName = &"winch"
const CABIN : StringName = &"cabin"
const ORDER : Array[StringName] = [HULL, SAILS, CARGO, SONAR, LANTERN, WINCH, CABIN]

# Per part: name, what it does, and its tiers: [coins, {item path: amount}, {stat: amount}, tier name].
const PARTS : Dictionary = {
	HULL: ["Hull", "Tougher hulls cost less energy to sail and reach the far seas.", [
		[600, {"res://items/materials/driftwood_plank.tres": 10}, {&"travelDiscount": 6.0}, "Patched Hull"],
		[2500, {"res://items/materials/driftwood_plank.tres": 25, "res://items/materials/iron_scrap.tres": 10}, {&"travelDiscount": 6.0}, "Oak Hull"],
		[9000, {"res://items/materials/iron_scrap.tres": 30, "res://items/materials/coral_shard.tres": 15}, {&"travelDiscount": 6.0}, "Iron Hull"],
		[28000, {"res://items/materials/obsidian_shard.tres": 20, "res://items/materials/frost_crystal.tres": 15}, {&"travelDiscount": 7.0}, "Obsidian Hull"],
		[80000, {"res://items/materials/abyssal_scale.tres": 10, "res://items/materials/storm_essence.tres": 10}, {&"travelDiscount": 10.0}, "Leviathan Hull"],
	]],
	SAILS: ["Sails", "Faster sails make every trip take less time.", [
		[400, {"res://items/materials/kelp_fiber.tres": 15}, {&"travelDiscount": 4.0}, "Canvas Sails"],
		[3000, {"res://items/materials/kelp_fiber.tres": 40, "res://items/materials/coral_shard.tres": 5}, {&"travelDiscount": 4.0}, "Reef Sails"],
		[15000, {"res://items/materials/storm_essence.tres": 5, "res://items/materials/kelp_fiber.tres": 60}, {&"travelDiscount": 5.0}, "Storm Sails"],
	]],
	CARGO: ["Cargo Hold", "More room for the catch: five backpack slots per tier.", [
		[1200, {"res://items/materials/driftwood_plank.tres": 15}, {}, "Crates"],
		[6000, {"res://items/materials/iron_scrap.tres": 20}, {}, "Cargo Hold"],
		[24000, {"res://items/materials/frost_crystal.tres": 10, "res://items/materials/iron_scrap.tres": 30}, {}, "Deep Hold"],
	]],
	SONAR: ["Sonar", "Pings the water for fish: spots show up more often and last longer. The Sonar Array shows the shadow of the fish in each spot; Deep Sonar shows the fish itself.", [
		[1500, {"res://items/materials/iron_scrap.tres": 8, "res://items/materials/glowcap.tres": 5}, {&"luck": 3.0}, "Fish Finder"],
		[8000, {"res://items/materials/iron_scrap.tres": 25, "res://items/materials/ink_sac.tres": 10}, {&"luck": 4.0}, "Sonar Array"],
		[30000, {"res://items/materials/abyssal_scale.tres": 5, "res://items/materials/storm_essence.tres": 5}, {&"luck": 6.0}, "Deep Sonar"],
	]],
	LANTERN: ["Bow Lantern", "Lights the water at night. Sea creatures come to look.", [
		[900, {"res://items/materials/glowcap.tres": 10}, {&"seaCreature": 1.0}, "Oil Lantern"],
		[7000, {"res://items/materials/ink_sac.tres": 10, "res://items/materials/glow_worm.tres": 15}, {&"seaCreature": 1.5}, "Glow Lantern"],
		[26000, {"res://items/materials/abyssal_scale.tres": 6}, {&"seaCreature": 2.5}, "Anglerlight"],
	]],
	WINCH: ["Treasure Winch", "Hauls up sunken things. More treasure from the deep.", [
		[2000, {"res://items/materials/iron_scrap.tres": 12}, {&"treasure": 1.0}, "Hand Winch"],
		[11000, {"res://items/materials/iron_scrap.tres": 30, "res://items/materials/coral_shard.tres": 10}, {&"treasure": 1.5}, "Steam Winch"],
		[40000, {"res://items/materials/obsidian_shard.tres": 15, "res://items/materials/abyssal_scale.tres": 8}, {&"treasure": 2.5}, "Kraken Winch"],
	]],
	CABIN: ["Cabin", "A bunk on board: sleep anywhere at sea. The second tier rests better.", [
		[15000, {"res://items/materials/driftwood_plank.tres": 40, "res://items/materials/kelp_fiber.tres": 30}, {&"energyMax": 10.0}, "Bunk"],
		[45000, {"res://items/materials/frost_crystal.tres": 20, "res://items/materials/storm_essence.tres": 8}, {&"energyMax": 15.0}, "Captain's Cabin"],
	]],
}
const CARGO_SLOTS : int = 5


static func tier(progress : Progress, part : StringName) -> int:
	return progress.boat.get(part, 0) if progress else 0

static func tiers(part : StringName) -> Array:
	return PARTS[part][2]

static func maxed(progress : Progress, part : StringName) -> bool:
	return tier(progress, part) >= tiers(part).size()

static func bonus(progress : Progress, stat : StringName) -> float:
	var total : float = 0.0
	for part in PARTS:
		var list : Array = tiers(part)
		for i in mini(tier(progress, part), list.size()):
			total += list[i][2].get(stat, 0.0)
	return total

# The part's picture in the Boatyard: res://boat/icons/<part>.png.
static func icon(part : StringName) -> Texture2D:
	var path : String = "res://boat/icons/%s.png" % part
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func tier_name(part : StringName, level : int) -> String:
	return tiers(part)[level - 1][3] if level >= 1 and level <= tiers(part).size() else "None"

# Puts built parts into effect: the cargo hold's backpack slots and the
# cabin's extra energy. Called after building and after loading.
static func apply(player : Player) -> void:
	var slots : int = 15 + CARGO_SLOTS * tier(player.progress, CARGO) + player.progress.counter("bag_slots")
	if player.inventory.backpackSize != slots:
		player.inventory.resize_backpack(slots)
	# The bunk on deck (and its bed frame's collision) only once it's built.
	var built : bool = tier(player.progress, CABIN) >= 1
	for bunk in player.get_tree().get_nodes_in_group(Bed.CABIN_GROUP):
		(bunk as Node2D).visible = built
		bunk.process_mode = Node.PROCESS_MODE_INHERIT if built else Node.PROCESS_MODE_DISABLED
	player.refresh_energy_max()
