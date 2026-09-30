extends Tackle
class_name Reforge

# A rod's reforge: a word in front of its name and a few stats on top of its
# parts, like a "Swift Bamboo Rod". The anvil rolls a random one from those
# with a weight above 0 for coins; the rest need their stone, a rare catch.
# Files live in res://fishing/reforges.

const FOLDER : String = "res://fishing/reforges"

#------------------------#
@export var prefix : String = ""
# How often the anvil rolls it. 0 means only its stone gives it.
@export var weight : float = 1.0
# The rare stone that gives it, used up.
@export var stone : Item
#------------------------#


static var cache : Array[Reforge] = []
static var scanned : bool = false


static func all() -> Array[Reforge]:
	if not scanned:
		scanned = true
		for resource in Catalog.scan(FOLDER):
			if resource is Reforge:
				cache.append(resource)
	return cache

# A random reforge from the anvil's pool, never the one the rod has.
static func roll(current : Reforge) -> Reforge:
	var weights : Dictionary = {}
	for each in all():
		if each.weight > 0.0 and each != current:
			weights[each] = each.weight
	return FishData.pick(weights) if not weights.is_empty() else null

static func for_stone(item : Item) -> Reforge:
	for each in all():
		if each.stone and item and each.stone == item.original():
			return each
	return null

# Its stats as short text, like "Bite speed x1.10, Control +5%".
func summary() -> String:
	var lines : PackedStringArray = details()
	var parts : PackedStringArray = PackedStringArray()
	for i in range(0, lines.size() - 1, 2):
		parts.append("%s %s" % [lines[i], lines[i + 1]])
	return ", ".join(parts)

func default_type() -> String:
	return "Reforge"
