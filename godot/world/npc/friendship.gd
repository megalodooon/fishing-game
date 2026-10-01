extends RefCounted
class_name Friendship

# How well the player knows each villager, in hearts (Stardew style). Talking
# once a day and gifts raise it; each villager takes two gifts a week and
# loves, likes, dislikes or hates certain things (TASTES), and a gift on their
# birthday counts eight times. Every two hearts a heart scene plays the next
# time they're talked to ("<id>_heart<N>" in the dialogue file) with a gift
# from them (HEART_GIFTS). Friends also sell cheaper in their shop.
# Saved in Progress.friends: id -> {points, talked, gifts (days), birthday}.

const POINTS_PER_HEART : int = 250
const MAX_HEARTS : int = 10
const TALK_POINTS : int = 20
const GIFTS_PER_WEEK : int = 2
const BIRTHDAY_TIMES : int = 8
const DISCOUNT_PER_HEART : float = 0.01
const REACTIONS : Dictionary = {"loved": 80, "liked": 45, "neutral": 20, "disliked": -20, "hated": -40}
const HEART_COLOR : Color = Color(1.0, 0.45, 0.6)
# Day of the year (1-56) of each villager's birthday.
const BIRTHDAYS : Dictionary = {
	"yuki": 3, "pip": 5, "brann": 9, "nora": 12, "mara": 16, "gus": 19, "moss": 23, "tilly": 25, "luma": 27,
	"silas": 31, "bo": 34, "marina": 38, "hale": 41, "rex": 44, "vera": 45, "opal": 47, "odette": 29,
	"barnaby": 13, "oriel": 40, "wally": 52, "grim": 53, "finn": 55,
}
# What they think of gifts: item paths, "cat:<category or type>",
# "rarity:<name>" (that rarity or better), "fish" (any fish) or
# "fish:<rarity>" (fish of that rarity or better). Checked hated, disliked,
# loved, liked; anything else is neutral, junk is disliked by everyone.
const TASTES : Dictionary = {
	"pip": {"loved": ["res://items/snacks/island_coffee.tres", "res://items/snacks/sunflower_bread.tres", "res://items/materials/honey.tres"], "liked": ["cat:Food", "fish"], "disliked": ["cat:Potion"], "hated": ["res://items/materials/oily_sludge.tres"]},
	"gus": {"loved": ["fish:rare", "res://items/snacks/fish_taco.tres"], "liked": ["fish", "res://items/materials/sea_salt.tres"], "disliked": ["cat:Crop"], "hated": ["res://items/materials/old_boot.tres"]},
	"nora": {"loved": ["res://items/rare/sea_glass.tres", "res://items/materials/pearl_oyster.tres", "fish:legendary"], "liked": ["res://items/materials/sea_shell.tres", "res://items/materials/starfish.tres", "fish:uncommon"], "disliked": ["res://items/materials/fish_oil.tres"], "hated": ["res://items/materials/tin_can.tres"]},
	"tilly": {"loved": ["res://items/snacks/pumpkin_pie.tres", "res://items/materials/honey.tres", "res://items/materials/sunflower.tres"], "liked": ["cat:Crop", "cat:Seed"], "disliked": ["res://items/materials/iron_scrap.tres"], "hated": ["res://items/materials/oily_sludge.tres"]},
	"silas": {"loved": ["res://items/snacks/island_tea.tres", "res://items/snacks/grilled_fish.tres", "res://items/rare/old_map_fragment.tres"], "liked": ["res://items/materials/driftwood_plank.tres", "fish:uncommon"], "disliked": ["res://items/snacks/energy_soda.tres"], "hated": ["res://items/events/candy_cane.tres"]},
	"marina": {"loved": ["res://items/materials/treated_plank.tres", "res://items/materials/iron_ingot.tres"], "liked": ["res://items/materials/rope.tres", "res://items/materials/driftwood_plank.tres", "cat:Refined"], "disliked": ["res://items/materials/seaweed.tres"], "hated": ["res://items/materials/rust_flakes.tres"]},
	"rex": {"loved": ["res://items/rare/pirate_doubloon.tres", "res://items/snacks/energy_soda.tres", "fish:legendary"], "liked": ["fish:rare"], "disliked": ["cat:Crop"], "hated": ["fish:common"]},
	"vera": {"loved": ["res://items/rare/abyssal_pearl.tres", "res://items/snacks/lava_cake.tres"], "liked": ["cat:Charm", "rarity:rare"], "disliked": ["fish:common"], "hated": ["res://items/materials/seaweed.tres"]},
	"brann": {"loved": ["res://items/materials/obsidian_shard.tres", "res://items/materials/iron_ingot.tres", "res://items/snacks/ember_curry.tres"], "liked": ["res://items/materials/iron_scrap.tres", "res://items/materials/pumice.tres"], "disliked": ["res://items/materials/frost_lichen.tres"], "hated": ["res://items/materials/frost_crystal.tres"]},
	"mara": {"loved": ["res://items/snacks/seafood_paella.tres", "res://items/snacks/fish_stew.tres"], "liked": ["cat:Food"], "disliked": ["res://items/materials/barnacle.tres"], "hated": ["res://items/materials/sludge_gland.tres"]},
	"luma": {"loved": ["res://items/materials/storm_glass.tres", "res://items/events/wishing_star.tres", "res://items/events/fallen_star.tres"], "liked": ["res://items/materials/frost_crystal.tres", "res://items/events/stardust.tres"], "disliked": ["res://items/materials/clay.tres"], "hated": ["res://items/materials/rust_flakes.tres"]},
	"bo": {"loved": ["res://items/snacks/honey_cake.tres", "res://items/materials/wild_berries.tres", "res://items/events/candy_corn.tres"], "liked": ["res://items/materials/sea_shell.tres", "res://items/materials/starfish.tres"], "disliked": ["res://items/materials/sea_kale.tres"], "hated": ["res://items/materials/ink_sac.tres"]},
	"hale": {"loved": ["res://items/events/contest_ribbon.tres", "res://items/events/gold_ornament.tres", "fish:legendary"], "liked": ["fish:rare"], "disliked": ["res://items/materials/barnacle.tres"], "hated": ["res://items/materials/old_boot.tres"]},
	"opal": {"loved": ["res://items/materials/pearl_oyster.tres", "res://items/materials/pearl_dust.tres", "res://items/rare/sea_glass.tres"], "liked": ["res://items/materials/sea_shell.tres", "res://items/materials/coral_shard.tres"], "disliked": ["res://items/materials/ember_ash.tres"], "hated": ["res://items/materials/oily_sludge.tres"]},
	"grim": {"loved": ["res://items/rare/treasure_map.tres", "res://items/rare/pirate_doubloon.tres"], "liked": ["res://items/materials/shark_tooth.tres", "res://items/materials/kraken_tentacle.tres"], "disliked": ["res://items/materials/sunflower.tres"], "hated": ["res://items/snacks/kale_salad.tres"]},
	"yuki": {"loved": ["res://items/snacks/hot_cocoa.tres", "res://items/materials/frost_crystal.tres"], "liked": ["res://items/materials/frost_lichen.tres", "res://items/materials/frostberry.tres"], "disliked": ["res://items/materials/chili_pepper.tres"], "hated": ["res://items/materials/ember_ash.tres"]},
	"moss": {"loved": ["res://items/materials/swamp_moss.tres", "res://items/materials/glowcap.tres", "cat:Potion"], "liked": ["res://items/materials/mangrove_root.tres", "res://items/materials/glow_worm.tres"], "disliked": ["cat:Refined"], "hated": ["res://items/snacks/energy_soda.tres"]},
	"finn": {"loved": ["res://items/snacks/grilled_fish.tres", "res://items/materials/honey.tres", "fish:legendary"], "liked": ["fish"], "disliked": [], "hated": []},
	"wally": {"loved": ["res://items/events/wrapped_gift.tres", "res://items/events/candy_cane.tres"], "liked": ["res://items/events/snowflake.tres"], "disliked": [], "hated": ["res://items/materials/ember_ash.tres"]},
	"oriel": {"loved": ["rarity:legendary"], "liked": ["rarity:rare"], "disliked": ["fish:common"], "hated": ["res://items/materials/tin_can.tres"]},
	"barnaby": {"loved": ["res://items/rare/pirate_doubloon.tres", "res://items/events/gold_ornament.tres"], "liked": ["cat:Refined"], "disliked": ["fish"], "hated": ["res://items/materials/oily_sludge.tres"]},
	"odette": {"loved": ["cat:Trophy Fish", "fish:legendary"], "liked": ["fish:rare"], "disliked": ["cat:Crop"], "hated": ["res://items/materials/old_boot.tres"]},
}
# What each villager gives at a heart scene: hearts -> [item path, amount].
const HEART_GIFTS : Dictionary = {
	2: ["res://items/snacks/fish_stew.tres", 3],
	4: ["res://items/materials/honey.tres", 5],
	6: ["res://items/charms/heart_locket.tres", 1],
	8: ["res://items/rare/lucky_stone.tres", 1],
	10: ["res://items/enchanting/sea_essence.tres", 40],
}
const RARITY_ORDER : PackedStringArray = ["Common", "Uncommon", "Rare", "Legendary", "Trophy"]


