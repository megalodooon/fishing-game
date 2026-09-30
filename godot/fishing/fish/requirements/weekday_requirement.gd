extends FishRequirement
class_name WeekdayRequirement

# Only bites on these days of the week.

#------------------------#
@export var days : Array[DayNightCycle.Weekday] = []
#------------------------#


func met(context : FishingContext) -> bool:
	return context.weekday < 0 or days.has(context.weekday)

func describe() -> String:
	var list : Array[int] = []
	list.assign(days)
	return "Only on " + DayNightCycle.weekday_text(list)
