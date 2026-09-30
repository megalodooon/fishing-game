extends Resource
class_name Wallet

# The player's coins. Spent on unlocking places for now.

#------------------------#
@export var coins : int = 0
#------------------------#


func can_afford(amount : int) -> bool:
	return coins >= amount

func spend(amount : int) -> bool:
	if not can_afford(amount):
		return false
	coins -= amount
	emit_changed()
	return true

func add(amount : int) -> void:
	coins += amount
	emit_changed()
