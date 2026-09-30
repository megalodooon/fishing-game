extends FishRequirement
class_name SpotRequirement

# Only bites in the fishing spot with this id, like a hidden pool.

#------------------------#
@export var spotId : StringName = &""
@export var spotName : String = "a secret spot"
#------------------------#


func met(context : FishingContext) -> bool:
	return context.spot != null and context.spot.id == spotId

func describe() -> String:
	return "Only in %s" % spotName
