extends State
class_name PlayerFishingState


#------------------------#
@onready var player : Player = owner
@onready var reel : PlayerReelState = %Reel

@export var settleTime : float = 0.5
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var holdAngle : float = deg_to_rad(8.0)
@export var holdOffset : Vector2 = Vector2(1.5, 0.5)
#------------------------#


func enter() -> void:
	player.pose_to(holdAngle, holdOffset, settleTime)

func update_physics(_delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	player.aimTarget = rod.get_bobber_point()
	if rod.should_return():
		stateMachine.change_state(reel)

func update_input(event : InputEvent) -> void:
	var slot : int = player.slot_pressed(event)
	if slot >= 0:
		reel.switchAfter = true
		reel.switchSlot = -1 if slot == player.heldSlot else slot
		stateMachine.change_state(reel)
	elif event.is_action_pressed("use") or event.is_action_pressed("cancel"):
		stateMachine.change_state(reel)
