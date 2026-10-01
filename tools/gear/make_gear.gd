extends RefCounted

# Makes the hats and gear (items/equipment/*.tres) with placeholder icons
# (items/equipment/icons/*.png, 12x12, paint over them), and puts the ones
# sold in shops into their stock. Run through the harness:
#   godot --headless --path . res://dev/harness.tscn -- out tool_gear

const RARITY : Dictionary = {
	"common": "res://items/rarities/common.tres", "uncommon": "res://items/rarities/uncommon.tres",
	"rare": "res://items/rarities/rare.tres", "legendary": "res://items/rarities/legendary.tres",
}
# id, name, hat?, rarity, stats, unique, sell price, description, colors (main, trim)
const GEAR : Array = [
	["straw_hat", "Straw Hat", true, "common", {&"biteSpeed": 2.0}, &"", 30, "Keeps the sun off and the fish curious.", ["e6c26a", "a37a35"]],
	["fishers_cap", "Fisher's Cap", true, "common", {&"control": 4.0}, &"", 40, "Brim low, eyes on the line.", ["3d6a9e", "f0f0f0"]],
	["souwester", "Sou'wester", true, "uncommon", {&"luck": 2.0}, &"storm_fisher", 120, "The fish don't mind the rain. Now neither do you.", ["f2c832", "b08a1a"]],
	["nightcap", "Nightcap", true, "uncommon", {&"energyMax": 5.0}, &"night_owl", 110, "Wear it to bed, or instead of going to bed.", ["5b4fa8", "f0f0f0"]],
	["lantern_helm", "Lantern Helm", true, "rare", {&"seaCreature": 0.5}, &"lantern", 300, "A little light for the dark water. Things come to look.", ["7a6a5a", "ffd45a"]],
	["captains_tricorn", "Captain's Tricorn", true, "rare", {&"travelDiscount": 5.0}, &"captain", 350, "Folded by someone who knew the tides by heart.", ["2c2c38", "d9b44a"]],
	["divers_helmet", "Diver's Helmet", true, "rare", {&"treasure": 1.0}, &"diver", 320, "Brass, glass, and a smell of old seawater.", ["c88a3a", "9fd3ea"]],
	["crown_of_tides", "Crown of Tides", true, "legendary", {&"hearts": 1.0, &"damage": 10.0, &"luck": 5.0}, &"", 1200, "It hums when the tide turns.", ["45c8d8", "f2f2f2"]],
	["work_apron", "Work Apron", false, "common", {&"craftBonus": 3.0}, &"", 30, "Pockets for nails, pockets for bait, pockets for pockets.", ["a37a4f", "6e4f32"]],
	["oilskin_coat", "Oilskin Coat", false, "uncommon", {&"energyMax": 5.0}, &"oilskin", 140, "Waxed until rain just gives up.", ["e3b23a", "8a6a20"]],
	["fishing_vest", "Fishing Vest", false, "uncommon", {&"doubleCatch": 2.0, &"weight": 3.0}, &"", 150, "Twelve pockets and a lucky lure in one of them.", ["6a8a4a", "3e5a2a"]],
	["wader_overalls", "Wader Overalls", false, "uncommon", {&"forageBonus": 20.0}, &"", 120, "For wading out to the good rocks.", ["4a7a6a", "2a4a3a"]],
	["merchants_waistcoat", "Merchant's Waistcoat", false, "rare", {&"sellBonus": 4.0}, &"", 400, "Gus says it makes you look trustworthy. Gus is wrong but kind.", ["7a2a3a", "d9b44a"]],
	["sharkskin_jacket", "Sharkskin Jacket", false, "rare", {&"hearts": 1.0, &"damage": 10.0}, &"", 450, "Tough as the thing it came from.", ["6a7a8a", "3a4a5a"]],
	["night_watch_coat", "Night Watch Coat", false, "rare", {&"stayUp": 3.0, &"energyMax": 10.0}, &"", 380, "Warm enough for the long watches.", ["2a3a5a", "8a9ab0"]],
	["leviathan_mail", "Leviathan Mail", false, "legendary", {&"hearts": 2.0, &"damage": 25.0}, &"", 1500, "Scales the size of plates. Still warm.", ["2a6a6a", "8ae0d0"]],
]
# Shop, gear id, price, skill needed, level.
const SOLD : Array = [
	["general_store", "straw_hat", 150, &"", 0],
	["general_store", "work_apron", 180, &"", 0],
	["general_store", "fishers_cap", 260, &"fishing", 3],
	["tackle_shop", "souwester", 900, &"fishing", 5],
	["tackle_shop", "oilskin_coat", 1200, &"fishing", 6],
	["tackle_shop", "fishing_vest", 1600, &"fishing", 8],
	["sunday_rare", "nightcap", 1400, &"", 0],
	["sunday_rare", "divers_helmet", 3500, &"fishing", 12],
	["sunday_rare", "merchants_waistcoat", 4200, &"trading", 10],
	["general_store", "wader_overalls", 700, &"fishing", 4],
	["sunday_rare", "night_watch_coat", 2600, &"fishing", 10],
	["sunday_rare", "captains_tricorn", 5000, &"trading", 12],
]
# Gear only sea creatures drop: creature, gear id, chance.
const DROPPED : Array = [
	["phantom_squid", "lantern_helm", 0.04],
	["thunder_squid", "lantern_helm", 0.04],
	["reef_shark_brute", "sharkskin_jacket", 0.03],
	["great_white", "sharkskin_jacket", 0.05],
	["abyssal_angler", "crown_of_tides", 0.015],
	["bone_shark", "crown_of_tides", 0.015],
	["sea_dragon", "leviathan_mail", 0.02],
	["storm_kraken", "leviathan_mail", 0.02],
]


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://items/equipment/icons"))
	for row in GEAR:
		var path : String = "res://items/equipment/icons/%s.png" % row[0]
		if not FileAccess.file_exists(path):
			icon(row[2], Color(row[8][0]), Color(row[8][1])).save_png(ProjectSettings.globalize_path(path))
	for row in GEAR:
		var gear : Gear = Gear.new()
		gear.displayName = row[1]
		gear.slot = Gear.Slot.HAT if row[2] else Gear.Slot.GEAR
		gear.rarity = load(RARITY[row[3]])
		var stats : Dictionary[StringName, float] = {}
		for key in row[4]:
			stats[key] = row[4][key]
		gear.stats = stats
		gear.unique_effect = row[5]
		gear.sellPrice = row[6]
		gear.description = row[7]
		gear.icon = load("res://items/equipment/icons/%s.png" % row[0]) if ResourceLoader.exists("res://items/equipment/icons/%s.png" % row[0]) else null
		print("gear ", row[0], " ", ResourceSaver.save(gear, "res://items/equipment/%s.tres" % row[0]))
	for sale in SOLD:
		var stock_path : String = "res://world/village/shop/stock/%s.tres" % sale[0]
		var stock : Resource = load(stock_path)
		var item : Item = load("res://items/equipment/%s.tres" % sale[1])
		var offers : Array = stock.get("offers")
		var known : bool = false
		for offer in offers:
			if offer and offer.item and offer.item.resource_path == item.resource_path:
				known = true
		if known:
			continue
		var offer : ShopOffer = ShopOffer.new()
		offer.item = item
		offer.price = sale[2]
		offer.requiredSkill = sale[3]
		offer.requiredLevel = sale[4]
		offers.append(offer)
		print("sold ", sale[1], " at ", sale[0], " ", ResourceSaver.save(stock, stock_path))

	for row in DROPPED:
		var path : String = "res://fishing/creatures/%s.tres" % row[0]
		var creature : SeaCreature = load(path)
		var item : Item = load("res://items/equipment/%s.tres" % row[1])
		if creature.drops.has(item):
			continue
		creature.drops.append(item)
		creature.dropChances.append(row[2])
		creature.dropAmounts.append(Vector2i(1, 1))
		print("drop ", row[1], " from ", row[0], " ", ResourceSaver.save(creature, path))

# A hat (a crown and a brim) or a coat (a body with sleeves), in two colors.
static func icon(hat : bool, main : Color, trim : Color) -> Image:
	var image : Image = Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rows : PackedStringArray
	if hat:
		rows = ["............", "....MMMM....", "...MMMMMM...", "...MMMMMM...", "...TTTTTT...", ".MMMMMMMMMM.", "MMMMMMMMMMMM", "............", "............", "............", "............", "............"]
	else:
		rows = ["............", "...MM..MM...", "..MMMTTMMM..", ".MMMMTTMMMM.", ".MM.MTTM.MM.", ".MM.MTTM.MM.", ".MM.MTTM.MM.", "....MTTM....", "....MTTM....", "....MMMM....", "............", "............"]
	for y in 12:
		for x in 12:
			match rows[y][x]:
				"M":
					image.set_pixel(x, y, main)
				"T":
					image.set_pixel(x, y, trim)
	# A dark edge around it.
	var copy : Image = image.duplicate()
	for y in 12:
		for x in 12:
			if copy.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p : Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 12 and p.y < 12 and copy.get_pixelv(p).a > 0.0:
					image.set_pixel(x, y, Color(0.09, 0.08, 0.1))
					break
	return image
