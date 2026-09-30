extends Node
class_name Tournament

# The weekly fishing tournament. Each week (Monday to Saturday 18:00) names one
# kind of fish from the places the player has opened. After entering at the
# tournament desk, the heaviest one caught counts. The other contestants'
# catches come in on set days through the week, and after the deadline the
# desk hands out prizes and tickets. Winning a league moves the player up to
# the next one, where the fish are rarer, the rivals better and prizes bigger.

const GROUP : StringName = &"tournaments"
const LEAGUES : PackedStringArray = ["Village Cup", "Silver League", "Gold League", "Platinum League", "World Championship"]
const FEES : PackedInt32Array = [40, 200, 800, 2500, 8000]
const PRIZE_COINS : PackedInt32Array = [500, 250, 120]
const PRIZE_TICKETS : PackedInt32Array = [3, 2, 1]
const LEAGUE_SCALE : PackedFloat32Array = [1.0, 3.0, 8.0, 20.0, 50.0]
# Per league: which rarities can be the target.
const RARITIES : Array = [["Common", "Uncommon"], ["Uncommon", "Rare"], ["Uncommon", "Rare"], ["Rare", "Legendary"], ["Rare", "Legendary"]]
# Name, Cast id and skill (0-1, how close to the heaviest they get) per league.
const RIVALS : Array = [
	[["Rex Marlow", "rex", 0.62], ["Gus", "gus", 0.3], ["Tilly", "tilly", 0.25], ["Bo", "bo", 0.2], ["Mara", "mara", 0.35]],
	[["Rex Marlow", "rex", 0.72], ["Captain Grim", "grim", 0.5], ["Luma", "luma", 0.45], ["Mara", "mara", 0.4], ["Deepnet Angler", "vera", 0.55]],
	[["Rex Marlow", "rex", 0.8], ["Yuki", "yuki", 0.62], ["Captain Grim", "grim", 0.58], ["Deepnet Angler", "vera", 0.66], ["Luma", "luma", 0.5]],
	[["Rex Marlow", "rex", 0.86], ["Yuki", "yuki", 0.7], ["Deepnet Pro", "vera", 0.78], ["Auntie Moss", "moss", 0.6], ["Captain Grim", "grim", 0.64]],
	[["Rex Marlow", "rex", 0.92], ["Old Silas", "silas", 0.85], ["Deepnet Champion", "vera", 0.88], ["Yuki", "yuki", 0.78], ["Opal", "opal", 0.7]],
]
const DEADLINE_HOUR : float = 18.0
const SATURDAY : int = 5

#------------------------#
@export var player : Player
@export var cycle : DayNightCycle
@export var notices : NoticeBoard
# Tournaments start once this flag is set (the tournament hall reopens).
@export var openFlag : String = "project/tournament_hall"
@export var color : Color = Color(1.0, 0.8, 0.35)
#------------------------#


func _ready() -> void:
	add_to_group(GROUP)
	player.fish_caught.connect(on_caught)
	if cycle:
		cycle.day_changed.connect(on_day.unbind(1))

static func find(tree : SceneTree) -> Tournament:
	return tree.get_first_node_in_group(GROUP) as Tournament

func open() -> bool:
	return openFlag.is_empty() or player.progress.has_flag(openFlag)

func week() -> int:
	@warning_ignore("integer_division")
	return (cycle.day - 1) / 7 if cycle else 0

func league() -> int:
	return clampi(player.progress.league, 0, LEAGUES.size() - 1)

func past_deadline() -> bool:
	var weekday : int = cycle.weekday()
	return weekday > SATURDAY or (weekday == SATURDAY and cycle.time >= DEADLINE_HOUR)

# This week's entry, made on first look: the target fish, the league, whether
# the player entered, their best weight and, once over, their place.
func state() -> Dictionary:
	var key : int = week()
	if not player.progress.tournaments.has(key):
		player.progress.tournaments[key] = {"week": key, "species": pick_species(key), "league": league(), "entered": false, "best": 0.0, "done": false, "rank": 0}
	return player.progress.tournaments[key]

