extends Item
class_name DigMap

# A buried treasure map. Clicking with it held on an island buries a trail of
# treasure there to dig up (see Digging). Higher tiers hold richer loot.

#------------------------#
@export_range(1, 3) var tier : int = 1
# More spots on top of what the spade digs.
@export var extraSpots : int = 0
#------------------------#


func use(player : Player) -> bool:
	if player.heldSlot < 0:
		return false
	var why : String = Digging.begin(player, self)
	if not why.is_empty():
		player.say(why, Color(0.82, 0.86, 0.92))
		return true
	player.inventory.take_one(player.heldSlot)
	Digging.place_spot(player.get_tree())
	player.say("X marks the spot! Follow the arrow.", Digging.COLOR)
	return true

func default_type() -> String:
	return "Treasure Map"

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Map tier", "%d" % tier, "Open on an island", "", "Needs a spade", ""])
	lines.append_array(super())
	return lines
