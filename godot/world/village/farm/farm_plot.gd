@tool
extends Node2D
class_name FarmPlot

# A few tiles of soil, farmed with the cursor. Clicking an empty tile with
# seeds held plants them, and clicking a grown crop harvests it into the bag.
# The tile under the cursor lights up while it's within reach of the player.
# Crops grow for the seed's days, no watering needed.

const GROUP : StringName = &"farm_plots"

#------------------------#
# Tells plots apart in the player's Progress.
@export var id : String = "farm"
@export var columns : int = 4:
	set(value):
		columns = maxi(value, 1)
		queue_redraw()
@export var rows : int = 2:
	set(value):
		rows = maxi(value, 1)
		queue_redraw()
@export var tileSize : Vector2i = Vector2i(10, 8):
	set(value):
		tileSize = value
		queue_redraw()
# How far from the player a tile can be clicked, to its middle.
@export var reach : float = 32.0

@export_group("Look")
@export var soilColor : Color = Color(0.36, 0.24, 0.16)
@export var furrowColor : Color = Color(0.28, 0.18, 0.12)
@export var edgeColor : Color = Color(0.22, 0.15, 0.1)
@export var readyColor : Color = Color(1.0, 0.95, 0.6)
@export var hoverColor : Color = Color(1.0, 1.0, 1.0, 0.8)
@export var farColor : Color = Color(0.95, 0.38, 0.34, 0.6)

var player : Player
var cycle : DayNightCycle
var time : float = 0.0
var hovered : int = -1
var hoverInReach : bool = false
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	player = Player.find(get_tree())
	cycle = DayNightCycle.find(get_tree())
	if cycle:
		cycle.day_changed.connect(queue_redraw.unbind(1))
	if player and player.progress:
		player.progress.changed.connect(queue_redraw)

func tiles() -> Array:
	return player.progress.plot(id, columns * rows) if player and player.progress else []

# Putting a seed in the ground takes a little energy.
const PLANT_ENERGY : float = 1.0

func tile_rect(index : int) -> Rect2:
	@warning_ignore("integer_division")
	var cell : Vector2 = Vector2(index % columns, index / columns)
	return Rect2(cell * Vector2(tileSize), Vector2(tileSize))

func area() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(columns * tileSize.x, rows * tileSize.y))

# The tile under a point in the world, or -1.
func tile_at(point : Vector2) -> int:
	var local : Vector2 = to_local(point)
	if not area().has_point(local):
		return -1
	return floori(local.y / tileSize.y) * columns + floori(local.x / tileSize.x)

func tile_center(index : int) -> Vector2:
	return to_global(tile_rect(index).get_center())

func in_reach(who : Player, index : int) -> bool:
	return who.global_position.distance_to(tile_center(index)) <= reach

func days_left(tile : Array) -> int:
	var kind : Seed = tile[0]
	return maxi(kind.days - ((cycle.day if cycle else 1) - int(tile[1])), 0)

# What clicking the tile would do: "plant", "harvest", or nothing.
func action(who : Player, index : int) -> String:
	var tile : Array = tiles()[index]
	if tile.is_empty():
		return "plant" if who.held_data() is Seed else ""
	return "harvest" if days_left(tile) <= 0 else ""

func hover_text(who : Player, index : int) -> String:
	var tile : Array = tiles()[index]
	match action(who, index):
		"plant":
			return "[Click] Plant" if in_reach(who, index) else "Too far"
		"harvest":
			return "[Click] Harvest" if in_reach(who, index) else "Too far"
	if not tile.is_empty():
		var left : int = days_left(tile)
		return "%d day%s to go" % [left, "" if left == 1 else "s"]
	return ""

func set_hover(index : int, ok : bool) -> void:
	if index != hovered or ok != hoverInReach:
		hovered = index
		hoverInReach = ok
		queue_redraw()

