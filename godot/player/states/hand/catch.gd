extends State
class_name PlayerCatchState


#------------------------#
@onready var player : Player = owner
@onready var reel : PlayerReelState = %Reel

@export_range(0.0, 1.0) var hookSplash : float = 0.8
#------------------------#


func enter() -> void:
	(player.heldItem as FishingRod).bobber.splash(hookSplash)
	stateMachine.change_state(reel)
