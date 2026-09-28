@tool
extends Node2D
class_name HeldItem


#------------------------#
@export_range(0.0, 1.0) var handAimWeight : float = 1.0
@export_range(0.0, 1.0) var aimFollow : float = 1.0
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var tilt : float = 0.0
@export var iconSprite : Sprite2D
# Held up over the head with both hands, like a fish that was just caught.
@export var overhead : bool = false

var holder : Player
var item : Item
var appear : float = 1.0
var angularVelocity : float = 0.0
var iconOffset : Vector2
# The middle of the icon's visible pixels, from the middle of its canvas.
var visibleCenter : Vector2 = Vector2.ZERO
var visibleSize : Vector2 = Vector2.ZERO
#------------------------#


func _ready() -> void:
	if iconSprite:
		iconOffset = iconSprite.position
		if item:
			iconSprite.texture = item.icon
			measure_icon()
		if holder:
			set_icon_scale(holder.heldItemScale)

func measure_icon() -> void:
	var image : Image = iconSprite.texture.get_image() if iconSprite.texture else null
	if not image:
		return
	if image.is_compressed():
		image.decompress()
	var used : Rect2 = Rect2(image.get_used_rect())
	visibleSize = used.size
	visibleCenter = used.get_center() - Vector2(image.get_size()) * 0.5

# The size of the icon's visible pixels as drawn in the hand.
func held_extent() -> Vector2:
	return visibleSize * (iconSprite.scale.abs() if iconSprite else Vector2.ONE)

func set_icon_scale(amount : float) -> void:
	if iconSprite:
		var sized : float = amount * (item.held_scale() if item else 1.0)
		iconSprite.scale = Vector2.ONE * sized
		iconSprite.position = (iconOffset - (visibleCenter if overhead else Vector2.ZERO)) * sized

func rest_angle(aim : float) -> float:
	return lerpf(-PI / 2.0, aim, aimFollow) + tilt

# Tooltip lines as label and value pairs. Runs on an instance that was never
# added to the tree.
func stats() -> PackedStringArray:
	return PackedStringArray()
