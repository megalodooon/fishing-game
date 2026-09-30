extends RefCounted
class_name Contests

# The contests some happenings hold (GameEvent.contest). The fishing derby
# scores the heaviest catch of the day's featured fish against how big that
# fish grows; the farming contest counts the featured crop harvested while it
# runs. When it ends the score earns a medal (bronze, silver or gold) paid in
# Contest Ribbons, which the hosts' stalls take. Scores live in progress
# flags, "contest/<event>/<day>".

const RIBBON : String = "res://items/events/contest_ribbon.tres"
const MEDALS : PackedStringArray = ["", "Bronze", "Silver", "Gold"]
const MEDAL_COLORS : Array[Color] = [Color(0.6, 0.65, 0.72), Color(0.85, 0.55, 0.3), Color(0.82, 0.86, 0.92), Color(1.0, 0.82, 0.3)]
const RIBBONS : PackedInt32Array = [0, 1, 3, 6]
# Derby: share of the species' heaviest possible weight. Harvest: crops.
const DERBY_AT : PackedFloat32Array = [0.0, 0.45, 0.7, 0.88]
const HARVEST_AT : PackedInt32Array = [0, 6, 16, 32]
const DERBY_FISH : PackedStringArray = [
	"res://fishing/fish/species/sardine.tres",
	"res://fishing/fish/species/anchovy.tres",
	"res://fishing/fish/species/mackerel.tres",
	"res://fishing/fish/species/sea_bass.tres",
	"res://fishing/fish/species/red_snapper.tres",
	"res://fishing/fish/species/flounder.tres",
]
const HARVEST_CROPS : PackedStringArray = [
	"res://items/materials/wormroot.tres",
	"res://items/materials/sunflower.tres",
	"res://items/materials/sweetcorn.tres",
	"res://items/materials/sand_carrot.tres",
	"res://items/materials/sea_kale.tres",
	"res://items/materials/tea_leaves.tres",
]


static func key(event : GameEvent, day : int) -> String:
	return "contest/%s/%d" % [event.key(), day]

# What this day's contest is about: a FishData or a crop Item.
static func featured(event : GameEvent, day : int) -> Resource:
	var list : Array[String] = []
	for path in (DERBY_FISH if event.contest == &"derby" else HARVEST_CROPS):
		if ResourceLoader.exists(path):
			list.append(path)
	if list.is_empty():
		return null
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([event.key(), day])
	return load(list[random.randi_range(0, list.size() - 1)])

static func featured_name(event : GameEvent, day : int) -> String:
	var thing : Resource = featured(event, day)
	return Collections.name_of(thing) if thing else "?"

static func running(player : Player) -> Array[GameEvent]:
	var list : Array[GameEvent] = []
	for event in EventDirector.active(player.get_tree()):
		if not event.contest.is_empty():
			list.append(event)
	return list

static func today(player : Player) -> int:
	var cycle : DayNightCycle = DayNightCycle.find(player.get_tree())
	return cycle.day if cycle else 1

static func score(player : Player, event : GameEvent, day : int) -> float:
	return float(player.progress.get_flag(key(event, day), 0.0))

static func medal_for(event : GameEvent, value : float) -> int:
	var medal : int = 0
	for i in range(1, 4):
		var need : float = DERBY_AT[i] if event.contest == &"derby" else float(HARVEST_AT[i])
		if value >= need:
			medal = i
	return medal

# The score needed for the next medal, or -1 at gold.
static func next_goal(event : GameEvent, value : float) -> float:
	var medal : int = medal_for(event, value)
	if medal >= 3:
		return -1.0
	return DERBY_AT[medal + 1] if event.contest == &"derby" else float(HARVEST_AT[medal + 1])

static func score_text(event : GameEvent, value : float) -> String:
	if event.contest == &"derby":
		return "%d%% of the record" % roundi(value * 100.0)
	return "%d harvested" % roundi(value)

static func notify(player : Player, event_name : StringName, data : Variant, extra : Variant) -> void:
	if event_name != &"catch" and event_name != &"harvest":
		return
	for event in running(player):
		var day : int = today(player)
		var thing : Resource = featured(event, day)
		var before : float = score(player, event, day)
		var after : float = before
		if event.contest == &"derby" and event_name == &"catch" and data is Fish and (data as Fish).species == thing:
			var fish : Fish = data
			after = maxf(before, fish.weight / maxf(fish.species.weightRange.y, 0.01))
		elif event.contest == &"harvest" and event_name == &"harvest" and data is Item and (data as Item).original() == thing:
			after = before + float(extra)
		if after > before:
			player.progress.set_flag(key(event, day), after)
			var medal : int = medal_for(event, after)
			if medal > medal_for(event, before):
				var board : NoticeBoard = NoticeBoard.find(player.get_tree())
				if board:
					board.post("%s: %s medal pace!" % [event.displayName, MEDALS[medal]], score_text(event, after), MEDAL_COLORS[medal], event.icon)

# Pays out a contest that ended. Called by the EventDirector.
static func finish(player : Player, event : GameEvent, day : int) -> void:
	if event.contest.is_empty() or player.progress.has_flag(key(event, day) + "/paid"):
		return
	var value : float = score(player, event, day)
	if value <= 0.0:
		return
	player.progress.set_flag(key(event, day) + "/paid")
	var medal : int = medal_for(event, value)
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if medal <= 0:
		if board:
			board.post("%s is over" % event.displayName, "%s. No medal this time." % score_text(event, value), MEDAL_COLORS[0], event.icon)
		return
	var ribbon : Item = load(RIBBON) as Item
	if ribbon:
		Counter.deliver(player, ribbon, RIBBONS[medal])
	player.progress.count("medal_%s" % MEDALS[medal].to_lower())
	player.progress.count("contests_medalled")
	Achievements.notify(player, &"medal", medal, event)
	if board:
		board.post("%s medal!" % MEDALS[medal], "%s: %s. +%d Contest Ribbons" % [event.displayName, score_text(event, value), RIBBONS[medal]], MEDAL_COLORS[medal], event.icon)
