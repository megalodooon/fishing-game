extends Item
class_name CrabPot

# Set out at a trap spot on an island, it fills up by itself every day with
# the local catch (see TrapSpot), up to its capacity. Better pots catch more,
# hold more and bring up rarer things.

#------------------------#
@export var perDay : int = 2
@export var capacity : int = 6
# How much likelier rare catches and extras are.
@export var luck : float = 1.0
#------------------------#


func default_type() -> String:
	return "Trap"

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Catches", "%d a day" % perDay, "Holds", "%d" % capacity])
	if luck > 1.0:
		lines.append_array(["Luck", "x%.1f" % luck])
	lines.append_array(["Set it at a trap spot", ""])
	lines.append_array(super())
	return lines
