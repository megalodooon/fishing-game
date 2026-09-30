extends Resource
class_name Biome

# An ocean's fish, in the order the journal shows them. Fishing spots in the
# ocean using this biome draw their catches from the same list.

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
# The part of the world it's in, for the journal's bookmarks (see JournalUI.REGIONS).
@export var region : String = ""
@export var fish : Array[FishData] = []
# Catches from here go on this journal page instead of one of their own, so
# several fish pools (like the village shore and its well) share one page.
@export var page : Biome
# Sea creatures that can bite here instead of a fish.
@export var creatures : Array[SeaCreature] = []
# 0 near home up to 4 in the deep: better treasure, more skill XP.
@export_range(0, 4) var tier : int = 0
# How often junk bites instead of a fish, 0 to 1.
@export_range(0.0, 1.0, 0.01) var junkChance : float = 0.04
@export var junk : Array[Item] = []
# What grows or washes up on this island's ground, gathered by walking over it
# (see ForageNode). New spots every day.
@export var forage : Array[Item] = []
@export var foragePerRoom : int = 3
#------------------------#


func journal_page() -> Biome:
	return page if page else self
