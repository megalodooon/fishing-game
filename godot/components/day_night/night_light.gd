@tool
extends Node2D
class_name NightLight

const GROUP : StringName = &"night_lights"

#------------------------#
@export var color : Color = Color(1.0, 0.72, 0.42):
	set(value):
		color = value
		queue_redraw()
@export var energy : float = 1.0
@export var darknessRange : Vector2 = Vector2(0.25, 0.55)

@export_group("Pool")
@export var radius : float = 40.0:
	set(value):
		radius = value
		queue_redraw()
@export_range(0.1, 1.0) var squash : float = 0.75:
	set(value):
		squash = value
		queue_redraw()
@export var height : float = 24.0:
	set(value):
		height = value
		queue_redraw()
@export_range(0.1, 8.0) var falloff : float = 2.0

@export_group("Glow")
@export_range(0.0, 1.0) var glow : float = 0.6
@export var glowRadius : float = 14.0:
	set(value):
		glowRadius = value
		queue_redraw()

@export_group("Flicker")
@export_range(0.0, 1.0) var flicker : float = 0.06
@export var flickerSpeed : float = 1.0
#------------------------#


func _enter_tree() -> void:
	add_to_group(GROUP)

func strength(darkness : float) -> float:
	var t : float = Time.get_ticks_msec() * 0.001 * flickerSpeed + get_instance_id() % 1000
	var wave : float = sin(t * 7.3) * 0.5 + sin(t * 12.9 + 1.7) * 0.3 + sin(t * 23.1 + 4.2) * 0.2
	return energy * smoothstep(darknessRange.x, darknessRange.y, darkness) * (1.0 + flicker * wave)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, glowRadius, 0.0, TAU, 32, color)
		draw_set_transform(Vector2(0.0, height), 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color)
