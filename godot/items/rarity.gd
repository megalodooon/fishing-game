extends Resource
class_name Rarity


#------------------------#
@export var displayName : String = ""
@export var color : Color = Color.WHITE
# Only fish use these: how often a rarity bites and how hard it is to catch.
@export_range(0.0, 100.0, 0.01, "or_greater") var chance : float = 1.0
@export_range(0.0, 1.0) var difficulty : float = 0.0
#------------------------#
