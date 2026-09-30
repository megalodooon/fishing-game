extends RefCounted
class_name Museum

# The museum wing of Nora's aquarium (like SkyBlock's museum): rare catches,
# relics, trophies, hunt trophies and rare charms can be donated, one of each,
# for museum points by rarity. Points reach milestones with a reward each.
# Donations are progress flags ("museum/<file>").

const COLOR : Color = Color(0.85, 0.75, 0.45)
const POINTS : Dictionary = {"Common": 1, "Uncommon": 2, "Rare": 4, "Legendary": 8, "Trophy": 12}
const WINGS : PackedStringArray = ["Rare catches", "Relics and treasure", "Trophies", "Hunt trophies", "Charms"]
# Points needed, and the reward [item path, amount].
const MILESTONES : Array = [
	[10, ["res://items/enchanting/sea_essence.tres", 15]],
	[25, ["res://items/tools/pouch_stitching_1.tres", 1]],
	[50, ["res://items/charms/curators_monocle.tres", 1]],
	[90, ["res://items/enchanting/sea_essence.tres", 60]],
	[140, ["res://items/tools/pouch_stitching_2.tres", 1]],
	[200, ["res://items/digging/legends_map.tres", 2]],
	[280, ["res://items/tools/pouch_stitching_3.tres", 1]],
]

static var cache : Array[Item] = []


static func wing_of(item : Item) -> int:
	var path : String = item.original().resource_path
	if path.begins_with("res://items/rare/"):
		return 0 if item.category == "Rare Catch" else 1
	if path.begins_with("res://items/digging/"):
		return 1
	if path.begins_with("res://items/trophy/") and item.category == "Trophy Fish":
		return 2 if path.ends_with("_gold.tres") or path.ends_with("_diamond.tres") else -1
	if path.begins_with("res://items/hunts/"):
		return 3
	if item is Charm and item.rarity and ["Rare", "Legendary", "Trophy"].has(item.rarity.displayName):
		return 4
	return -1

# Everything that can be donated.
static func pieces() -> Array[Item]:
	if cache.is_empty():
		for item in Catalog.items():
			if wing_of(item) >= 0:
				cache.append(item)
	return cache

static func key(item : Item) -> String:
	return "museum/" + item.original().resource_path.get_file().get_basename()

static func donated(progress : Progress, item : Item) -> bool:
	return progress.has_flag(key(item))

static func points_of(item : Item) -> int:
	return POINTS.get(item.rarity.displayName if item.rarity else "Common", 1)

static func points(progress : Progress) -> int:
	var total : int = 0
	for item in pieces():
		if donated(progress, item):
			total += points_of(item)
	return total

static func donate(player : Player, slot : int) -> bool:
	var item : Item = player.inventory.get_item(slot)
	if not item or wing_of(item) < 0 or donated(player.progress, item):
		return false
	player.inventory.take_one(slot)
	player.progress.set_flag(key(item))
	player.progress.count("museum_items")
	AnglerLevel.forget()
	return true

static func claimed(progress : Progress) -> int:
	return int(progress.get_flag("museum/claimed", 0))

static func reached(progress : Progress) -> int:
	var have : int = points(progress)
	var at : int = 0
	for i in MILESTONES.size():
		if have >= int(MILESTONES[i][0]):
			at = i + 1
	return at
