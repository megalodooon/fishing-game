@tool
extends Interactable
class_name ForageSpot

# A place on an island worth gathering from: a berry bush, a tide pool, a
# pile of driftwood. It's full until the player gathers it with F, then bare
# until it grows back a few days later. What it gives is set by its kind (see
# KINDS), so a spot in a scene is just a kind and a position. Some kinds need
# a better foraging tool in the bag (see ForageTool); tools also add to the
# yield and the odds of the rare find. The art is world/forage/art/<kind>.png:
# two frames side by side, full then gathered.

enum Kind { BERRY_BUSH, TIDE_POOL, SALT_CRUST, DRIFTWOOD, PALM_LITTER, CLAY_BANK, REEDS, OYSTER_BED, FROST_ROCK, EMBER_VENT, STORM_SHARDS, SCRAP_HEAP, CORAL_HEAP, NEST }

const ART : String = "res://world/forage/art/%s.png"
const XP_EACH : float = 4.0
const READY_GLINT : Color = Color(1.0, 0.97, 0.8)
# Per kind: file name, name, verb, [item path, weight] list, rare item path,
# rare chance, days to grow back, tool tier needed, where they're found.
const KINDS : Dictionary = {
	Kind.BERRY_BUSH: ["berry_bush", "Berry bush", "Pick berries", [["res://items/materials/wild_berries.tres", 5.0]], "res://items/materials/honey.tres", 0.05, 2, 0, "Bramblewick, Meadow Isle"],
	Kind.TIDE_POOL: ["tide_pool", "Tide pool", "Search the pool", [["res://items/materials/sea_shell.tres", 3.0], ["res://items/materials/barnacle.tres", 3.0], ["res://items/materials/starfish.tres", 1.0]], "res://items/rare/sea_glass.tres", 0.04, 2, 0, "Bramblewick, Driftwood Cay, Pearl Lagoon, Wreck Atoll, Champion Atoll"],
	Kind.SALT_CRUST: ["salt_crust", "Salt flat", "Scrape salt", [["res://items/materials/sea_salt.tres", 4.0], ["res://items/materials/beach_sand.tres", 3.0]], "res://items/materials/pearl_oyster.tres", 0.03, 1, 0, "Driftwood Cay, Tidal Shrine"],
	Kind.DRIFTWOOD: ["driftwood", "Driftwood pile", "Pick through it", [["res://items/materials/driftwood_plank.tres", 4.0], ["res://items/materials/palm_frond.tres", 1.5], ["res://items/materials/gull_feather.tres", 0.8]], "res://items/rare/old_map_fragment.tres", 0.02, 2, 0, "Bramblewick, Driftwood Cay, Wreck Atoll"],
	Kind.PALM_LITTER: ["palm_litter", "Fallen fronds", "Gather fronds", [["res://items/materials/palm_frond.tres", 4.0], ["res://items/materials/gull_feather.tres", 1.0]], "res://items/materials/wild_berries.tres", 0.1, 2, 0, "Lantern Key"],
	Kind.CLAY_BANK: ["clay_bank", "Clay bank", "Dig clay", [["res://items/materials/clay.tres", 4.0], ["res://items/materials/beach_sand.tres", 1.5]], "res://items/materials/wormroot.tres", 0.08, 2, 0, "Meadow Isle, Mangrove Hollow"],
	Kind.REEDS: ["reeds", "Reed bed", "Cut reeds", [["res://items/materials/swamp_moss.tres", 3.0], ["res://items/materials/mangrove_root.tres", 3.0]], "res://items/materials/glow_worm.tres", 0.06, 2, 0, "Mangrove Hollow"],
	Kind.OYSTER_BED: ["oyster_bed", "Oyster bed", "Pry oysters", [["res://items/materials/pearl_oyster.tres", 3.0], ["res://items/materials/sea_shell.tres", 2.0]], "res://items/rare/sea_glass.tres", 0.05, 3, 1, "Pearl Lagoon, Tidal Shrine"],
	Kind.FROST_ROCK: ["frost_rock", "Frosted rocks", "Chip the frost", [["res://items/materials/frost_lichen.tres", 4.0], ["res://items/materials/frost_crystal.tres", 1.5]], "res://items/rare/frozen_relic.tres", 0.008, 3, 1, "Frostpeak"],
	Kind.EMBER_VENT: ["ember_vent", "Ember vent", "Rake the vent", [["res://items/materials/ember_ash.tres", 3.0], ["res://items/materials/pumice.tres", 3.0], ["res://items/materials/obsidian_shard.tres", 1.0]], "res://items/rare/magma_heart.tres", 0.008, 3, 2, "Ember Isle"],
	Kind.STORM_SHARDS: ["storm_shards", "Storm glass", "Break off shards", [["res://items/materials/storm_glass.tres", 3.0], ["res://items/materials/storm_essence.tres", 0.8]], "res://items/rare/storm_crystal.tres", 0.008, 3, 2, "Stormwatch"],
	Kind.SCRAP_HEAP: ["scrap_heap", "Scrap heap", "Salvage", [["res://items/materials/scrap_wire.tres", 3.0], ["res://items/materials/iron_scrap.tres", 3.0], ["res://items/materials/rust_flakes.tres", 1.5]], "res://items/materials/deepnet_chip.tres", 0.04, 2, 0, "The Deepnet Rig"],
	Kind.CORAL_HEAP: ["coral_heap", "Coral heap", "Break off coral", [["res://items/materials/coral_shard.tres", 3.0], ["res://items/materials/starfish.tres", 1.5], ["res://items/materials/deep_coral.tres", 0.8]], "res://items/rare/abyssal_pearl.tres", 0.006, 4, 3, "Champion Atoll"],
	Kind.NEST: ["nest", "Gull nest", "Take feathers", [["res://items/materials/gull_feather.tres", 4.0], ["res://items/materials/palm_frond.tres", 1.0]], "res://items/rare/lucky_stone.tres", 0.01, 2, 0, "Lantern Key, Stormwatch"],
}

