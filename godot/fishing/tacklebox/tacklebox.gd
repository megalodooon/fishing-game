extends Resource
class_name Tacklebox

# The collection of rod parts, kept as a count per part and never thrown away.
# A part on a rod uses up one copy until it comes off again.

# Parts came in, from a shop, a crafter or a reward.
signal gained(part : Tackle, amount : int)

#------------------------#
# Every part in the game, in the order the tacklebox lists them. Parts not
# owned yet show up as unknown.
@export var catalog : Array[Tackle] = []
@export var owned : Dictionary = {}
#------------------------#


func setup() -> void:
	owned = owned.duplicate()

func count(part : Tackle) -> int:
	return owned.get(part, 0)

func add(part : Tackle, amount : int = 1) -> void:
	owned[part] = count(part) + amount
	emit_changed()
	gained.emit(part, amount)

# Owned at some point, even if every copy got used up since.
func knows(part : Tackle) -> bool:
	return owned.has(part)

# Uses up one copy of a part that runs out, like bait. Once the last one is
# gone it comes off the rods.
func use_up(part : Tackle, inventory : Inventory) -> void:
	owned[part] = maxi(count(part) - 1, 0)
	var extra : int = used(part, inventory) - count(part)
	for item in inventory.items:
		if extra <= 0:
			break
		if item is RodItem:
			var rod : RodItem = item
			for slot in rod.tackle.size():
				if extra > 0 and rod.tackle[slot] == part:
					rod.set_tackle(slot, null)
					extra -= 1
	emit_changed()

func used(part : Tackle, inventory : Inventory) -> int:
	var total : int = 0
	for item in inventory.items:
		if item is RodItem:
			total += (item as RodItem).tackle.count(part)
	return total

func free_count(part : Tackle, inventory : Inventory) -> int:
	return count(part) - used(part, inventory)

func can_equip(rod : RodItem, slot : int, part : Tackle, inventory : Inventory) -> bool:
	if part == null:
		return not rod.is_required(slot)
	return rod.slots[slot] == part.kind and (rod.tackle[slot] == part or free_count(part, inventory) > 0)

func parts_of(kind : Tackle.Kind) -> Array[Tackle]:
	var list : Array[Tackle] = []
	for part in catalog:
		if part and part.kind == kind:
			list.append(part)
	for part in owned:
		if part is Tackle and part.kind == kind and not list.has(part):
			list.append(part)
	return list
