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
		return
	# Holding the button down plants (or harvests) every tile swept over.
	if Input.is_action_pressed("use") and not player.frozen and not player.charting:
		player.hold_farm()
	else:
		player.lastFarmKey = []

func update_input(event : InputEvent) -> void:
	if player.asleep:
		return
	var slot : int = player.slot_pressed(event)
	var wheel : int = wheel_step(event)
	if slot >= 0:
		pick(slot)
	elif wheel != 0:
		pick(wheel_slot(player.heldSlot, wheel), false)
	elif event.is_action_pressed("interact"):
		if player.interactTarget and not player.frozen:
			player.interactTarget.try_interact(player)
	elif event.is_action_pressed("use") and player.heldItem is FishingRod:
		if player.energy and player.energy.is_empty():
			catchText.pop(player.center.global_position + tiredOffset, tiredText, tiredColor, 1.2)
		else:
			stateMachine.change_state(charge)
	elif event.is_action_pressed("use") and player.click_farm():
		pass
	elif event.is_action_pressed("use") and player.held_data() and player.held_data().use(player):
		pass
	elif event.is_action_pressed("use") and player.held_data() and not player.held_data().useAction.is_empty():
		for pressed in [true, false]:
			var use : InputEventAction = InputEventAction.new()
			use.action = player.held_data().useAction
			use.pressed = pressed
			Input.parse_input_event(use)

# Picking the held slot again puts it away, unless toggling is off (the wheel).
func pick(slot : int, toggle : bool = true) -> void:
	switchState.slot = -1 if toggle and slot == player.heldSlot else slot
	stateMachine.change_state(switchState)

# The hotbar slot one wheel step away. With nothing held, down starts at the
# first slot and up at the last.
func wheel_slot(from : int, step : int) -> int:
	return wrapi((from if from >= 0 else (-1 if step > 0 else 0)) + step, 0, player.inventory.hotbarSize)

# 1 for the wheel scrolling down, -1 for up, 0 for anything else.
func wheel_step(event : InputEvent) -> int:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return 1
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			return -1
	return 0
