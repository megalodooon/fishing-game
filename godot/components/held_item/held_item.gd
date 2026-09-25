@tool
extends Node2D
class_name HeldItem


#------------------------#
@export_range(0.0, 1.0) var handAimWeight : float = 1.0
@export_range(0.0, 1.0) var aimFollow : float = 1.0
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var tilt : float = 0.0

var holder : Player
var appear : float = 1.0
var angularVelocity : float = 0.0
#------------------------#


func rest_angle(aim : float) -> float:
	return lerpf(-PI / 2.0, aim, aimFollow) + tilt
