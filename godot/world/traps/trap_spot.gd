@tool
extends Interactable
class_name TrapSpot

# A good place for a crab pot, by a pier or on the rocks. Set a pot from the
# bag here and it fills up day by day with fish from its biome (and a chance
# of its extras, like crabs and shells) while the player is away. Checking it
# empties the catch into the bag; checking an empty pot picks it back up.

#------------------------#
@export var biome : Biome
@export var extras : Array[Item] = []
# Chance per catch that it's one of the extras instead of a fish.
@export_range(0.0, 1.0) var extraChance : float = 0.3
@export var buoyColor : Color = Color(0.95, 0.35, 0.3)

var player : Player
var time : float = 0.0
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	time = randf() * 5.0

func key() -> String:
	return "trap/" + String(get_path())

func state() -> Dictionary:
	return player.progress.traps.get(key(), {}) if player else {}

func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

func waiting() -> int:
	var entry : Dictionary = state()
	if entry.is_empty():
		return 0
	var pot : CrabPot = entry.pot
	return mini((today() - int(entry.day)) * pot.perDay, pot.capacity) if pot else 0

func best_pot(who : Player) -> CrabPot:
	var best : CrabPot = null
	for item in who.inventory.items:
		if item is CrabPot and (not best or (item as CrabPot).capacity > best.capacity):
			best = item.original() as CrabPot
	return best

func prompt_text(who : Player) -> String:
	if not blocked_reason(who).is_empty():
		return super(who)
	if state().is_empty():
		return "Set crab pot" if best_pot(who) else "Trap spot (needs a pot)"
	var inside : int = waiting()
	return "Check pot (%d)" % inside if inside > 0 else "Pick up pot"

func interact(who : Player) -> void:
	var entry : Dictionary = state()
	if entry.is_empty():
		var fresh : CrabPot = best_pot(who)
		if not fresh:
			notice("Trap spot", "Crab pots are made at the village workbench. Set one here and it fills up every day.", blockedColor)
			return
		who.inventory.take(fresh, 1)
		who.progress.traps[key()] = {"pot": fresh, "day": today()}
		who.progress.emit_changed()
		notice("Pot set!", "Come back in a day or two to check it.", promptColor, fresh.icon)
		return
	var count : int = waiting()
	if count <= 0:
		if who.inventory.room_for(entry.pot) < 1:
			notice("Bag full", "Make room to pick the pot up.", blockedColor)
			return
		who.inventory.give(entry.pot, 1)
		who.progress.traps.erase(key())
		who.progress.emit_changed()
		return
	var names : PackedStringArray = PackedStringArray()
	var pot : CrabPot = entry.pot
	for i in count:
		if not who.inventory.has_space():
			break
		if not extras.is_empty() and randf() < extraChance * pot.luck:
			var extra : Item = extras.pick_random()
			if who.inventory.give(extra, 1) == 0:
				names.append(extra.displayName)
		elif biome:
			var data : FishData = pick_fish(pot.luck)
			if data:
				var fish : Fish = Fish.caught(data)
				if who.inventory.add(fish) >= 0:
					who.journal.record(fish, biome)
					Collections.check(who, data)
					names.append(data.displayName)
	entry.day = today()
	who.progress.count("trap_catches", names.size())
	Skills.add(who, Skills.FISHING, names.size() * 4.0)
	who.progress.emit_changed()
	notice("Crab pot", ("Got " + ", ".join(names) + ".") if not names.is_empty() else "Your bag is full.", promptColor, pot.icon)

# Pots catch the easy fish: commons mostly, uncommons sometimes, rarely more.
func pick_fish(luck : float) -> FishData:
	var weights : Dictionary = {}
	for data in biome.fish:
		if data and data.rarity and data.requirements.is_empty() and data.chance < 0.0:
			var share : float = {"Common": 10.0, "Uncommon": 3.0, "Rare": 0.4 * luck, "Legendary": 0.03 * luck}.get(data.rarity.displayName, 0.0)
			if share > 0.0:
				weights[data] = share * data.spawnRate
	return FishData.pick(weights) if not weights.is_empty() else null

func _process(delta : float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		super()
		return
	var bob : float = sin(time * 2.0) * 0.6
	if state().is_empty():
		draw_arc(Vector2(0.0, 1.0), 2.5, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, 0.25 + 0.15 * sin(time * 3.0)), 0.3, true)
		return
	draw_line(Vector2(0.0, bob), Vector2(0.0, 4.0), Color(0.85, 0.8, 0.6, 0.8), 0.3, true)
	draw_circle(Vector2(0.0, bob), 1.6, buoyColor)
	draw_rect(Rect2(-1.6, bob - 0.3, 3.2, 0.6), Color(1.0, 1.0, 1.0, 0.9))
	if waiting() > 0 and fmod(time, 1.6) < 0.8:
		draw_circle(Vector2(0.0, bob - 4.0), 0.7, Color(1.0, 0.9, 0.4))
