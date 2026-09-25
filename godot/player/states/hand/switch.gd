extends State
class_name PlayerSwitchState


#------------------------#
@onready var player : Player = owner
@onready var idle : PlayerHandIdleState = %Idle

@export var lowerTime : float = 0.13
@export var raiseTime : float = 0.36
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var lowerAngle : float = deg_to_rad(55.0)
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var raiseAngle : float = deg_to_rad(-35.0)
@export var lowerOffset : Vector2 = Vector2(-2.0, 3.0)
@export var grabSquash : Vector2 = Vector2(1.35, 0.7)

var slot : int = -1
#------------------------#


func enter() -> void:
	var tween : Tween = player.pose_to(lowerAngle, lowerOffset, lowerTime, Tween.TRANS_SINE, Tween.EASE_IN)
	if player.heldItem:
		tween.tween_property(player, "itemScale", 0.0, lowerTime).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(raise)

func raise() -> void:
	player.itemScale = 0.0
	player.poseAngle = raiseAngle
	player.equip(slot)
	player.handScale = grabSquash
	var tween : Tween = player.pose_to(0.0, Vector2.ZERO, raiseTime, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.tween_property(player, "handScale", Vector2.ONE, raiseTime * 1.4).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(player, "itemScale", 1.0, raiseTime)
	tween.tween_callback(stateMachine.change_state.bind(idle)).set_delay(raiseTime)
