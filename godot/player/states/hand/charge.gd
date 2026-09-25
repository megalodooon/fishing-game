extends State
class_name PlayerChargeState


#------------------------#
@onready var player : Player = owner
@onready var idle : PlayerHandIdleState = %Idle
@onready var cast : PlayerCastState = %Cast

@export var minChargeTime : float = 0.14
@export_range(-180.0, 0.0, 0.1, "radians_as_degrees") var windupAngle : float = deg_to_rad(-60.0)
@export_range(-180.0, 0.0, 0.1, "radians_as_degrees") var fullAngle : float = deg_to_rad(-100.0)
@export var windupOffset : Vector2 = Vector2(-1.5, -1.0)
@export var fullOffset : Vector2 = Vector2(-3.5, -3.0)
@export_range(0.0, 45.0, 0.1, "radians_as_degrees") var fullLean : float = deg_to_rad(12.0)
@export var tremble : float = 0.02

var elapsed : float = 0.0
var power : float = 0.0
#------------------------#


func enter() -> void:
	elapsed = 0.0
	power = 0.0
	player.rooted = true
	player.stop_pose()

func exit() -> void:
	player.rooted = false
	if player.heldItem is FishingRod:
		player.heldItem.hide_target()

func update_physics(delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	if not rod:
		stateMachine.change_state(idle)
		return
	elapsed += delta
	power = clampf(elapsed / rod.charge_time(), 0.0, 1.0)
	var eased : float = 1.0 - pow(1.0 - power, 3.0)
	player.poseAngle = lerpf(windupAngle, fullAngle, eased) + sin(elapsed * 40.0) * tremble * smoothstep(0.85, 1.0, power)
	player.poseOffset = windupOffset.lerp(fullOffset, eased)
	player.lean = fullLean * eased
	var landing : Variant = rod.find_landing(player.global_position, player.get_global_mouse_position(), power)
	if landing == null:
		rod.hide_target()
	else:
		rod.show_target(landing)
	if not Input.is_action_pressed("use") and elapsed >= minChargeTime:
		if landing == null:
			stateMachine.change_state(idle)
		else:
			cast.power = power
			stateMachine.change_state(cast)

func update_input(event : InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		stateMachine.change_state(idle)
