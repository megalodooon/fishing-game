@tool
extends Node2D
class_name Ocean

const SHADER_PARAMETERS : Array[String] = [
	"shallow_color", "deep_color", "caustic_color",
	"depth_scale", "depth_contrast", "depth_speed",
	"wave_scale", "wave_strength", "wave_speed",
	"clarity", "refraction_strength",
	"caustic_amount", "caustic_cell_size", "caustic_speed",
	"caustic_sharpness", "caustic_coverage", "caustic_patch_size",
	"flow",
]

#------------------------#
@export var sprite : Sprite2D

@export_group("Colors")
@export var shallow_color : Color = Color(0.18, 0.62, 0.78):
	set(value):
		shallow_color = value
		update_shader("shallow_color", value)
@export var deep_color : Color = Color(0.04, 0.17, 0.36):
	set(value):
		deep_color = value
		update_shader("deep_color", value)
@export var caustic_color : Color = Color(0.8, 1.0, 1.0):
	set(value):
		caustic_color = value
		update_shader("caustic_color", value)

@export_group("Depth")
@export var depth_scale : float = 64.0:
	set(value):
		depth_scale = value
		update_shader("depth_scale", value)
@export_range(0.0, 4.0) var depth_contrast : float = 1.6:
	set(value):
		depth_contrast = value
		update_shader("depth_contrast", value)
@export var depth_speed : float = 0.01:
	set(value):
		depth_speed = value
		update_shader("depth_speed", value)

@export_group("Waves")
@export var wave_scale : float = 20.0:
	set(value):
		wave_scale = value
		update_shader("wave_scale", value)
@export var wave_strength : float = 0.8:
	set(value):
		wave_strength = value
		update_shader("wave_strength", value)
@export var wave_speed : float = 0.8:
	set(value):
		wave_speed = value
		update_shader("wave_speed", value)

@export_group("Underwater")
@export_range(0.0, 1.0) var clarity : float = 0.55:
	set(value):
		clarity = value
		update_shader("clarity", value)
@export var refraction_strength : float = 2.5:
	set(value):
		refraction_strength = value
		update_shader("refraction_strength", value)

@export_group("Caustics")
@export_range(0.0, 8.0) var caustic_amount : float = 2.5:
	set(value):
		caustic_amount = value
		update_shader("caustic_amount", value)
@export_range(1.0, 64.0, 0.5) var caustic_cell_size : float = 9.0:
	set(value):
		caustic_cell_size = value
		update_shader("caustic_cell_size", value)
@export var caustic_speed : float = 0.7:
	set(value):
		caustic_speed = value
		update_shader("caustic_speed", value)
@export_range(1.0, 8.0) var caustic_sharpness : float = 3.5:
	set(value):
		caustic_sharpness = value
		update_shader("caustic_sharpness", value)
@export_range(0.0, 100.0, 1.0) var caustic_coverage : float = 100.0:
	set(value):
		caustic_coverage = value
		update_shader("caustic_coverage", value)
@export_range(4.0, 256.0, 1.0) var caustic_patch_size : float = 48.0:
	set(value):
		caustic_patch_size = value
		update_shader("caustic_patch_size", value)

@export_group("Flow")
@export var flow : Vector2 = Vector2.ZERO:
	set(value):
		flow = value
		update_shader("flow", value)
#------------------------#


func _ready() -> void:
	for parameter in SHADER_PARAMETERS:
		update_shader(parameter, get(parameter))

func update_shader(parameter: String, value: Variant):
	if sprite:
		sprite.material.set_shader_parameter(parameter, value)
