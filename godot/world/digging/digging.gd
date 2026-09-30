extends RefCounted
class_name Digging

# Buried treasure hunts (like SkyBlock's Mythological Ritual). Opening a dig
# map on an island buries a trail of treasure there: a few spots, one after
# the other, with an arrow on the HUD pointing to the next. Digging each one
# with a spade in the bag turns up coins, materials and sometimes something
# rare; the last spot holds the map's big chest. Better spades make longer
# trails, better maps richer loot, and the Dig luck stat helps the rare
# finds. Saved as the progress flag "dig/trail".

const COLOR : Color = Color(0.95, 0.75, 0.35)
const MIN_GAP : float = 36.0
# Per map tier: loot rolls per spot, coins per spot, the rare chance, and the
# big chest at the end.
const MAPS : Array = [
	[1, Vector2i(40, 120), 0.04, "res://items/treasure/iron_chest.tres"],
	[2, Vector2i(150, 400), 0.07, "res://items/treasure/golden_chest.tres"],
	[3, Vector2i(500, 1400), 0.11, "res://items/treasure/ancient_coffer.tres"],
]
# What a spot can hold: [item path, weight, amount].
const LOOT : Array = [
	["res://items/materials/sea_shell.tres", 3.0, Vector2i(2, 5)],
	["res://items/materials/iron_scrap.tres", 3.0, Vector2i(2, 4)],
	["res://items/materials/old_boot.tres", 1.0, Vector2i(1, 1)],
	["res://items/materials/clay.tres", 2.0, Vector2i(2, 5)],
	["res://items/materials/coral_shard.tres", 2.0, Vector2i(1, 3)],
	["res://items/enchanting/sea_essence.tres", 2.0, Vector2i(1, 3)],
	["res://items/rare/pirate_doubloon.tres", 1.0, Vector2i(1, 2)],
	["res://items/rare/old_map_fragment.tres", 1.0, Vector2i(1, 1)],
]
const RARE : Array = [
	["res://items/rare/sea_glass.tres", 4.0],
	["res://items/rare/lucky_stone.tres", 1.0],
	["res://items/charms/treasure_1.tres", 1.5],
	["res://items/digging/sunken_crown.tres", 0.3],
]


static func trail(progress : Progress) -> Dictionary:
	return progress.get_flag("dig/trail", {})

static func active_here(player : Player) -> bool:
	var state : Dictionary = trail(player.progress)
	var island : Island = Island.current(player.get_tree())
	return not state.is_empty() and island != null and state.island == island.scene_file_path

# The spot to dig next, in global coordinates, or INF.
static func target(player : Player) -> Vector2:
	if not active_here(player):
		return Vector2.INF
	var state : Dictionary = trail(player.progress)
	return state.points[int(state.index)]

static func best_spade(player : Player) -> Spade:
	var found : Spade = null
	for item in player.inventory.items:
		var spade : Spade = item as Spade
		if spade and (not found or spade.tier > found.tier):
			found = spade
	return found

# Buries a trail on the island the player is on. Returns why it couldn't.
static func begin(player : Player, map : DigMap) -> String:
	var island : Island = Island.current(player.get_tree())
	if not island:
		return "Open it on an island"
	var spade : Spade = best_spade(player)
	if not spade:
		return "You'll need a spade to dig"
	if not trail(player.progress).is_empty():
		return "Finish the treasure trail you're on first"
	var grid : WalkGrid = island.walk_grid()
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	var points : Array = []
	var last : Vector2 = player.global_position
	var count : int = spade.trail + map.extraSpots
	for tries in 400:
		if points.size() >= count:
			break
		var cell : Vector2i = Vector2i(random.randi_range(2, grid.cells.x - 3), random.randi_range(3, grid.cells.y - 3))
		if not grid.open(cell) or not grid.open(cell + Vector2i(0, 1)) or not grid.open(cell + Vector2i(1, 0)):
			continue
		var point : Vector2 = grid.origin + (Vector2(cell) + Vector2(0.5, 0.5)) * WalkGrid.CELL
		if point.distance_to(last) < MIN_GAP or not island.room_at(point):
			continue
		var edge : Rect2 = island.room_at(point).rect().grow(-10.0)
		if not edge.has_point(point):
			continue
		points.append(point)
		last = point
	if points.size() < 2:
		return "Nowhere to dig here"
	player.progress.set_flag("dig/trail", {"island": island.scene_file_path, "points": points, "index": 0, "tier": map.tier})
	return ""

# Digs the spot the player is standing on. Returns what came up, as text.
static func dig(player : Player) -> String:
	var state : Dictionary = trail(player.progress)
	var tier : int = clampi(int(state.tier), 1, MAPS.size())
	var spec : Array = MAPS[tier - 1]
	var found : PackedStringArray = PackedStringArray()
	var coins : int = randi_range(spec[1].x, spec[1].y)
	player.wallet.add(coins)
	found.append("$%d" % coins)
	for i in int(spec[0]):
		var entry : Array = pick(LOOT)
		var item : Item = load(entry[0]) as Item
		var amount : int = randi_range(entry[2].x, entry[2].y)
		if item and Counter.fits(player, item, amount):
			Counter.deliver(player, item, amount)
			found.append("%s x%d" % [item.displayName, amount] if amount > 1 else item.displayName)
	var rareChance : float = float(spec[2]) * (1.0 + player.stat(&"digLuck") * 0.01)
	if randf() < rareChance:
		var rare : Item = load(pick(RARE)[0]) as Item
		if rare and Counter.fits(player, rare, 1):
			Counter.deliver(player, rare, 1)
			found.append(rare.displayName)
			if rare.resource_path.ends_with("sunken_crown.tres"):
				player.progress.count("dig_legendary")
			var board : NoticeBoard = NoticeBoard.find(player.get_tree())
			if board:
				board.post("Buried treasure!", rare.displayName, COLOR, rare.icon)
	state.index = int(state.index) + 1
	player.progress.count("digs")
	Skills.add(player, Skills.FORAGING, 25.0 * tier)
	if int(state.index) >= (state.points as Array).size():
		var chest : Item = load(spec[3]) as Item
		if chest and Counter.fits(player, chest, 1):
			Counter.deliver(player, chest, 1)
			found.append(chest.displayName)
		player.progress.flags.erase("dig/trail")
		player.progress.count("trails")
		player.progress.emit_changed()
	else:
		player.progress.set_flag("dig/trail", state)
	return ", ".join(found)

# Puts the X for the next spot on the island (and clears any old one).
static func place_spot(tree : SceneTree) -> void:
	var island : Island = Island.current(tree)
	var player : Player = Player.find(tree)
	if not island or not player:
		return
	for old in island.find_children("*", "DigSpot", true, false):
		old.queue_free()
	var at : Vector2 = target(player)
	if at == Vector2.INF:
		return
	var room : IslandRoom = island.room_at(at)
	if not room:
		return
	var spot : DigSpot = DigSpot.new()
	room.add_child(spot)
	spot.global_position = at

static func pick(list : Array) -> Array:
	var total : float = 0.0
	for entry in list:
		total += entry[1]
	var roll : float = randf() * total
	for entry in list:
		roll -= entry[1]
		if roll <= 0.0:
			return entry
	return list[0]
