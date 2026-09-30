@tool
extends Interactable
class_name Counter

# An Interactable that opens the counter menu: a list to pick from (things to
# buy, sell, craft or give) with the picked row's details beside it.
# Subclasses fill in the rows, the details and what picking a row does.

#------------------------#
@export var title : String = ""

# Drawn in the corner of the menu, like the shopkeeper.
@export var portrait : Texture2D
# The menu's look. Empty uses the kind of counter's own (see theme_path).
@export var skin : MenuSkin

# Whether the last choice worked, for the color of its message.
var lastGood : bool = true
# The open tab, when there are tabs.
var tab : int = 0
#------------------------#


# Tabs across the top of the menu, like Buy and Sell. Empty for none.
func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray()

func look() -> MenuSkin:
	if skin:
		return skin
	var path : String = "res://ui/skins/themes/%s.tres" % theme_name()
	return load(path) as MenuSkin if ResourceLoader.exists(path) else MenuSkin.default_skin()

# The kind of counter's look, a theme file name in ui/skins/themes.
func theme_name() -> String:
	return "logbook"

# Whether the list gets a search box. Short lists read better without.
func searchable() -> bool:
	return true

# Whether the header shows the coins.
func shows_coins() -> bool:
	return true

# How many of an item the player has, in the bag or the tacklebox.
static func count_owned(player : Player, item : Item) -> int:
	if item is Tackle and player.tacklebox:
		return player.tacklebox.count(item)
	return player.inventory.count(item)


func interact(player : Player) -> void:
	var menu : CounterUI = CounterUI.find(get_tree())
	if menu:
		menu.open_counter(self, player)

# Rows in the ListMenu format: value, text, icon, tint, detail, dim, marked...
func rows(_player : Player) -> Array[Dictionary]:
	return []

# Rows kept above the list, like a switch between buying and selling.
func pinned_rows(_player : Player) -> Array[Dictionary]:
	return []

# What the details pane shows for a row: title, color, icon, tint, text (a
# paragraph), lines (label and value pairs), action (what clicking does) and
# enabled (whether it can).
func info(_player : Player, _value : Variant) -> Dictionary:
	return {}

# A row was clicked. Returns a short message for the status line, or nothing.
func choose(_player : Player, _value : Variant) -> String:
	return ""

# A line under the title, like when the stock changes.
func subtitle(_player : Player) -> String:
	return ""

func ok(text : String) -> String:
	lastGood = true
	return text

func fail(text : String) -> String:
	lastGood = false
	return text

func opened(_player : Player) -> void:
	pass

# Sends a bought item where it belongs: parts and bait into the tacklebox,
# everything else into the inventory. Returns false when it doesn't fit.
static func deliver(player : Player, item : Item, amount : int) -> bool:
	if item is Tackle and player.tacklebox:
		player.tacklebox.add(item, amount)
		return true
	if player.inventory.room_for(item) < amount:
		return false
	player.inventory.give(item, amount)
	return true

# An item's tooltip lines as detail rows.
static func item_lines(item : Item) -> Array:
	var list : Array = []
	var pairs : PackedStringArray = item.details()
	for i in range(0, pairs.size() - 1, 2):
		list.append([pairs[i], pairs[i + 1]])
	return list

static func item_info(item : Item) -> Dictionary:
	var tint : Color = (item as Tackle).icon_tint() if item is Tackle else Color.WHITE
	var lines : Array = item_lines(item)
	return {"title": item.displayName, "color": item.title_color(), "icon": item.icon, "tint": tint, "text": item.description, "tag": item.tag(), "lines": lines}

static func fits(player : Player, item : Item, amount : int) -> bool:
	return (item is Tackle and player.tacklebox != null) or player.inventory.room_for(item) >= amount
