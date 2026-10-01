extends Resource
class_name Progress

# What the player has done around the world that isn't fish or items: secrets
# found, fish given to the aquarium, what grows on the farm and what was
# bought where today, skills, collections, quests and more. SaveGame saves
# every script variable here.

# A quest was taken or handed in (the story director plays their scenes).
signal quest_taken(quest : Quest)
signal quest_handed_in(quest : Quest)

#------------------------#
# The player's name, picked when the story starts (or when joining a friend).
@export var playerName : String = ""
# Anything that only has to be remembered, by name.
@export var flags : Dictionary = {}
# Every aquarium tank's donated fish.
@export var donations : Dictionary = {}
# Every farm plot's tiles: per tile an empty array, or the seed and the day it went in.
@export var farms : Dictionary = {}
# Pets bought at the pet shop, the one out with the player, and how many fish
# each has seen caught (their level).
@export var pets : Array[PetData] = []
@export var activePet : PetData
@export var petCatches : Dictionary = {}
# Food buffs by stat: the multiplier, the clock hour it runs out and the icon.
@export var buffs : Dictionary = {}
# Every quest taken: a dictionary with its goal counts and whether it's done.
@export var quests : Dictionary = {}
# The quest shown on the HUD. Empty picks the first one going.
@export var tracked : Quest
# Story scenes that played for the other player while this one was elsewhere
# (multiplayer), to watch from the quest log.
@export var missedScenes : Array[String] = []
# When the player last woke, in clock hours since day 0 (see SleepSchedule).
@export var awakeSince : float = -1.0
# Seconds played, for the save slots.
@export var playtime : float = 0.0
# The story chapter reached (see Story).
@export var chapter : int = 0
# XP per skill (see Skills).
@export var skills : Dictionary = {}
# How many of each item, fish species or sea creature were ever obtained.
@export var collected : Dictionary = {}
# The highest collection tier already rewarded, per collected thing.
@export var collectionTiers : Dictionary = {}
# Sea creatures beaten, per kind.
@export var bestiary : Dictionary = {}
# Boat part tiers built (see BoatParts).
@export var boat : Dictionary = {}
# Crab pots set out, per trap spot.
@export var traps : Dictionary = {}
# Tournament entries and results, per week, and the league reached.
@export var tournaments : Dictionary = {}
@export var league : int = 0
# Tournament tickets, spent at the tournament hall.
@export var tickets : int = 0
# Running totals, like fish caught or treasure opened.
@export var counters : Dictionary = {}
# Rare drop luck meters: catches since each drop last came up (see RareDrops).
@export var pity : Dictionary = {}
# Event pickups already collected, by id, with the day they were taken.
@export var pickups : Dictionary = {}
# The recipe pinned to the HUD, its ingredients counted as they come in.
@export var pinnedRecipe : BaitRecipe
# What's worn, by slot (see Equipment).
@export var equipment : Dictionary = {}
# Daily harbor orders: the day they were made and which were delivered.
@export var orders : Dictionary = {}
# The crew at the crew board: per member its CrewMember, tier, the clock hour
# it was last counted and how much it holds (see Crew).
@export var crew : Array = []
# Friendship with each villager, by Cast id (see Friendship).
@export var friends : Dictionary = {}
# The harbor bank: coin account and vault tiers, and the vault's stacks (see
# Bank).
@export var bank : Dictionary = {}
@export var vault : Array = []
#------------------------#


func setup() -> void:
	flags = flags.duplicate(true)
	donations = donations.duplicate(true)
	farms = farms.duplicate(true)
	pets = pets.duplicate()
	petCatches = petCatches.duplicate()
	buffs = buffs.duplicate(true)
	quests = quests.duplicate(true)
	skills = skills.duplicate()
	collected = collected.duplicate()
	collectionTiers = collectionTiers.duplicate()
	bestiary = bestiary.duplicate()
	boat = boat.duplicate()
	traps = traps.duplicate(true)
	tournaments = tournaments.duplicate(true)
	counters = counters.duplicate()
	pity = pity.duplicate()
	pickups = pickups.duplicate()
	equipment = equipment.duplicate()
	orders = orders.duplicate(true)
	crew = crew.duplicate(true)
	friends = friends.duplicate(true)
	bank = bank.duplicate(true)
	vault = vault.duplicate()
	missedScenes = missedScenes.duplicate()

