extends Item
class_name Spade

# A spade for buried treasure (see Digging). Carried in the bag; the best one
# decides how many spots a treasure trail has.

#------------------------#
@export_range(1, 3) var tier : int = 1
# Spots in a trail dug with it.
@export var trail : int = 3
#------------------------#


func default_type() -> String:
	return "Spade"

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Trail length", "%d spots" % trail, "Works from the bag", ""])
	lines.append_array(super())
	return lines
