extends Resource
class_name Biome

# An ocean's fish, in the order the journal shows them. Fishing spots in the
# ocean using this biome draw their catches from the same list.

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var fish : Array[FishData] = []
#------------------------#
