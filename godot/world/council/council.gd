extends RefCounted
class_name Council

# The Harbor Council, like Skyblock's mayors: every week one villager holds
# the harbor's seat and their perk helps everyone all week. Three stand for
# next week; the one the player voted for at the ballot box wins, otherwise
# the village picks. Perks are stats (see Stats.extras).

# Cast id, perk name, the perk's stats (in Stats units).
const CANDIDATES : Array = [
	["gus", "Market Boom", {&"sellBonus": 10.0}],
	["nora", "Curator", {&"xpBonus": 10.0}],
	["marina", "Shipwright", {&"travelDiscount": 12.0}],
	["tilly", "Harvest Fair", {&"harvestBonus": 25.0}],
	["grim", "Buried Treasure", {&"treasure": 2.0, &"digLuck": 40.0}],
	["luma", "Starlight", {&"rareFind": 15.0}],
	["opal", "Pearl Luck", {&"luck": 8.0}],
	["brann", "Forgefire", {&"craftBonus": 8.0}],
	["moss", "Brew Night", {&"potionPower": 30.0}],
	["hale", "Tournament Fever", {&"weight": 10.0}],
	["bo", "Pet Parade", {&"walkSpeed": 10.0}],
	["silas", "Old Ways", {&"seaCreature": 2.0}],
	["odette", "Trophy Season", {&"trophyLuck": 25.0}],
	["pip", "Harbor Lights", {&"doubleCatch": 3.0}],
	["mara", "Inn's Welcome", {&"foodPower": 25.0}],
	["rex", "Rivalry", {&"biteSpeed": 8.0}],
]
const PER_BALLOT : int = 3


static func week(day : int) -> int:
	@warning_ignore("integer_division")
	return (day - 1) / 7

static func today(tree : SceneTree) -> int:
	var cycle : DayNightCycle = DayNightCycle.find(tree) if tree else null
	return cycle.day if cycle else 1

# The three standing in a week's election (held the week before).
static func ballot(which : int) -> Array:
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(["council", which])
	var pool : Array = CANDIDATES.duplicate()
	var picks : Array = []
	for i in PER_BALLOT:
		picks.append(pool.pop_at(random.randi_range(0, pool.size() - 1)))
	return picks

# Who holds the seat in a week: the player's vote from the week before, or the
# village's pick.
static func mayor(progress : Progress, which : int) -> Array:
	var standing : Array = ballot(which)
	var voted : String = progress.get_flag("vote/%d" % which, "") if progress else ""
	for candidate in standing:
		if candidate[0] == voted:
			return candidate
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(["mayor", which])
	return standing[random.randi_range(0, standing.size() - 1)]

static func current(tree : SceneTree, progress : Progress) -> Array:
	return mayor(progress, week(today(tree)))

static func vote(progress : Progress, which : int, id : String) -> void:
	progress.set_flag("vote/%d" % which, id)

static func perk_text(candidate : Array) -> String:
	var parts : PackedStringArray = PackedStringArray()
	for stat in candidate[2]:
		parts.append(Stats.perk_line(stat, candidate[2][stat] * (0.01 if Stats.multiplies(stat) else 1.0)))
	return ", ".join(parts)

# The seat's perk, worked out once a day (stats ask for it every tick). A vote
# only changes next week, so this week's seat never changes mid-week.
static var cachedDay : int = -1
static var cachedPerk : Dictionary = {}

static func bonus(player : Player, stat : StringName) -> float:
	if not player or not player.progress or not player.is_inside_tree():
		return 0.0
	var day : int = today(player.get_tree())
	if day != cachedDay:
		cachedDay = day
		cachedPerk = current(player.get_tree(), player.progress)[2]
	return cachedPerk.get(stat, 0.0)
