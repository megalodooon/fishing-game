extends State
class_name PlayerCastState


#------------------------#
@onready var player : Player = owner
@onready var fishing : PlayerFishingState = %Fishing
@onready var reel : PlayerReelState = %Reel

@export var whipTime : float = 0.12
@export var followTime : float = 0.4
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var whipAngle : float = deg_to_rad(35.0)
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var followAngle : float = deg_to_rad(12.0)
@export_range(-180.0, 0.0, 0.1, "radians_as_degrees") var releaseAngle : float = deg_to_rad(-80.0)
@export_range(-45.0, 45.0, 0.1, "radians_as_degrees") var whipLean : float = deg_to_rad(-8.0)
@export var whipOffset : Vector2 = Vector2(3.5, 0.5)
@export var followOffset : Vector2 = Vector2(2.0, 0.5)
@export var releaseSquash : Vector2 = Vector2(0.8, 1.2)

var power : float = 0.0
var target : Vector2
var released : bool = false
var elapsed : float = 0.0
#------------------------#


func enter() -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	target = rod.find_landing(player.global_position, player.get_global_mouse_position(), power)
	player.aimTarget = target
	player.rooted = true
	released = false
	elapsed = 0.0
	var tween : Tween = player.pose_to(whipAngle, whipOffset, whipTime, Tween.TRANS_QUAD, Tween.EASE_IN, whipLean)
	tween.chain().tween_property(player, "poseAngle", followAngle, followTime).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "poseOffset", followOffset, followTime).set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "lean", 0.0, followTime).set_ease(Tween.EASE_OUT)

func exit() -> void:
	player.rooted = false

func update_physics(delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	elapsed += delta
	if not released and (player.itemAngle >= releaseAngle or elapsed >= whipTime):
		released = true
		rod.launch(target)
		player.handScale = releaseSquash
		player.create_tween().tween_property(player, "handScale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if released and rod.mode == FishingRod.Mode.WATER:
		stateMachine.change_state(fishing)

func update_input(event : InputEvent) -> void:
	if released and event.is_action_pressed("use"):
		stateMachine.change_state(reel)
