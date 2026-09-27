extends State
class_name PlayerCatchState


#------------------------#
@onready var player : Player = owner
@onready var reel : PlayerReelState = %Reel

@export_range(0.0, 1.0) var hookSplash : float = 0.8
#------------------------#


func enter() -> void:
	(player.heldItem as FishingRod).bobber.splash(hookSplash)

func update_physics(_delta : float) -> void:
	player.aimTarget = (player.heldItem as FishingRod).get_bobber_point()

func update_input(event : InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		stateMachine.change_state(reel)