#------------------------#
@export var kind : Kind = Kind.BERRY_BUSH:
	set(value):
		kind = value
		art = null
		queue_redraw()

var player : Player
var art : Texture2D
var glint : float = 0.0
var glintWait : float = 2.0
var burst : float = -1.0
#------------------------#


func _ready() -> void:
	if prompt == "Use":
		prompt = "Gather"
	reach = 11.0
	promptOffset = Vector2(0.0, -14.0)
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	glintWait = randf_range(1.0, 4.0)

func info() -> Array:
	return KINDS[kind]

func picture() -> Texture2D:
	if not art:
		var path : String = ART % info()[0]
		art = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return art

func key() -> String:
	return "forage/" + String(get_path())

func today() -> int:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	return cycle.day if cycle else 1

# The day it's full again (0 when it never was gathered).
func regrows_on() -> int:
	if not player or not player.progress:
		return 0
	var taken : Variant = player.progress.get_flag(key())
	return int(taken) + int(info()[6]) if taken != null else 0

func ready_now() -> bool:
	return today() >= regrows_on()

static func needed_tool_name(tier : int) -> String:
	return ForageTool.name_for(tier)

func blocked_reason(who : Player) -> String:
	var why : String = super(who)
	if not why.is_empty():
		return why
	if not ready_now():
		var wait : int = regrows_on() - today()
		return "Grows back %s" % ("tomorrow" if wait <= 1 else "in %d days" % wait)
	if ForageTool.best_tier(who) < int(info()[7]):
		return "Needs a %s" % needed_tool_name(int(info()[7]))
	return ""

func prompt_text(who : Player) -> String:
	var why : String = blocked_reason(who)
	return info()[2] if why.is_empty() else "%s: %s" % [info()[1], why.to_lower()]

func try_interact(who : Player) -> void:
	var why : String = blocked_reason(who)
	if why.is_empty():
		interact(who)
	else:
		notice(info()[1], why + ".", blockedColor, picture_icon())

func picture_icon() -> Texture2D:
	var first : Item = load(info()[3][0][0]) as Item
	return first.icon if first else null

