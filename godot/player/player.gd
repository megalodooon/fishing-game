extends CharacterBody2D
class_name Player

#------------------------#
@onready var animationPlayer : AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = %Sprite

#----------Movement Variables-----------#
@export var speed : float = 50.0
@export var acceleration : float = 100.0
@export var deceleration : float = 80.0
#------------------------#


func _ready() -> void:
	pass
