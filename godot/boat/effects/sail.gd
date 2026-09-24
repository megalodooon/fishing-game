@tool
extends Sprite2D
class_name BoatSail


func _ready() -> void:
	texture_changed.connect(fit_to_texture)
	fit_to_texture()

func fit_to_texture() -> void:
	if not texture:
		return
	var rect : Rect2i = texture.get_image().get_used_rect()
	material.set_shader_parameter("sail_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