# Picks an item from the kind's list by weight.
func roll(list : Array) -> Item:
	var total : float = 0.0
	for entry in list:
		total += entry[1]
	var pick : float = randf() * total
	for entry in list:
		pick -= entry[1]
		if pick <= 0.0:
			return load(entry[0]) as Item
	return load(list[0][0]) as Item

func interact(who : Player) -> void:
	var tool : ForageTool = ForageTool.best(who)
	var bonus : float = who.stat(&"forageBonus")
	var total : int = randi_range(3, 5) + (tool.yieldBonus if tool else 0)
	while bonus > 0.0:
		if randf() * 100.0 < minf(bonus, 100.0):
			total += 1
		bonus -= 100.0
	var got : Dictionary = {}
	for i in total:
		var item : Item = roll(info()[3])
		if item:
			got[item] = got.get(item, 0) + 1
	var rareChance : float = float(info()[5]) * (tool.rareBoost if tool else 1.0) * (1.0 + who.stat(&"rareFind") * 0.01)
	if randf() < rareChance:
		var rare : Item = load(info()[4]) as Item
		if rare:
			got[rare] = got.get(rare, 0) + 1
	var texts : PackedStringArray = PackedStringArray()
	var gathered : int = 0
	for item in got:
		var given : int = who.inventory.give(item, got[item])
		if given > 0:
			gathered += given
			texts.append("+%d %s" % [given, item.displayName])
			Quest.notify(who, &"forage", item, given)
	if gathered <= 0:
		notice(info()[1], "No room in the bag.", blockedColor)
		return
	who.progress.set_flag(key(), today())
	who.progress.count("forage", gathered)
	var xp : float = XP_EACH * gathered * (1.0 + int(info()[7]) * 0.6)
	Skills.add(who, Skills.FORAGING, xp)
	who.say(", ".join(texts), Color(0.8, 0.92, 0.6))
	burst = 0.0
	set_process(true)
	queue_redraw()

func _process(delta : float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var redraw : bool = false
	if burst >= 0.0:
		burst += delta
		redraw = true
		if burst > 0.6:
			burst = -1.0
	if ready_now():
		glintWait -= delta
		if glintWait <= 0.0:
			glint = 0.5
			glintWait = randf_range(2.5, 5.0)
		if glint > 0.0:
			glint = maxf(glint - delta, 0.0)
			redraw = true
	if redraw:
		queue_redraw()

func _draw() -> void:
	var texture : Texture2D = picture()
	if not texture:
		if Engine.is_editor_hint():
			draw_rect(Rect2(-6.0, -8.0, 12.0, 8.0), Color(0.5, 1.0, 0.6, 0.6), false, 1.0)
			super()
		return
	var frame : Vector2 = Vector2(floorf(texture.get_width() * 0.5), texture.get_height())
	var full : bool = Engine.is_editor_hint() or ready_now()
	var source : Rect2 = Rect2(Vector2(0.0 if full else frame.x, 0.0), frame)
	var at : Vector2 = Vector2(-floorf(frame.x * 0.5), -frame.y + 2.0)
	draw_texture_rect_region(texture, Rect2(at, frame), source)
	if glint > 0.0 and full:
		var t : float = sin(glint / 0.5 * PI)
		var spark : Vector2 = at + Vector2(frame.x * 0.7, 3.0).round()
		draw_rect(Rect2(spark, Vector2.ONE), Color(READY_GLINT, t))
		draw_rect(Rect2(spark + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), Color(READY_GLINT, t * 0.5))
		draw_rect(Rect2(spark + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), Color(READY_GLINT, t * 0.5))
	if burst >= 0.0:
		var fade : float = 1.0 - burst / 0.6
		for i in 6:
			var angle : float = TAU * i / 6.0 + 0.4
			var point : Vector2 = at + frame * Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle) * 0.6) * (3.0 + burst * 18.0)
			draw_rect(Rect2(point.round(), Vector2.ONE), Color(0.85, 1.0, 0.7, fade))
	if Engine.is_editor_hint():
		super()
