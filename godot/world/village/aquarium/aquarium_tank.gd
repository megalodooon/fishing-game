extends Resource
class_name AquariumTank

# One tank of the village aquarium, like a Stardew bundle: give it the fish it
# asks for and it's restored, which opens a building (any Building that names
# this tank) and pays out a reward.

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var icon : Texture2D
@export var fish : Array[FishData] = []
# How many of the fish above it takes. 0 means all of them.
@export var needs : int = 0
@export var rewardCoins : int = 0
# What restoring it opens, for the text.
@export var opens : String = ""
# Only shown once this progress flag is set, like a new aquarium wing.
@export var requiredFlag : String = ""
#------------------------#


func needed() -> int:
	return fish.size() if needs <= 0 else mini(needs, fish.size())
