extends Item
class_name Seed

# Planted in a farm plot by clicking an empty tile while holding it. Grows into its crop
# over some days, no watering needed.

#------------------------#
@export var crop : Item
@export var days : int = 2
@export var harvest : int = 1
# The sprout's color while it grows.
@export var leafColor : Color = Color(0.45, 0.8, 0.35)
#------------------------#


# Farming XP for harvesting it: slower crops teach more.
func xp() -> float:
	return 6.0 * days * (1.0 + (rarity.difficulty if rarity else 0.0) * 2.0)

func details() -> PackedStringArray:
	var lines : PackedStringArray = super()
	lines.append_array(["Grows in", "%d day%s" % [days, "" if days == 1 else "s"]])
	if crop:
		lines.append_array(["Gives", crop.displayName if harvest <= 1 else "%s x%d" % [crop.displayName, harvest]])
	return lines

func default_type() -> String:
	return "Seed"
