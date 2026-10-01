extends Item
class_name BagUpgrade

# Sewn into the backpack by clicking with it held: the backpack keeps the
# extra slots for good and the item is used up. Each kind works once. See
# BoatParts.apply for how the backpack's size adds up.

#------------------------#
@export var slots : int = 3
# Was for the old charm pouch; now these go in the backpack too.
@export var pouch : bool = false
#------------------------#


func flag() -> String:
	return "bag/" + original().resource_path.get_file().get_basename()

func use(player : Player) -> bool:
	if player.heldSlot < 0:
		return false
	if player.progress.has_flag(flag()):
		player.say("already sewn in", Color(0.82, 0.86, 0.92))
		return true
	player.inventory.take_one(player.heldSlot)
	player.progress.set_flag(flag())
	player.progress.count("bag_slots", slots)
	BoatParts.apply(player)
	player.say("+%d backpack slots!" % slots, Color(0.56, 0.93, 0.44))
	return true

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Backpack", "+%d slots" % slots, "Click to sew it in", ""])
	lines.append_array(super())
	return lines

func default_type() -> String:
	return "Bag Upgrade"
