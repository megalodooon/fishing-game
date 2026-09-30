extends FishRequirement
class_name WeatherRequirement

# Only bites in this weather.

#------------------------#
@export_enum("Clear", "Rain", "Fog") var weather : int = 1
#------------------------#


func met(context : FishingContext) -> bool:
	return context.weather == weather

func describe() -> String:
	return "Only in %s" % Weather.NAMES[weather].to_lower()
