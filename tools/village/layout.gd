extends RefCounted

# Where everything in Bramblewick goes, shared by the land painter
# (tools/placeholder_art/make.gd, art_town) and the scene builder
# (tools/village/build_village.gd). Coordinates are island pixels, the top
# left of the island at 0,0; the island is ROOMS rooms of 192x108.

const ROOMS : Vector2i = Vector2i(4, 4)
const ROOM : Vector2 = Vector2(192.0, 108.0)
const SIZE : Vector2 = Vector2(768.0, 432.0)

# The coast: an oval with these middle and radii, roughened, plus headlands.
const CENTER : Vector2 = Vector2(384.0, 204.0)
const RADII : Vector2 = Vector2(356.0, 184.0)
const HEADLANDS : Array = [[Vector2(722.0, 210.0), 44.0], [Vector2(60.0, 300.0), 40.0], [Vector2(384.0, 372.0), 26.0]]
const SAND : float = 8.0

# Dirt paths as polylines, and their width.
const PATH_WIDTH : float = 10.0
const PATHS : Array = [
	[Vector2(384.0, 388.0), Vector2(384.0, 256.0)],
	[Vector2(384.0, 168.0), Vector2(384.0, 122.0)],
	[Vector2(92.0, 122.0), Vector2(690.0, 122.0)],
	[Vector2(90.0, 266.0), Vector2(338.0, 236.0)],
	[Vector2(430.0, 236.0), Vector2(700.0, 266.0)],
	[Vector2(150.0, 122.0), Vector2(150.0, 112.0)],
	[Vector2(240.0, 258.0), Vector2(240.0, 330.0)],
	[Vector2(600.0, 262.0), Vector2(612.0, 340.0)],
	[Vector2(520.0, 122.0), Vector2(520.0, 112.0)],
	[Vector2(640.0, 122.0), Vector2(640.0, 112.0)],
	[Vector2(690.0, 122.0), Vector2(720.0, 200.0)],
]
# The town square: stones in a circle.
const PLAZA : Vector2 = Vector2(384.0, 212.0)
const PLAZA_RADIUS : float = 46.0
# Wooden piers: rects (walkable).
const PIERS : Array = [Rect2(375.0, 384.0, 18.0, 44.0), Rect2(608.0, 338.0, 70.0, 12.0)]
# Where the player steps off the boat.
const ARRIVAL : Vector2 = Vector2(384.0, 416.0)

