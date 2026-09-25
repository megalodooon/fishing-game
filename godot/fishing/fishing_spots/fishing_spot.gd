@tool
extends Node2D
class_name FishingSpot


#------------------------#
@export var radius : float = 10.0
@export var rings : int = 3
@export var ringSpeed : float = 0.4
@export var ringWidth : float = 0.8
@export_range(0.1, 1.0) var squash : float = 0.55
@export var ringColor : Color = Color(0.9, 0.98, 1.0, 1.0)
@export var shadowColor : Color = Color(0.0, 0.06, 0.16, 0.5)
@export var lifetime : Vector2 = Vector2(20.0, 30.0)
@export var fadeTime : float = 1.0

var age : float = 0.0
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	modulate.a = 0.0
	var tween : Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fadeTime)
	tween.tween_interval(randf_range(lifetime.x, lifetime.y))
	tween.tween_property(self, "modulate:a", 0.0, fadeTime)
	tween.tween_callback(queue_free)

func _process(delta : float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius * 0.45, shadowColor, true, -1.0, true)
	for i in rings:
		var t : float = fposmod(age * ringSpeed + float(i) / rings, 1.0)
		draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 48, Color(ringColor, ringColor.a * sin(t * PI)), ringWidth, true)