func chapter_title() -> String:
	return Story.chapter_title(chapter)

func count(key : String, amount : int = 1) -> void:
	counters[key] = counters.get(key, 0) + amount

func counter(key : String) -> int:
	return counters.get(key, 0)

# Hours since day 0 began, for buffs that last a while.
static func clock(tree : SceneTree) -> float:
	var cycle : DayNightCycle = DayNightCycle.find(tree)
	return cycle.day * 24.0 + cycle.time if cycle else 0.0

func add_buff(stat : StringName, amount : float, until : float, icon : Texture2D) -> void:
	buffs[stat] = [amount, until, icon]
	emit_changed()

func buff(stat : StringName, now : float) -> float:
	var entry : Array = buffs.get(stat, [])
	return entry[0] if not entry.is_empty() and entry[1] > now else 1.0

# The buffs still running: stat, multiplier, hours left and icon each.
func active_buffs(now : float) -> Array[Array]:
	var list : Array[Array] = []
	for stat in buffs:
		var entry : Array = buffs[stat]
		if entry[1] > now:
			list.append([stat, entry[0], entry[1] - now, entry[2]])
	return list

func quest_started(quest : Quest) -> bool:
	return quests.has(quest)

func quest_done(quest : Quest) -> bool:
	return quests.has(quest) and quests[quest].done

func quest_active(quest : Quest) -> bool:
	return quests.has(quest) and not quests[quest].done

func start_quest(quest : Quest) -> void:
	var counts : Array = []
	counts.resize(quest.goals.size())
	counts.fill(0)
	quests[quest] = {"counts": counts, "done": false}
	if not tracked or quest_done(tracked):
		tracked = quest
	emit_changed()
	quest_taken.emit(quest)

func quest_count(quest : Quest, goal : int) -> int:
	return quests[quest].counts[goal] if quests.has(quest) else 0

func add_quest_count(quest : Quest, goal : int, amount : int) -> void:
	quests[quest].counts[goal] += amount
	emit_changed()

func finish_quest(quest : Quest) -> void:
	quests[quest].done = true
	set_flag(quest.key())
	if tracked == quest:
		tracked = null
		for other in quests:
			if not quests[other].done:
				tracked = other
				break
	emit_changed()
	quest_handed_in.emit(quest)

func active_quests() -> Array[Quest]:
	var list : Array[Quest] = []
	for quest in quests:
		if not quests[quest].done:
			list.append(quest)
	return list

func has_flag(key : String) -> bool:
	return flags.has(key)

func get_flag(key : String, fallback : Variant = null) -> Variant:
	return flags.get(key, fallback)

func set_flag(key : String, value : Variant = true) -> void:
	flags[key] = value
	emit_changed()

func donated(tank : AquariumTank) -> Array:
	return donations.get(tank, [])

func has_donated(tank : AquariumTank, fish : FishData) -> bool:
	return donated(tank).has(fish)

# Returns whether this finished the tank.
func donate(tank : AquariumTank, fish : FishData) -> bool:
	var wasDone : bool = tank_done(tank)
	if not donations.has(tank):
		donations[tank] = []
	if not donations[tank].has(fish):
		donations[tank].append(fish)
	emit_changed()
	return not wasDone and tank_done(tank)

func tank_done(tank : AquariumTank) -> bool:
	return tank != null and donated(tank).size() >= tank.needed()

func plot(id : String, tiles : int) -> Array:
	if not farms.has(id):
		var list : Array = []
		for i in tiles:
			list.append([])
		farms[id] = list
	return farms[id]

func plant(id : String, tile : int, kind : Seed, day : int) -> void:
	farms[id][tile] = [kind, day]
	emit_changed()

func clear_tile(id : String, tile : int) -> void:
	farms[id][tile] = []
	emit_changed()

func set_active_pet(pet : PetData) -> void:
	activePet = pet
	emit_changed()

func pet_catches(pet : PetData) -> int:
	return petCatches.get(pet, 0)

func pet_level(pet : PetData) -> int:
	return pet.level_for(pet_catches(pet)) if pet else 0

# A fish was caught with the active pet out. Returns whether it leveled up.
func pet_caught() -> bool:
	if not activePet:
		return false
	var before : int = pet_level(activePet)
	petCatches[activePet] = pet_catches(activePet) + 1
	emit_changed()
	return pet_level(activePet) > before