# Returns whether the click was used.
func click(who : Player, index : int) -> bool:
	var what : String = action(who, index)
	if what.is_empty():
		return false
	if not in_reach(who, index):
		who.say("too far", farColor)
		return true
	var tile : Array = tiles()[index]
	if what == "harvest":
		var kind : Seed = tile[0]
		var amount : int = kind.harvest + (1 if randf() * 100.0 < who.stat(&"harvestBonus") else 0)
		if who.inventory.room_for(kind.crop) < amount:
			who.say("bag full", farColor)
			return true
		who.inventory.give(kind.crop, amount)
		who.progress.clear_tile(id, index)
		who.progress.count("harvests")
		Quest.notify(who, &"harvest", kind.crop, amount)
		Skills.add(who, Skills.FARMING, kind.xp())
		who.say("+%d %s" % [amount, kind.crop.displayName], readyColor)
		return true
	if who.energy.value < PLANT_ENERGY:
		who.say("too tired", farColor)
		return true
	who.energy.spend(PLANT_ENERGY)
	var held : Seed = who.held_data() as Seed
	# Fully grown Green Hands sometimes keep the seed.
	var planted : Seed = (held.original() as Seed) if TideTree.has(who, "green_hands") and randf() < 0.2 else who.inventory.take_one(who.heldSlot) as Seed
	who.progress.plant(id, index, planted.original() as Seed, cycle.day if cycle else 1)
	Skills.add(who, Skills.FARMING, 1.0)
	return true

func _process(delta : float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	for tile in tiles():
		if not tile.is_empty() and days_left(tile) <= 0:
			queue_redraw()
			return

func _draw() -> void:
	var rect : Rect2 = area()
	draw_rect(rect.grow(1.0), edgeColor)
	draw_rect(rect, soilColor)
	for i in columns * rows:
		var cell : Rect2 = tile_rect(i)
		for y in range(2, tileSize.y, 3):
			draw_rect(Rect2(cell.position + Vector2(1.0, y), Vector2(tileSize.x - 2.0, 1.0)), furrowColor)
	if Engine.is_editor_hint():
		return
	var list : Array = tiles()
	for i in list.size():
		if not list[i].is_empty():
			draw_crop(tile_rect(i), list[i])
	if hovered >= 0:
		draw_rect(tile_rect(hovered).grow(-0.5), hoverColor if hoverInReach else farColor, false, 1.0)

func draw_crop(cell : Rect2, tile : Array) -> void:
	var kind : Seed = tile[0]
	var bottom : Vector2 = (cell.get_center() + Vector2(0.0, cell.size.y * 0.25)).floor()
	var left : int = days_left(tile)
	if left <= 0 and kind.crop and kind.crop.icon:
		var icon : Texture2D = kind.crop.icon
		var bob : float = roundf(sin(time * 3.0 + cell.position.x) * 0.5)
		draw_texture(icon, (bottom - Vector2(icon.get_width() * 0.5, icon.get_height() - 1.0 + bob)).floor())
		if fmod(time + cell.position.x * 0.1, 2.5) < 0.25:
			draw_rect(Rect2(bottom + Vector2(2.0, -icon.get_height()), Vector2.ONE), readyColor)
		return
	var grown : float = 1.0 - float(left) / maxf(kind.days, 1.0)
	var height : int = 1 + roundi(grown * 3.0)
	draw_rect(Rect2(bottom - Vector2(0.0, height), Vector2(1.0, height)), kind.leafColor.darkened(0.2))
	if height >= 2:
		draw_rect(Rect2(bottom + Vector2(-1.0, -height), Vector2.ONE), kind.leafColor)
		draw_rect(Rect2(bottom + Vector2(1.0, -height + 1.0), Vector2.ONE), kind.leafColor)
	if height >= 4:
		draw_rect(Rect2(bottom + Vector2(-2.0, -height + 1.0), Vector2.ONE), kind.leafColor.lightened(0.2))
		draw_rect(Rect2(bottom + Vector2(2.0, -height), Vector2.ONE), kind.leafColor.lightened(0.2))
