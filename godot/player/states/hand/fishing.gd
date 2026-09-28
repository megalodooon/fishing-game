extends State
class_name PlayerFishingState


#------------------------#
@onready var player : Player = owner
@onready var reel : PlayerReelState = %Reel
@onready var catchState : PlayerCatchState = %Catch
@onready var rating : Callout = %Rating
@onready var biteMark : Callout = %BiteMark

@export var settleTime : float = 0.5
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var holdAngle : float = deg_to_rad(8.0)
@export var holdOffset : Vector2 = Vector2(1.5, 0.5)

@export_group("Rating")
@export var ratingNames : PackedStringArray = PackedStringArray(["miss", "bad", "okay", "good", "better", "perfect"])
@export var ratingColors : PackedColorArray = PackedColorArray([Color(0.82, 0.86, 0.92), Color(0.95, 0.38, 0.34), Color(1.0, 0.66, 0.3), Color(0.98, 0.9, 0.38), Color(0.56, 0.93, 0.44), Color(0.45, 0.93, 1.0)])
@export var ratingTime : float = 1.5

@export_group("Bite")
@export var biteColor : Color = Color(1.0, 0.9, 0.35)
@export_range(0.0, 1.0) var biteTug : float = 0.35

# One bite timer per line. Only one line bites at a time.
var biteTimers : PackedFloat32Array = PackedFloat32Array()
var biting : FishingRod
var shown : FishingRod
var biteLeft : float = 0.0
#------------------------#


func _ready() -> void:
	rating.boat = player.boat
	biteMark.boat = player.boat
	rating.warm_up("".join(ratingNames))
	biteMark.warm_up("!")

func enter() -> void:
	player.pose_to(holdAngle, holdOffset, settleTime)
	var rod : FishingRod = player.heldItem as FishingRod
	var lines : Array[FishingRod] = rod.line_rods()
	shown = rod
	biteTimers.resize(lines.size())
	for i in lines.size():
		biteTimers[i] = lines[i].bite_delay(lines[i].castScore)
		if lines[i].castScore > shown.castScore:
			shown = lines[i]
	var index : int = mini(shown.castScore, mini(ratingNames.size(), ratingColors.size()) - 1)
	if index >= 0:
		rating.pop(shown.get_bobber_point(), ratingNames[index], ratingColors[index], ratingTime)
	biteLeft = 0.0
	biting = null

func exit() -> void:
	biteMark.dismiss()

func update_physics(delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	var lines : Array[FishingRod] = rod.line_rods()
	player.aimTarget = (biting if biting else rod).get_bobber_point()
	rating.anchor = shown.get_bobber_point()
	if biteLeft > 0.0:
		biteLeft -= delta
		if biteLeft <= 0.0:
			biteMark.dismiss()
			biteTimers[lines.find(biting)] = biting.bite_delay(biting.castScore)
			biting = null
	else:
		for i in mini(lines.size(), biteTimers.size()):
			var spot : FishingSpot = lines[i].castSpot
			if lines[i].mode != FishingRod.Mode.WATER or not spot or spot.leaving:
				continue
			biteTimers[i] -= delta
			if biteTimers[i] <= 0.0:
				biting = lines[i]
				biteLeft = biting.bite_window()
				biting.bobber.splash(biteTug)
				rating.dismiss()
				biteMark.pop(spot.global_position - Vector2(0.0, spot.size * spot.squash), "!", biteColor)
				break
	if rod.should_return():
		stateMachine.change_state(reel)

func update_input(event : InputEvent) -> void:
	var slot : int = player.slot_pressed(event)
	if slot >= 0:
		reel.switchAfter = true
		reel.switchSlot = -1 if slot == player.heldSlot else slot
		stateMachine.change_state(reel)
	elif event.is_action_pressed("use") and biteLeft > 0.0 and biting:
		catchState.line = biting
		stateMachine.change_state(catchState)
	elif event.is_action_pressed("use") or event.is_action_pressed("cancel"):
		stateMachine.change_state(reel)
