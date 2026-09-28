extends Resource
class_name Energy

# How much the player can still do today. Casting uses it up, sleeping
# refills it (less after a late night) and snacks will top it up.

#------------------------#
@export var maximum : float = 100.0
@export var value : float = 100.0
#------------------------#


func fraction() -> float:
	return clampf(value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0

func is_empty() -> bool:
	return value <= 0.0

func spend(amount : float) -> void:
	value = maxf(value - amount, 0.0)
	emit_changed()

func add(amount : float) -> void:
	value = clampf(value + amount, 0.0, maximum)
	emit_changed()

# Sets it to this share of the maximum, like after a night's sleep.
func refill(share : float) -> void:
	value = maximum * clampf(share, 0.0, 1.0)
	emit_changed()
