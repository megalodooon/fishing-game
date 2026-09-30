@tool
extends Node2D
class_name IslandRoom

# One screen of an island. The camera jumps from room to room as the player
# walks across their edges, so rooms sit side by side like tiles. The land
# sprites mark the ground: the player walks wherever they're opaque, casts
# can't land there and the sea shows through where they're see-through.

#------------------------#
@export var size : Vector2 = Vector2(192.0, 108.0):
	set(value):
		size = value
		queue_redraw()
@export var land : Array[Sprite2D] = []
#------------------------#


func rect() -> Rect2:
	return Rect2(global_position, size)

func is_land(point : Vector2) -> bool:
	for sprite in land:
		if sprite and sprite.visible and sprite.texture and sprite.is_pixel_opaque(sprite.to_local(point)):
			return true
	return false

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.8, 0.3, 0.8), false, 1.0)
