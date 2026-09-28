extends Resource
class_name Inventory

# Something was caught or hooked with no room left, so the backpack should open.
signal needs_room

#------------------------#
@export var hotbarSize : int = 5
@export var backpackSize : int = 15
@export var items : Array[Item] = []

var catchSlot : int:
	get:
		return hotbarSize + backpackSize
var trashSlot : int:
	get:
		return catchSlot + 1
#------------------------#


func setup() -> void:
	items.resize(trashSlot + 1)
	for slot in items.size():
		if items[slot]:
			items[slot] = items[slot].unique()

func get_item(slot : int) -> Item:
	return items[slot] if slot >= 0 and slot < items.size() else null

func has_space() -> bool:
	return first_free() >= 0 or items[catchSlot] == null

func first_free() -> int:
	for slot in range(hotbarSize, catchSlot):
		if items[slot] == null:
			return slot
	for slot in hotbarSize:
		if items[slot] == null:
			return slot
	return -1

# Fills the backpack first, then the hotbar, then the catch slot. Returns the
# slot it went into, or -1 when even the catch slot was taken.
func add(item : Item) -> int:
	var slot : int = first_free()
	if slot < 0 and items[catchSlot] == null:
		slot = catchSlot
	if slot >= 0:
		items[slot] = item
		emit_changed()
	if slot == catchSlot or slot < 0:
		needs_room.emit()
	return slot

# Nothing can be dropped into the catch slot, and whatever ends up in the
# trash has to be discardable.
func can_move(from : int, to : int) -> bool:
	var moving : Item = get_item(from)
	var target : Item = get_item(to)
	if from == to or moving == null or to == catchSlot or to < 0 or to > trashSlot:
		return false
	if to == trashSlot:
		return moving.discardable
	if target == null:
		return true
	if from == catchSlot:
		return false
	return from != trashSlot or target.discardable

# Moving into the trash throws away what was in it before.
func move(from : int, to : int) -> void:
	if not can_move(from, to):
		return
	var target : Item = null if to == trashSlot else items[to]
	items[to] = items[from]
	items[from] = target
	emit_changed()