func pick_species(key : int) -> FishData:
	var allowed : Array = RARITIES[league()]
	var pool : Array[FishData] = []
	for location in player.atlas.unlocked:
		if location and location.biome:
			for data in location.biome.fish:
				if data and data.rarity and allowed.has(data.rarity.displayName) and data.requirements.is_empty() and data.chance < 0.0 and not pool.has(data):
					pool.append(data)
	if pool.is_empty():
		return null
	pool.sort_custom(func(a : FishData, b : FishData) -> bool: return a.resource_path < b.resource_path)
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([key, "tournament"])
	return pool[random.randi_range(0, pool.size() - 1)]

# The rivals' catches this week: name, Cast id, weight, and the weekday it comes in.
func rivals(entry : Dictionary) -> Array:
	var species : FishData = entry.species
	var list : Array = []
	if not species:
		return list
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([entry.get("week", 0), "rivals", species.resource_path])
	for rival in RIVALS[entry.league]:
		var roll : float = pow(random.randf(), 1.0 / (0.6 + rival[2] * 2.2))
		var pounds : float = lerpf(species.weightRange.x, species.weightRange.y, lerpf(roll, 1.0, rival[2] * 0.35))
		list.append([rival[0], rival[1], pounds, random.randi_range(0, SATURDAY)])
	return list

# Everyone's weight known so far, heaviest first. The player shows as "You".
func standings(entry : Dictionary, everything : bool) -> Array:
	var list : Array = []
	for rival in rivals(entry):
		if everything or cycle.weekday() >= rival[3]:
			list.append([rival[0], rival[2], false])
	if entry.entered:
		list.append(["You", entry.best, true])
	list.sort_custom(func(a : Array, b : Array) -> bool: return a[1] > b[1])
	return list

func fee() -> int:
	return FEES[league()]

func enter() -> bool:
	var entry : Dictionary = state()
	if entry.entered or past_deadline() or not entry.species or not player.wallet.spend(fee()):
		return false
	entry.entered = true
	player.progress.set_flag("tournament/entered")
	player.progress.emit_changed()
	return true

func on_caught(fish : Fish, _biome : Biome) -> void:
	if not open():
		return
	var entry : Dictionary = state()
	if entry.entered and not entry.done and not past_deadline() and fish.species == entry.species and fish.weight > entry.best:
		entry.best = fish.weight
		var place : int = rank(entry)
		notices.post("Tournament", "New best %s: %s. You're %s so far." % [fish.species.displayName, fish.weight_text(), ordinal(place)], color, fish.icon)

func rank(entry : Dictionary) -> int:
	var list : Array = standings(entry, false)
	for i in list.size():
		if list[i][2]:
			return i + 1
	return list.size() + 1

static func ordinal(place : int) -> String:
	match place:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
	return "%dth" % place

# Earlier weeks the player entered but never came back for are settled on
# the next morning, by notice.
func on_day() -> void:
	for key in player.progress.tournaments:
		var entry : Dictionary = player.progress.tournaments[key]
		if key < week() and not entry.done:
			var text : String = settle(entry)
			if entry.entered and notices:
				notices.post("Tournament results", text, color)

# Hands out a week's prizes once it's over. Returns a line to show.
func settle(entry : Dictionary) -> String:
	if entry.done or (entry.get("week", 0) == week() and not past_deadline()):
		return ""
	entry.done = true
	if not entry.entered or entry.best <= 0.0:
		player.progress.emit_changed()
		return "You didn't enter a fish this week."
	var list : Array = standings(entry, true)
	var place : int = 1
	for i in list.size():
		if list[i][2]:
			place = i + 1
	entry.rank = place
	player.progress.count("tournaments")
	var text : String = "You placed %s of %d." % [ordinal(place), list.size()]
	if place <= 3:
		var coins : int = roundi(PRIZE_COINS[place - 1] * LEAGUE_SCALE[entry.league])
		player.wallet.add(coins)
		player.progress.tickets += PRIZE_TICKETS[place - 1]
		player.progress.count("podiums")
		text += " Prize: $%d and %d ticket%s." % [coins, PRIZE_TICKETS[place - 1], "" if PRIZE_TICKETS[place - 1] == 1 else "s"]
	if place == 1:
		player.progress.count("tournament_wins")
		player.progress.set_flag("league_won/%d" % entry.league)
		if entry.league == player.progress.league and player.progress.league < LEAGUES.size() - 1:
			player.progress.league += 1
			player.progress.set_flag("league/%d" % player.progress.league)
			text += " Promoted to the %s!" % LEAGUES[player.progress.league]
	player.progress.emit_changed()
	return text
