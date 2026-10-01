extends RefCounted
class_name Crew

# The crew's work, worked out from the clock whenever someone looks: each
# member made one item per interval since they were last counted, up to what
# they can hold. Slots: two to start, one more for every three new crew tiers
# reached, and more from the Angler Level, up to MAX_SLOTS so the crew never
# earns more than fishing does.

const BASE_SLOTS : int = 2
const UNIQUE_PER_SLOT : int = 3
const MAX_SLOTS : int = 10


static func slots(player : Player) -> int:
	return mini(BASE_SLOTS + floori(unique_tiers(player) / float(UNIQUE_PER_SLOT)) + AnglerLevel.crew_bonus(player), MAX_SLOTS)

static func unique_tiers(player : Player) -> int:
	var count : int = 0
	for flag in player.progress.flags:
		if String(flag).begins_with("crew_tier/"):
			count += 1
	return count

static func mark_tier(player : Player, member : CrewMember, tier : int) -> void:
	var flag : String = "crew_tier/%s/%d" % [member.key(), tier]
	if not player.progress.has_flag(flag):
		player.progress.set_flag(flag)
		AnglerLevel.forget()

static func speed(player : Player) -> float:
	return player.stat(&"crewSpeed")

# Counts up what everyone made until now.
static func work(player : Player) -> void:
	var now : float = Progress.clock(player.get_tree())
	var rate : float = speed(player)
	for entry in player.progress.crew:
		var member : CrewMember = entry.crew
		if not member:
			continue
		var interval : float = member.interval(entry.tier, rate)
		var made : int = floori((now - entry.since) / interval)
		var room : int = member.storage(entry.tier) - entry.stored
		if made <= 0:
			continue
		if made >= room:
			entry.stored += room
			entry.since = now
		else:
			entry.stored += made
			entry.since += made * interval

static func hire(player : Player, member : CrewMember) -> bool:
	if player.progress.crew.size() >= slots(player):
		return false
	player.progress.crew.append({"crew": member, "tier": 1, "since": Progress.clock(player.get_tree()), "stored": 0})
	player.progress.count("crew_hired")
	mark_tier(player, member, 1)
	player.progress.emit_changed()
	return true

# Moves a member's stored items into the bag, as much as fits. Returns how many.
static func collect(player : Player, index : int) -> int:
	var entry : Dictionary = player.progress.crew[index]
	var member : CrewMember = entry.crew
	var fits : int = mini(entry.stored, player.inventory.room_for(member.product))
	if fits <= 0:
		return 0
	player.inventory.give(member.product, fits)
	entry.stored -= fits
	Skills.add(player, Skills.FORAGING, fits * 0.5)
	player.progress.emit_changed()
	return fits

static func hours_text(hours : float) -> String:
	var minutes : int = roundi(hours * 60.0)
	if minutes < 60:
		return "%dm" % minutes
	@warning_ignore("integer_division")
	return "%dh%02d" % [minutes / 60, minutes % 60] if minutes % 60 != 0 else "%dh" % (minutes / 60)
