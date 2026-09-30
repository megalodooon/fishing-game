extends FishRequirement
class_name CastRequirement

# Only bites when the cast landed this close to the middle of the spot.

const NAMES : PackedStringArray = ["miss", "bad", "okay", "good", "better", "perfect"]

#------------------------#
@export_range(1, 5) var minScore : int = 5
#------------------------#


func met(context : FishingContext) -> bool:
	return context.score >= minScore

func describe() -> String:
	return "A %s cast%s" % [NAMES[minScore], "" if minScore >= NAMES.size() - 1 else " or better"]
