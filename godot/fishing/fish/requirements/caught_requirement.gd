extends FishRequirement
class_name CaughtRequirement

# Only bites once these fish have been caught, this many of each.

#------------------------#
@export var fish : Array[FishData] = []
@export var count : int = 1
#------------------------#


func met(context : FishingContext) -> bool:
	var journal : Journal = context.player.journal if context.player else null
	if not journal:
		return true
	for data in fish:
		if data and journal.count(data) < count:
			return false
	return true

func describe() -> String:
	var names : PackedStringArray = PackedStringArray()
	for data in fish:
		if data:
			names.append(data.displayName)
	return "After catching %s%s" % [", ".join(names), "" if count <= 1 else " (%d each)" % count]
