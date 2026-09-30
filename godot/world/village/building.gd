@tool
extends Node2D
class_name Building

# A building (or a stall, or a machine) on an island. It can stay locked until
# an aquarium tank is restored, and only open on some weekdays or hours. The
# market isn't even there on other days. Interactables inside it follow all
# of this and say why when they can't be used.

#------------------------#
@export var displayName : String = ""
@export var unlockedBy : AquariumTank
# Also locked until this progress flag is set, like a restoration project.
@export var unlockFlag : String = ""
@export var unlockHint : String = "Restore it at the village restoration board."
# Open every day when empty.
@export var openDays : Array[DayNightCycle.Weekday] = []
# From x to y, wrapping past midnight. The same hour twice means all day.
@export var openHours : Vector2 = Vector2(0.0, 24.0)
# Gone on the days it's closed, collisions and all.
@export var hideWhenClosed : bool = false
# Only there once this progress flag is set, like after a quest.
@export var requiredFlag : String = ""
# Only there on some days, like a merchant sailing from island to island.
@export_range(0.0, 1.0, 0.05) var visitChance : float = 1.0
# Shown while locked, like boards over the door.
@export var lockedArt : CanvasItem
@export var lockedTint : Color = Color(0.6, 0.6, 0.68)

var player : Player
var cycle : DayNightCycle
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	cycle = DayNightCycle.find(get_tree())
	if cycle:
		cycle.day_changed.connect(update.unbind(1))
	if player and player.progress:
		player.progress.changed.connect(update)
	update()

func is_unlocked(_player : Player = null) -> bool:
	if not unlockFlag.is_empty() and not (player != null and player.progress != null and player.progress.has_flag(unlockFlag)):
		return false
	return unlockedBy == null or (player != null and player.progress != null and player.progress.tank_done(unlockedBy))

func open_today() -> bool:
	return openDays.is_empty() or cycle == null or openDays.has(cycle.weekday())

# Whether it's on the island at all today.
func present() -> bool:
	if not requiredFlag.is_empty() and not (player and player.progress and player.progress.has_flag(requiredFlag)):
		return false
	if visitChance >= 1.0 or cycle == null:
		return true
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash([cycle.day, displayName, String(get_path())])
	return random.randf() < visitChance

func open_now() -> bool:
	if not open_today():
		return false
	if cycle == null or is_equal_approx(fposmod(openHours.x, 24.0), fposmod(openHours.y, 24.0)):
		return true
	var from : float = fposmod(openHours.x, 24.0)
	var to : float = fposmod(openHours.y, 24.0)
	return (cycle.time >= from and cycle.time < to) if from < to else (cycle.time >= from or cycle.time < to)

func blocked_reason(who : Player) -> String:
	if not is_unlocked(who):
		return "Restore the aquarium's %s to open it." % unlockedBy.displayName if unlockedBy and not player.progress.tank_done(unlockedBy) else unlockHint
	if not open_today():
		var days : Array[int] = []
		days.assign(openDays)
		return "Only open on %s." % DayNightCycle.weekday_text(days)
	if not open_now():
		return "Open from %s to %s." % [hour_text(openHours.x), hour_text(openHours.y)]
	return ""

func blocked_label(who : Player) -> String:
	return "Locked" if not is_unlocked(who) else "Closed"

static func hour_text(hour : float) -> String:
	return "%d:%02d" % [floori(fposmod(hour, 24.0)), roundi(fmod(hour, 1.0) * 60.0)]

func update() -> void:
	var here : bool = present() and (not hideWhenClosed or open_today())
	visible = here
	for shape in find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", not here)
	for shape in find_children("*", "CollisionPolygon2D", true, false):
		shape.set_deferred("disabled", not here)
	var locked : bool = not is_unlocked()
	modulate = lockedTint if locked else Color.WHITE
	if lockedArt:
		lockedArt.visible = locked
