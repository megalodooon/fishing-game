extends State
class_name PlayerHandIdleState


#------------------------#
@onready var player : Player = owner
@onready var switchState : PlayerSwitchState = %Switch
@onready var charge : PlayerChargeState = %Charge
@onready var catchText : Callout = %CatchText

@export var settleTime : float = 0.35
@export var tiredText : String = "too tired"
@export var tiredColor : Color = Color(0.95, 0.38, 0.34)
@export var tiredOffset : Vector2 = Vector2(0.0, -12.0)
#------------------------#


func enter() -> void:
	player.aimTarget = null
	player.pose_to(0.0, Vector2.ZERO, settleTime)

func update_physics(_delta : float) -> void:
	if player.heldSlot >= 0 and player.inventory.get_item(player.heldSlot) != player.held_data():
		switchState.slot = player.heldSlot
		stateMachine.change_state(switchState)

func update_input(event : InputEvent) -> void:
	if player.asleep:
		return
	var slot : int = player.slot_pressed(event)
	if slot >= 0:
		switchState.slot = -1 if slot == player.heldSlot else slot
		stateMachine.change_state(switchState)
	elif event.is_action_pressed("use") and player.heldItem is FishingRod:
		if player.energy and player.energy.is_empty():
			catchText.pop(player.center.global_position + tiredOffset, tiredText, tiredColor, 1.2)
		else:
			stateMachine.change_state(charge)
	elif event.is_action_pressed("use") and player.held_data() and not player.held_data().useAction.is_empty():
		for pressed in [true, false]:
			var use : InputEventAction = InputEventAction.new()
			use.action = player.held_data().useAction
			use.pressed = pressed
			Input.parse_input_event(use)
