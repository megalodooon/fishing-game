extends State
class_name PlayerReelState


#------------------------#
@onready var player : Player = owner
@onready var idle : PlayerHandIdleState = %Idle
@onready var switchState : PlayerSwitchState = %Switch

@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var reelAngle : float = deg_to_rad(-15.0)
@export var reelOffset : Vector2 = Vector2(0.5, -1.0)
@export var crankRadius : float = 0.7
@export var crankSpeed : float = 18.0
@export var followSpeed : float = 10.0

var switchAfter : bool = false
var switchSlot : int = -1
var elapsed : float = 0.0
#------------------------#


func enter() -> void:
	elapsed = 0.0
	player.stop_pose()
	(player.heldItem as FishingRod).reel()

func exit() -> void:
	switchAfter = false

func update_physics(delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	elapsed += delta
	var weight : float = 1.0 - exp(-followSpeed * delta)
	var crank : Vector2 = Vector2.from_angle(elapsed * crankSpeed) * crankRadius
	player.poseAngle = lerpf(player.poseAngle, reelAngle, weight)
	player.poseOffset = player.poseOffset.lerp(reelOffset + crank, weight)
	player.aimTarget = rod.get_bobber_point()
	if rod.mode == FishingRod.Mode.HOLD:
		if switchAfter:
			switchState.slot = switchSlot
			stateMachine.change_state(switchState)
		else:
			stateMachine.change_state(idle)
