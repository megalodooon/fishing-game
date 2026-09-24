extends Node2D
class_name Boat


#------------------------#
@export var visuals : Node2D

var upgrades : Array[BoatUpgrade] = []
#------------------------#


func upgrade(upgradeScene : PackedScene) -> BoatUpgrade:
	var newUpgrade : BoatUpgrade = upgradeScene.instantiate()
	newUpgrade.boat = self
	visuals.add_child(newUpgrade)
	upgrades.append(newUpgrade)
	newUpgrade.apply()
	return newUpgrade

func remove_upgrade(oldUpgrade : BoatUpgrade) -> void:
	upgrades.erase(oldUpgrade)
	oldUpgrade.remove()
	oldUpgrade.queue_free()
