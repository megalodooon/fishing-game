extends Resource
class_name FishRequirement

# Something that has to be true before a fish bites. Subclasses check one
# thing each and say what it is for the journal and hints.


func met(_context : FishingContext) -> bool:
	return true

func describe() -> String:
	return ""
