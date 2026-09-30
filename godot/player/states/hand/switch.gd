extends State
class_name PlayerSwitchState


#------------------------#
@onready var player : Player = owner
@onready var idle : PlayerHandIdleState = %Idle

@export var lowerTime : float = 0.07
@export var raiseTime : float = 0.2
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var lowerAngle : float = deg_to_rad(55.0)
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var raiseAngle : float = deg_to_rad(-35.0)
@export var lowerOffset : Vector2 = Vector2(-2.0, 3.0)
@export var grabSquash : Vector2 = Vector2(1.35, 0.7)

var slot : int = -1
# A slot picked while switching: swapped in if the old item is still going
# down, or switched to right after, so fast scrolling never gets lost.
var next : int = -1
var queued : bool = false
var raised : bool = false
#------------------------#


func enter() -> void:
	queued = false
	raised = false
	var tween : Tween = player.pose_to(lowerAngle, lowerOffset, lowerTime, Tween.TRANS_SINE, Tween.EASE_IN)
	if player.heldItem:
		tween.tween_property(player, "itemScale", 0.0, lowerTime).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_callback(raise)

func raise() -> void:
	raised = true
	player.itemScale = 0.0
	player.poseAngle = raiseAngle
	player.equip(slot)
	player.handScale = grabSquash
	var tween : Tween = player.pose_to(0.0, Vector2.ZERO, raiseTime, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.tween_property(player, "handScale", Vector2.ONE, raiseTime * 1.4).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(player, "itemScale", 1.0, raiseTime)
	tween.tween_callback(finish).set_delay(raiseTime)

func finish() -> void:
	stateMachine.change_state(idle)
	if queued and next != player.heldSlot:
		idle.pick(next, false)

func update_input(event : InputEvent) -> void:
	if player.asleep:
		return
	var picked : int = player.slot_pressed(event)
	var wheel : int = idle.wheel_step(event)
	if picked >= 0:
		choose(-1 if picked == target() else picked)
	elif wheel != 0:
		choose(idle.wheel_slot(target(), wheel))

func target() -> int:
	return next if queued else slot

func choose(chosen : int) -> void:
	if raised:
		next = chosen
		queued = true
	else:
		slot = chosen
