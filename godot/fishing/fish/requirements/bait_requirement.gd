extends FishRequirement
class_name BaitRequirement

# Only bites with this bait on the rod.

#------------------------#
@export var bait : Bait
#------------------------#


func met(context : FishingContext) -> bool:
	return bait == null or context.has_bait(bait)

func describe() -> String:
	return "Needs %s" % (bait.displayName if bait else "bait")
