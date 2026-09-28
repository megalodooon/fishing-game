@tool
extends Node2D
class_name HeldItem


#------------------------#
@export_range(0.0, 1.0) var handAimWeight : float = 1.0
@export_range(0.0, 1.0) var aimFollow : float = 1.0
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var tilt : float = 0.0
@export var iconSprite : Sprite2D

var holder : Player
var item : Item
var appear : float = 1.0
var angularVelocity : float = 0.0
var iconOffset : Vector2
#------------------------#


func _ready() -> void:
	if iconSprite:
		iconOffset = iconSprite.position
		if item:
			iconSprite.texture = item.icon
		if holder:
			set_icon_scale(holder.heldItemScale)

func set_icon_scale(amount : float) -> void:
	if iconSprite:
		iconSprite.scale = Vector2.ONE * amount
		iconSprite.position = iconOffset * amount

func rest_angle(aim : float) -> float:
	return lerpf(-PI / 2.0, aim, aimFollow) + tilt

# Tooltip lines as label and value pairs. Runs on an instance that was never
# added to the tree.
func stats() -> PackedStringArray:
	return PackedStringArray()
