extends Item
class_name Gear

# Something worn: a hat or gear (a coat, a vest, overalls). It goes in its
# equipment slot (see Equipment) and adds its stats while worn. Many also do
# one thing no stat can (unique, see Equipment.UNIQUES), like making rain
# better for fishing or trips shorter.

enum Slot { HAT, GEAR }

#------------------------#
@export var slot : Slot = Slot.HAT
@export var stats : Dictionary[StringName, float] = {}
# What only this does, by id (see Equipment.UNIQUES); empty for none.
@export var unique_effect : StringName = &""
#------------------------#


func default_type() -> String:
	return "Hat" if slot == Slot.HAT else "Gear"

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	for stat in stats:
		lines.append_array([Stats.name_of(stat), Stats.bonus_text(stat, stats[stat])])
	if not unique_effect.is_empty():
		lines.append_array([Equipment.UNIQUES.get(unique_effect, ""), ""])
	lines.append_array(["Use it to wear it", ""])
	lines.append_array(super())
	return lines

func use(player : Player) -> bool:
	return Equipment.equip(player, player.heldSlot)
