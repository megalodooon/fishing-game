extends CharacterBody2D
class_name Player

#------------------------#
@onready var animationPlayer : AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = %Sprite
@onready var center : Node2D = $Center

#----------Movement Variables-----------#
@export var speed : float = 50.0
@export var acceleration : float = 100.0
@export var deceleration : float = 80.0

#----------Hand Variables-----------#
var center_rotation_speed : float = 25.0
var center_follow_speed : float = 15.0
var center_rest_position : Vector2
var last_global_position : Vector2
#------------------------#


func _ready() -> void:
	center_rest_position = center.position
	last_global_position = global_position

func _physics_process(delta: float) -> void:
	move_center(delta)
	rotate_center(delta)

func move_center(delta: float):
	center.position -= global_position - last_global_position
	last_global_position = global_position

	center.position = center.position.lerp(center_rest_position,
	1.0 - exp(-center_follow_speed * delta))

func rotate_center(delta: float):
	var target_angle := (get_global_mouse_position()
	- center.global_position).angle()
	
	center.rotation = lerp_angle(center.rotation,
	target_angle,1.0 
	- exp(-center_rotation_speed
	* delta))
	
	center.rotation_degrees = wrap(
	center.rotation_degrees,0,360)
	
	if (center.rotation_degrees < 270 and 
	center.rotation_degrees > 90):
		center.scale.y = -1
	else:
		center.scale.y = 1
