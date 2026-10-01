extends RefCounted
class_name Stats

# Every player stat and where it comes from: the pet, food buffs, the weather,
# skill perks, charms carried in the bag, boat parts and found pearls.
# Multiplier stats multiply (1 changes nothing), the others add up (0 changes
# nothing, most in percent points). Rod and tackle stats stay on the rod.

const MULTIPLY : Array[StringName] = [&"biteSpeed", &"castEnergy", &"walkSpeed", &"luck"]
# Name, and how a value shows: "x" multiplier, "%" percent points, "+" plain.
const INFO : Dictionary = {
	&"biteSpeed": ["Fishing speed", "x"],
	&"luck": ["Rare fish luck", "x"],
	&"castEnergy": ["Cast energy", "x"],
	&"walkSpeed": ["Walk speed", "x"],
	&"seaCreature": ["Sea creature chance", "%"],
	&"treasure": ["Treasure chance", "%"],
	&"doubleCatch": ["Double catch", "%"],
	&"weight": ["Heavier fish", "%"],
	&"variantLuck": ["Shiny luck", "%"],
	&"sellBonus": ["Fish sell price", "%"],
	&"xpBonus": ["Skill XP", "%"],
	&"control": ["Catch control", "%"],
	&"damage": ["Fight damage", "%"],
	&"hearts": ["Fight hearts", "+"],
	&"stayUp": ["Stay up later", "+"],
	&"harvestBonus": ["Extra harvest", "%"],
	&"foodPower": ["Food power", "%"],
	&"travelDiscount": ["Travel discount", "%"],
	&"energyMax": ["Max energy", "+"],
	&"rareFind": ["Rare find", "%"],
	&"forageBonus": ["Extra forage", "%"],
	&"craftBonus": ["Double craft", "%"],
	&"potionPower": ["Potion time", "%"],
	&"crewSpeed": ["Crew speed", "%"],
	&"trophyLuck": ["Trophy tier luck", "%"],
	&"digLuck": ["Dig luck", "%"],
}
# What every player starts with.
const BASE : Dictionary = {&"treasure": 1.5, &"hearts": 1.0, &"seaCreature": 5.0}


static func multiplies(stat : StringName) -> bool:
	return MULTIPLY.has(stat)

# Stats are asked for many times a frame, so each is worked out once a frame.
static var cacheFrame : int = -1
static var cachePlayer : Player
static var cache : Dictionary = {}

static func of(player : Player, stat : StringName) -> float:
	if not player:
		return 1.0 if multiplies(stat) else BASE.get(stat, 0.0)
	var frame : int = Engine.get_process_frames()
	if frame != cacheFrame or player != cachePlayer:
		cacheFrame = frame
		cachePlayer = player
		cache.clear()
	elif cache.has(stat):
		return cache[stat]
	var value : float = work_out(player, stat)
	cache[stat] = value
	return value

static func work_out(player : Player, stat : StringName) -> float:
	var tree : SceneTree = player.get_tree()
	if multiplies(stat):
		var value : float = player.pet_stat(stat)
		var weather : Weather = Weather.find(tree)
		if weather:
			value *= weather.stat(stat)
		if player.progress:
			value *= player.progress.buff(stat, Progress.clock(tree))
		value *= 1.0 + Skills.bonus(player, stat)
		value *= 1.0 + extras(player, stat) * 0.01
		return value
	var total : float = BASE.get(stat, 0.0) + Skills.bonus(player, stat) + extras(player, stat)
	var pet : PetData = player.progress.activePet if player.progress else null
	if pet:
		total += pet.bonus(stat, player.progress.pet_level(pet))
	if player.progress:
		total += (player.progress.buff(stat, Progress.clock(tree)) - 1.0) * 100.0
	return total

# What's worn (and Magical Power, see Equipment), the rod in hand, the
# Angler Level, the council's perk, events running now, boat parts, pearls
# and village projects.
static func extras(player : Player, stat : StringName) -> float:
	var total : float = 0.0
	total += Equipment.bonus(player, stat)
	var rod : RodItem = player.held_data() as RodItem
	if rod:
		total += rod.fight_bonus(stat)
	total += AnglerLevel.bonus(player, stat)
	total += Council.bonus(player, stat)
	total += Calendar.bonus(player.get_tree(), stat)
	total += TideTree.bonus(player, stat)
	total += Enchanting.bonus(player, stat)
	if stat == &"damage" and player.progress:
		total += Hunts.damage_bonus(player.progress)
	if player.progress:
		total += BoatParts.bonus(player.progress, stat)
		total += Pearls.bonus(player.progress, stat)
		total += Project.bonus(player.progress, stat)
	return total

static func name_of(stat : StringName) -> String:
	return INFO.get(stat, [String(stat)])[0]

static func value_text(stat : StringName, value : float) -> String:
	match INFO.get(stat, ["", "+"])[1]:
		"x":
			return "x%.2f" % value
		"%":
			return "%+.1f%%" % value if absf(value - roundf(value)) > 0.01 else "%+d%%" % roundi(value)
	return "%+d" % roundi(value)

# A bonus in extra-source units (percent, even for multiplier stats), like "+2%".
static func bonus_text(stat : StringName, amount : float) -> String:
	if INFO.get(stat, ["", "%"])[1] == "+":
		return "%+d" % roundi(amount)
	return ("%+.1f%%" % amount) if absf(amount - roundf(amount)) > 0.01 else ("%+d%%" % roundi(amount))

# A bonus as a line, like "+2% Extra harvest". Multiplier stats get their
# share as percent.
static func perk_line(stat : StringName, amount : float) -> String:
	if INFO.get(stat, ["", "%"])[1] == "+":
		return "%+d %s" % [roundi(amount), name_of(stat)]
	var shown : float = amount * 100.0 if multiplies(stat) else amount
	var number : String = ("%+.1f" % shown) if absf(shown - roundf(shown)) > 0.01 else ("%+d" % roundi(shown))
	return "%s%% %s" % [number, name_of(stat)]

# Every stat that differs from nothing, for the profile screen.
static func summary(player : Player) -> Array:
	var rows : Array = []
	for stat in INFO:
		var value : float = of(player, stat)
		if (multiplies(stat) and not is_equal_approx(value, 1.0)) or (not multiplies(stat) and not is_zero_approx(value)):
			rows.append([name_of(stat), value_text(stat, value)])
	return rows