static func entry(progress : Progress, id : String) -> Dictionary:
	if not progress.friends.has(id):
		progress.friends[id] = {"points": 0, "talked": -1, "gifts": [], "birthday": -1}
	return progress.friends[id]

static func points(progress : Progress, id : String) -> int:
	return int(progress.friends[id].points) if progress.friends.has(id) else 0

static func hearts(progress : Progress, id : String) -> int:
	return mini(floori(points(progress, id) / float(POINTS_PER_HEART)), MAX_HEARTS)

# 0 to 1 through the current heart.
static func heart_progress(progress : Progress, id : String) -> float:
	if hearts(progress, id) >= MAX_HEARTS:
		return 1.0
	return fmod(float(points(progress, id)), POINTS_PER_HEART) / POINTS_PER_HEART

static func short_name(id : String) -> String:
	var full : String = Cast.name_of(id)
	for title in ["Harbor Master ", "Smith ", "Innkeeper ", "Old ", "Auntie ", "Grandpa ", "Captain ", "Commissioner "]:
		full = full.trim_prefix(title)
	return full.get_slice(" ", 0)

static func is_birthday(id : String, day : int) -> bool:
	return BIRTHDAYS.get(id, -99) == Calendar.day_of_year(day)

static func add(player : Player, id : String, amount : int) -> void:
	var data : Dictionary = entry(player.progress, id)
	var before : int = hearts(player.progress, id)
	data.points = clampi(int(data.points) + amount, 0, POINTS_PER_HEART * MAX_HEARTS)
	var after : int = hearts(player.progress, id)
	player.progress.emit_changed()
	if after > before:
		var board : NoticeBoard = NoticeBoard.find(player.get_tree())
		if board:
			board.post("%s: %d hearts!" % [short_name(id), after], "Your friendship grows." + (" Talk to them soon." if after % 2 == 0 and after > 0 else ""), HEART_COLOR, Cast.portrait(id))
		Achievements.notify(player, &"heart", id, after)

