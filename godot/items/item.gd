extends Resource
class_name Item

# Anything that goes in the bag or the tacklebox. Every item has one shop price
# (shop_price), the same in every shop that stocks it, so prices read as a
# tier: better things cost more, alike things cost the same.

# What a shop asks for one, by rarity, when buyPrice isn't set and the item
# doesn't sell for anything.
const TIER_PRICES : Dictionary = {"Common": 150, "Uncommon": 600, "Rare": 2000, "Legendary": 7500, "Trophy": 25000}
# Shops ask this much more than they pay.
const MARKUP : float = 3.0


#------------------------#
@export var displayName : String = ""
# What kind of thing it is, shown in small text under the name, like "Crop"
# or "Upgrade Material". Empty lets the item's class say.
@export var category : String = ""
@export var icon : Texture2D
@export var rarity : Rarity
@export_multiline var description : String = ""
@export var heldScene : PackedScene
@export var discardable : bool = true
# Input action fired when the item is used while held (clicked with it out).
@export var useAction : StringName = &""
# Extra tooltip line, like how to use the item.
@export var hint : String = ""
# Copies of it share one inventory slot, up to this many. 1 means it doesn't stack.
@export_range(1, 999) var maxStack : int = 1
# What a shop pays for one. 0 means shops don't buy it.
@export var sellPrice : int = 0
# What a shop asks for one. 0 works it out: MARKUP times the sell price, or
# the rarity's TIER_PRICES.
@export var buyPrice : int = 0
# Where to get it, for the recipe book and tooltips, on top of what the game
# works out itself (see Sources). Like "Tackle Shop".
@export var foundAt : String = ""

# How many this stack holds.
@export_storage var amount : int = 1
# The resource a stack was copied from, so stacks can tell they're the same kind.
var base : Item
#------------------------#


# The copy that ends up in an inventory. Items that change per copy override it.
func unique() -> Item:
	if maxStack <= 1:
		return self
	var copy : Item = duplicate()
	copy.base = original()
	copy.amount = amount
	return copy

# The resource every stack of this item came from.
func original() -> Item:
	return base if base else self

func same_kind(other : Item) -> bool:
	return other != null and other.original() == original()

func stacks() -> bool:
	return maxStack > 1

# What a shop pays for this, per item.
func price() -> int:
	return sellPrice

# What a shop asks for one.
func shop_price() -> int:
	if buyPrice > 0:
		return buyPrice
	if sellPrice > 0:
		return roundi(sellPrice * MARKUP)
	return TIER_PRICES.get(rarity.displayName if rarity else "Common", 150)

# The small line under the name.
func type_name() -> String:
	return category if not category.is_empty() else default_type()

func default_type() -> String:
	return "Tool" if not useAction.is_empty() else "Item"

# The rarity and the type together, like "Rare Bait".
func tag() -> String:
	return ("%s %s" % [rarity.displayName, type_name()]) if rarity else type_name()

# Clicking with it held. Returns whether it did something, like eating a snack.
func use(_player : Player) -> bool:
	return false

# How much bigger than usual it looks in the hand.
func held_scale() -> float:
	return 1.0

func title_color() -> Color:
	return rarity.color if rarity else Color.WHITE

# Tooltip lines as label and value pairs.
func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	if heldScene:
		var held : HeldItem = heldScene.instantiate() as HeldItem
		held.item = self
		lines.append_array(held.stats())
		held.free()
	if stacks() and amount > 1:
		lines.append_array(["Amount", "%d" % amount])
	if price() > 0:
		lines.append_array(["Sells for", "$%d" % price()])
	if not hint.is_empty():
		lines.append_array([hint, ""])
	return lines
