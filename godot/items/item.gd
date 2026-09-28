extends Resource
class_name Item


#------------------------#
@export var displayName : String = ""
@export var icon : Texture2D
@export var rarity : Rarity
@export var heldScene : PackedScene
@export var discardable : bool = true
# Input action fired when the item is used while held (clicked with it out).
@export var useAction : StringName = &""
# Extra tooltip line, like how to use the item.
@export var hint : String = ""
#------------------------#


# The copy that ends up in an inventory. Items that change per copy override it.
func unique() -> Item:
	return self

# How much bigger than usual it looks in the hand.
func held_scale() -> float:
	return 1.0

func title_color() -> Color:
	return rarity.color if rarity else Color.WHITE

# Tooltip lines as label and value pairs.
func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Rarity", rarity.displayName] if rarity else [])
	if heldScene:
		var held : HeldItem = heldScene.instantiate() as HeldItem
		held.item = self
		lines.append_array(held.stats())
		held.free()
	if not hint.is_empty():
		lines.append_array([hint, ""])
	return lines