# Talking once a day counts. Returns whether it counted.
static func talk(player : Player, id : String, day : int) -> bool:
	var data : Dictionary = entry(player.progress, id)
	if int(data.talked) == day:
		return false
	data.talked = day
	player.progress.count("talks")
	add(player, id, TALK_POINTS)
	return true

static func talked_today(progress : Progress, id : String, day : int) -> bool:
	return progress.friends.has(id) and int(progress.friends[id].talked) == day

static func gifts_this_week(progress : Progress, id : String, day : int) -> int:
	if not progress.friends.has(id):
		return 0
	@warning_ignore("integer_division")
	var week : int = (day - 1) / 7
	var count : int = 0
	for when in progress.friends[id].gifts:
		@warning_ignore("integer_division")
		if (int(when) - 1) / 7 == week:
			count += 1
	return count

static func gifted_today(progress : Progress, id : String, day : int) -> bool:
	return progress.friends.has(id) and (progress.friends[id].gifts as Array).has(day)

# Why a gift can't be given right now, or nothing.
static func gift_blocked(progress : Progress, id : String, day : int) -> String:
	if gifted_today(progress, id, day):
		return "Already had a gift today"
	if gifts_this_week(progress, id, day) >= GIFTS_PER_WEEK and not is_birthday(id, day):
		return "Two gifts a week is plenty"
	return ""

