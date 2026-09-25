extends State
class_name PlayerHandIdleState


#------------------------#
@onready var player : Player = owner
@onready var switchState : PlayerSwitchState = %Switch
@onready var charge : PlayerChargeState = %Charge

@export var settleTime : float = 0.35
#------------------------#


func enter() -> void:
	player.aimTarget = null
	player.pose_to(0.0, Vector2.ZERO, settleTime)

func update_input(event : InputEvent) -> void:
	var slot : int = player.slot_pressed(event)
	if slot >= 0:
		switchState.slot = -1 if slot == player.heldSlot else slot
		stateMachine.change_state(switchState)
	elif event.is_action_pressed("use") and player.heldItem is FishingRod:
		stateMachine.change_state(charge)
