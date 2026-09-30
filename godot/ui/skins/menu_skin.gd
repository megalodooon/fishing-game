@tool
extends Resource
class_name MenuSkin

# How a menu looks: the style boxes it draws its parts with and its text
# colors. Every look is a .tres in ui/skins/themes, and every style box a
# .tres in ui/skins over a PNG in ui/skins/art, so menus can be restyled or
# repainted without touching code. Shops use wood, quest boards paper, the
# journal leather and pages, the tacklebox tin...

#------------------------#
# The whole panel.
@export var frame : StyleBox
# Sunk areas, like the list and the details card.
@export var well : StyleBox
# Raised tiles, like cards in a grid.
@export var card : StyleBox
# The title ribbon. Empty draws the title straight on the frame.
@export var ribbon : StyleBox

@export_group("Buttons")
@export var button : StyleBox
@export var buttonHover : StyleBox
@export var buttonDown : StyleBox
@export var buttonOff : StyleBox
@export var tab : StyleBox
@export var tabHover : StyleBox
@export var tabOn : StyleBox

@export_group("Text")
# Dark text on a light skin, like paper. Rarity colors get darkened to read.
@export var light : bool = false
@export var text : Color = Color(0.94, 0.97, 1.0)
@export var dim : Color = Color(0.58, 0.67, 0.78)
@export var title : Color = Color(1.0, 0.9, 0.4)
# Prices and highlights.
@export var accent : Color = Color(1.0, 0.9, 0.4)
@export var good : Color = Color(0.56, 0.93, 0.44)
@export var bad : Color = Color(0.95, 0.38, 0.34)
@export var buttonText : Color = Color(0.94, 0.97, 1.0)
# Drawn one pixel around text, clear for none.
@export var outline : Color = Color(0.0, 0.0, 0.0, 0.0)

@export_group("Rows")
@export var hover : Color = Color(0.55, 0.68, 0.82, 0.22)
@export var marked : Color = Color(0.56, 0.93, 0.44)
@export var shade : Color = Color(1.0, 1.0, 1.0, 0.04)
@export var line : Color = Color(0.04, 0.07, 0.13, 0.8)
#------------------------#


# A color picked for dark skins (like a rarity), made readable on this one.
func readable(color : Color) -> Color:
	if not light:
		return color
	if color.get_luminance() > 0.8:
		return text
	return Color(color.darkened(0.45), color.a)

static var fallback : MenuSkin

static func default_skin() -> MenuSkin:
	if not fallback:
		fallback = load("res://ui/skins/themes/logbook.tres") as MenuSkin
	return fallback
