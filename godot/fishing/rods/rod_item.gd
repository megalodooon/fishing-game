extends Item
class_name RodItem


#------------------------#
# One entry per tackle slot. Repeat a kind for extra slots of it.
@export var slots : Array[Tackle.Kind] = [Tackle.Kind.BOBBER, Tackle.Kind.LINE, Tackle.Kind.HOOK]
# What sits in each slot, in the same order. Empty slots use the rod's defaults.
@export var tackle : Array[Tackle] = []
# Stats the rod itself adds on top of its parts. Use the Tech kind.
@export var builtIn : Tackle
# The held rod is tinted this color.
@export var rodTint : Color = Color.WHITE
# Set at the anvil (see Reforge): a word in front of the name and more stats.
@export var reforge : Reforge
# Put on at the enchanting altar: enchantment id -> level (see Enchanting).
@export var enchants : Dictionary = {}
#------------------------#


func unique() -> Item:
	var copy : RodItem = duplicate()
	copy.base = original()
	copy.tackle = tackle.duplicate()
	copy.tackle.resize(slots.size())
	copy.enchants = enchants.duplicate()
	return copy

# Puts a reforge on this rod (a copy in the bag, never the original).
func apply_reforge(which : Reforge) -> void:
	reforge = which
	displayName = ("%s %s" % [which.prefix, original().displayName]) if which else original().displayName
	emit_changed()

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

func default_type() -> String:
	return "Fishing Rod"

func details() -> PackedStringArray:
	var lines : PackedStringArray = super()
	var magic : PackedStringArray = Enchanting.lines(self)
	for i in range(magic.size() - 1, -1, -1):
		lines.insert(0, magic[i])
	if reforge:
		lines.insert(0, reforge.prefix)
		lines.insert(0, "Reforge")
	return lines