# Where every node from the old village goes (its foot point), by the path
# it had under its room. Nodes going inside a building are in INSIDE.
const SPOTS : Dictionary = {
	"Pier/Sign": Vector2(404.0, 378.0),
	"Pier/Lamp": Vector2(366.0, 380.0),
	"Pier/Coin": Vector2(340.0, 364.0),
	"Pier/Npc_Rex": Vector2(414.0, 360.0),
	"Pier/Pearl1": Vector2(300.0, 372.0),
	"Pier/Trap": Vector2(250.0, 360.0),
	"Pier/ForageTidePool1": Vector2(130.0, 320.0),
	"Square/Aquarium": Vector2(520.0, 110.0),
	"Square/VendingMachine": Vector2(352.0, 272.0),
	"Square/BaitCrafter": Vector2(306.0, 252.0),
	"Square/Well": Vector2(300.0, 186.0),
	"Square/NoticeBoard": Vector2(352.0, 190.0),
	"Square/BallotBox": Vector2(418.0, 190.0),
	"Square/Lamp": Vector2(420.0, 252.0),
	"Square/TackleStall": Vector2(206.0, 302.0),
	"Square/Goods": Vector2(276.0, 302.0),
	"Square/Npc_Vera": Vector2(440.0, 230.0),
	"Square/Fountain": Vector2(384.0, 222.0),
	"Square/Pearl2": Vector2(110.0, 100.0),
	"Home/House": Vector2(150.0, 110.0),
	"Home/CrewBoard": Vector2(196.0, 114.0),
	"Home/Lamp": Vector2(120.0, 118.0),
	"Home/Bottle": Vector2(450.0, 380.0),
	"Home/Npc_Hale": Vector2(276.0, 134.0),
	"Home/TournamentHall": Vector2(474.0, 186.0),
	"Home/Stage": Vector2(384.0, 152.0),
	"Home/Pearl3": Vector2(30.0, 236.0),
	"Home/Pearl4": Vector2(700.0, 150.0),
	"Home/ForageBerryBush2": Vector2(92.0, 150.0),
	"Lane/TackleShop": Vector2(180.0, 252.0),
	"Lane/Boatyard": Vector2(580.0, 334.0),
	"Lane/Smokehouse": Vector2(130.0, 314.0),
	"Lane/PetShop": Vector2(116.0, 254.0),
	"Lane/Stash": Vector2(40.0, 196.0),
	"Lane/Npc_Marina": Vector2(626.0, 330.0),
	"Lane/Npc_Bo": Vector2(150.0, 272.0),
	"Lane/MarketHall": Vector2(252.0, 250.0),
	"Lane/Bazaar": Vector2(312.0, 302.0),
	"Lane/Pearl5": Vector2(180.0, 352.0),
	"Lane/Pearl6": Vector2(560.0, 60.0),
	"Lane/Trap": Vector2(670.0, 290.0),
	"Lane/ForageDriftwood3": Vector2(520.0, 372.0),
	"Harbor/Bank": Vector2(570.0, 252.0),
	"Harbor/TrophyLodge": Vector2(650.0, 252.0),
	"Harbor/HuntBoard": Vector2(530.0, 312.0),
	"Harbor/TideAltar": Vector2(730.0, 214.0),
	"Harbor/Npc_Odette": Vector2(664.0, 276.0),
}

# Buildings with an inside: the old building node (its art and collision
# stay outside), the interior's name, and the nodes that move in with where
# they stand inside (a 192x108 room).
const INSIDE : Dictionary = {
	"House": {"building": "Home/House", "art": "", "floor": "wood", "moves": {"Home/House/Bed": Vector2(56.0, 48.0), "Home/Workbench": Vector2(140.0, 48.0)}},
	"MarketHall": {"building": "Lane/MarketHall", "art": "", "floor": "stone", "moves": {"Square/Fishmonger/Door": Vector2(62.0, 46.0), "Square/Npc_Gus": Vector2(62.0, 40.0), "Lane/MarketHall/Door": Vector2(132.0, 46.0)}},
	"Bank": {"building": "Harbor/Bank", "art": "", "floor": "marble", "moves": {"Harbor/Bank/Counter": Vector2(96.0, 46.0), "Harbor/Npc_Barnaby": Vector2(96.0, 40.0)}},
	"HarborOffice": {"building": "", "art": "harbor_office", "floor": "wood", "at": Vector2(500.0, 252.0), "moves": {"Pier/Npc_Pip": Vector2(96.0, 42.0)}},
	"Museum": {"building": "Square/Aquarium", "art": "", "floor": "marble", "moves": {"Square/Aquarium/Door": Vector2(56.0, 44.0), "Square/Npc_Nora": Vector2(136.0, 42.0)}},
	"Tavern": {"building": "", "art": "tavern", "floor": "wood", "at": Vector2(640.0, 110.0), "moves": {}},
}
# Nodes of the old village that aren't needed any more.
const DROP : PackedStringArray = ["Square/Fishmonger"]
# Little houses the villagers go home to at night (just outsides).
const COTTAGES : Array = [Vector2(250.0, 110.0), Vector2(318.0, 110.0), Vector2(704.0, 160.0), Vector2(70.0, 210.0)]
# Lamps along the streets, besides the old ones.
const LAMPS : Array = [Vector2(348.0, 252.0), Vector2(220.0, 128.0), Vector2(450.0, 128.0), Vector2(580.0, 128.0), Vector2(300.0, 270.0), Vector2(470.0, 270.0), Vector2(392.0, 330.0)]