static func matches(token : String, item : Item) -> bool:
	if token.begins_with("res://"):
		return item.original().resource_path == token or (item is Fish and (item as Fish).species and (item as Fish).species.resource_path == token)
	if token.begins_with("cat:"):
		var what : String = token.substr(4)
		return item.category == what or item.type_name() == what
	if token.begins_with("rarity:"):
		return rank(item.rarity) >= RARITY_ORDER.find(token.substr(7).capitalize())
	if token == "fish":
		return item is Fish
	if token.begins_with("fish:"):
		return item is Fish and rank(item.rarity) >= RARITY_ORDER.find(token.substr(5).capitalize())
	return false

static func rank(rarity : Rarity) -> int:
	return RARITY_ORDER.find(rarity.displayName) if rarity else 0

# "loved", "liked", "neutral", "disliked" or "hated".
static func taste(id : String, item : Item) -> String:
	var tastes : Dictionary = TASTES.get(id, {})
	for kind in ["hated", "disliked", "loved", "liked"]:
		for token in tastes.get(kind, []):
			if matches(token, item):
				return kind
	if item.category == "Junk":
		return "disliked"
	return "neutral"

# Gives one of the item and returns the reaction.
static func give(player : Player, id : String, slot : int, day : int) -> String:
	var item : Item = player.inventory.get_item(slot)
	if not item:
		return ""
	var reaction : String = taste(id, item)
	var amount : int = REACTIONS[reaction]
	if is_birthday(id, day) and amount > 0:
		amount *= BIRTHDAY_TIMES
	player.inventory.take_one(slot)
	var data : Dictionary = entry(player.progress, id)
	# Only this week's gifts are kept.
	var kept : Array = []
	for when in data.gifts:
		if floori((int(when) - 1) / 7.0) == floori((day - 1) / 7.0):
			kept.append(when)
	kept.append(day)
	data.gifts = kept
	add(player, id, amount)
	player.progress.count("gifts")
	if reaction == "loved":
		player.progress.count("gifts_loved")
	Achievements.notify(player, &"gift", id, reaction)
	return reaction

# The heart scene waiting to be seen, like "nora_heart4", or "".
static func heart_scene(progress : Progress, id : String) -> String:
	var have : int = hearts(progress, id)
	for at in [2, 4, 6, 8, 10]:
		if have >= at:
			var scene : String = "%s_heart%d" % [id, at]
			if not progress.has_flag("seen/" + scene) and Dialogue.has_scene(scene):
				return scene
	return ""

# After a heart scene: marks it seen and hands over their gift.
static func finish_heart_scene(player : Player, scene : String) -> void:
	player.progress.set_flag("seen/" + scene)
	var at : int = int(scene.get_slice("_heart", 1))
	var gift : Array = HEART_GIFTS.get(at, [])
	if gift.is_empty() or not ResourceLoader.exists(gift[0]):
		return
	var item : Item = load(gift[0]) as Item
	Counter.deliver(player, item, gift[1])
	var board : NoticeBoard = NoticeBoard.find(player.get_tree())
	if board:
		board.post("A gift from %s" % short_name(scene.get_slice("_heart", 0)), "%s x%d" % [item.displayName, gift[1]] if gift[1] > 1 else item.displayName, HEART_COLOR, item.icon)

# What a villager's shop takes off for a friend, 0 to 0.1.
static func discount(progress : Progress, id : String) -> float:
	return hearts(progress, id) * DISCOUNT_PER_HEART if not id.is_empty() else 0.0

# How many villagers are at least this friendly.
static func count_at(progress : Progress, at_hearts : int) -> int:
	var count : int = 0
	for id in progress.friends:
		if hearts(progress, id) >= at_hearts:
			count += 1
	return count
