extends Item
class_name CrewContract

# A signed contract: take it to the crew board to hire its crew member.

#------------------------#
@export var crew : CrewMember
#------------------------#


func default_type() -> String:
	return "Crew Contract"

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	if crew:
		lines.append_array(["Gathers", crew.product.displayName if crew.product else "?", "Speed", "1 per %s" % Crew.hours_text(crew.interval(1, 0.0)), "Hire at", "the crew board"])
	lines.append_array(super())
	return lines
