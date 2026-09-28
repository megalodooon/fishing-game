extends Item
class_name RodItem


#------------------------#
# One entry per tackle slot. Repeat a kind for extra slots of it.
@export var slots : Array[Tackle.Kind] = [Tackle.Kind.BOBBER, Tackle.Kind.LINE, Tackle.Kind.HOOK]
# What sits in each slot, in the same order. Empty slots use the rod's defaults.
@export var tackle : Array[Tackle] = []
#------------------------#


func unique() -> Item:
	var copy : RodItem = duplicate()
	copy.tackle = tackle.duplicate()
	copy.tackle.resize(slots.size())
	return copy

# The first bobber, line and hook slot always has to hold a part.
func is_required(slot : int) -> bool:
	return Tackle.REQUIRED.has(slots[slot]) and slots.find(slots[slot]) == slot

func set_tackle(slot : int, part : Tackle) -> void:
	tackle[slot] = part
	emit_changed()

# The rod's stat values and texts with these parts on, for previews.
func stat_rows(parts : Array[Tackle]) -> Array:
	var saved : Array[Tackle] = tackle
	tackle = parts
	var rod : FishingRod = heldScene.instantiate() as FishingRod
	rod.item = self
	var values : PackedFloat32Array = rod.stat_values()
	var texts : PackedStringArray = PackedStringArray()
	for i in values.size():
		texts.append(rod.stat_text(i, values[i]))
	rod.free()
	tackle = saved
	return [values, texts]
