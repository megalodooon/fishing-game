extends Resource
class_name Inventory

# Something was caught or hooked with no room left, so the backpack should open.
signal needs_room
signal trashed(item : Item)
# Something came into the bag from outside it (caught, bought, crafted...).
signal gained(item : Item, amount : int)

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
		gained.emit(item, item.amount)
	if slot == catchSlot or slot < 0:
		needs_room.emit()
	return slot

# The slots a stack of this kind can go into: its own stacks first, then the
# backpack and the hotbar. The catch and trash slots are left out.
func stack_slots(kind : Item) -> Array[int]:
	var slots : Array[int] = []
	for slot in catchSlot:
		if items[slot] and items[slot].same_kind(kind) and items[slot].amount < kind.maxStack:
			slots.append(slot)
	return slots

# How many of this kind still fit.
func room_for(kind : Item) -> int:
	var room : int = 0
	for slot in stack_slots(kind):
		room += kind.maxStack - items[slot].amount
	for slot in catchSlot:
		if items[slot] == null:
			room += kind.maxStack
	return room

# Adds this many of the kind, topping up its stacks before taking new slots.
# Returns how many didn't fit.
func give(kind : Item, number : int = 1) -> int:
	kind = kind.original()
	var left : int = number
	for slot in stack_slots(kind):
		var moved : int = mini(left, kind.maxStack - items[slot].amount)
		items[slot].amount += moved
		left -= moved
	while left > 0:
		var slot : int = first_free()
		if slot < 0:
			break
		var stack : Item = kind.unique()
		stack.amount = mini(left, kind.maxStack) if kind.stacks() else 1
		items[slot] = stack
		left -= stack.amount
	emit_changed()
	if number - left > 0:
		gained.emit(kind, number - left)
	return left

# How many items pass the test, counting whole stacks.
func count_where(test : Callable) -> int:
	var total : int = 0
	for slot in trashSlot:
		if items[slot] and test.call(items[slot]):
			total += items[slot].amount
	return total

func count(kind : Item) -> int:
	return count_where(func(item : Item) -> bool: return item.same_kind(kind))

# Takes this many items that pass the test, the catch slot and the backpack's
# last slots first. Takes nothing when there aren't enough.
func take_where(test : Callable, amount : int) -> Array[Item]:
	var taken : Array[Item] = []
	if count_where(test) < amount:
		return taken
	var order : Array[int] = [catchSlot]
	for slot in range(catchSlot - 1, -1, -1):
		order.append(slot)
	var left : int = amount
	for slot in order:
		var item : Item = items[slot]
		if left <= 0:
			break
		if not item or not test.call(item):
			continue
		if item.amount > left:
			item.amount -= left
			taken.append(item)
			left = 0
		else:
			left -= item.amount
			items[slot] = null
			taken.append(item)
	emit_changed()
	return taken

func take(kind : Item, amount : int = 1) -> bool:
	return not take_where(func(item : Item) -> bool: return item.same_kind(kind), amount).is_empty()

# Takes out the item in this slot, or one from its stack.
func take_one(slot : int) -> Item:
	var item : Item = get_item(slot)
	if not item:
		return null
	if item.amount > 1:
		item.amount -= 1
		var single : Item = item.original().unique()
		single.amount = 1
		emit_changed()
		return single
	items[slot] = null
	emit_changed()
	return item

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
	if moving.stacks() and target.same_kind(moving) and target.amount < target.maxStack:
		return true
	if from == catchSlot:
		return false
	return from != trashSlot or target.discardable

# Moving into the trash throws the item away for good. Dropping a stack on one
# of its kind tops that one up.
func move(from : int, to : int) -> void:
	if not can_move(from, to):
		return
	if to == trashSlot:
		var thrown : Item = items[from]
		items[from] = null
		items[trashSlot] = null
		emit_changed()
		trashed.emit(thrown)
		return
	var target : Item = items[to]
	if target and items[from].stacks() and target.same_kind(items[from]):
		var moved : int = mini(items[from].amount, target.maxStack - target.amount)
		target.amount += moved
		items[from].amount -= moved
		if items[from].amount <= 0:
			items[from] = null
		emit_changed()
		return
	items[to] = items[from]
	items[from] = target
	emit_changed()

# A bigger (or smaller) backpack. The catch and trash slots move to the end.
func resize_backpack(slots : int) -> void:
	var hotbar : Array[Item] = items.slice(0, hotbarSize)
	var pack : Array[Item] = items.slice(hotbarSize, catchSlot)
	var caught : Item = items[catchSlot]
	var thrown : Item = items[trashSlot]
	backpackSize = slots
	pack.resize(slots)
	items.clear()
	items.append_array(hotbar)
	items.append_array(pack)
	items.append(caught)
	items.append(thrown)
	emit_changed()
