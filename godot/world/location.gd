extends Resource
class_name Location

# A place on the sea chart: an ocean to fish in or an island to dock at.
# Sailing there costs energy and time by distance on the chart, unless it's
# free. Places that don't start unlocked open up for coins and/or after
# finding enough fish on a journal page (quests can join Atlas.missing later).

enum Kind { OCEAN, ISLAND }

#------------------------#
@export var displayName : String = ""
@export_multiline var description : String = ""
@export var kind : Kind = Kind.OCEAN
# Loaded on arrival. Islands keep the boat still at their pier. A path, not a
# PackedScene, so quests in the scene can point back at this place.
@export_file("*.tscn") var scene : String = ""
# Where it sits on the sea chart, in chart pixels.
@export var mapPosition : Vector2 = Vector2.ZERO
@export var mapIcon : Texture2D
# Colors the chart's water around it, strongest right here. Alpha is how
# strongly, 0 leaves the sea as it is.
@export var chartTint : Color = Color(0.0, 0.0, 0.0, 0.0)
# The fish found here, for tournaments and hints. Oceans and island shores.
@export var biome : Biome
# Getting here costs no energy, only time.
@export var freeTravel : bool = false
# Trips to or from here take this share of the usual time and energy.
@export_range(0.05, 1.0, 0.05) var travelScale : float = 1.0
# How likely clear, rain and fog are here. Empty uses the Weather node's odds.
@export var weatherChances : PackedFloat32Array = PackedFloat32Array()

@export_group("Unlock")
@export var startsUnlocked : bool = true
@export var coinCost : int = 0
# A journal page that needs fish found on it first.
@export var requiredBiome : Biome
# How many of that page's fish. 0 means the whole page.
@export var requiredFish : int = 0
# A progress flag that has to be set first, like a quest handed in.
@export var requiredFlag : String = ""
# What the chart says about that flag, like "Finish Reef Rumors".
@export var requiredText : String = ""
# The boat's hull has to be at least this tier (see BoatParts) to sail here.
@export var requiredHull : int = 0
# A skill level needed first, like Sailing 10 for the far north.
@export var requiredSkill : StringName = &""
@export var requiredLevel : int = 0
# A tournament league that has to be won first (see Unlocks.LEAGUES).
@export var requiredLeague : int = 0
#------------------------#


func is_island() -> bool:
	return kind == Kind.ISLAND

func kind_name() -> String:
	return "Island" if is_island() else "Ocean"
