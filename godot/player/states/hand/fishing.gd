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

var biteTimer : float = 0.0
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
	var index : int = mini(rod.castScore, mini(ratingNames.size(), ratingColors.size()) - 1)
	if index >= 0:
		rating.pop(rod.get_bobber_point(), ratingNames[index], ratingColors[index], ratingTime)
	biteLeft = 0.0
	biteTimer = rod.bite_delay(rod.castScore)

func exit() -> void:
	biteMark.dismiss()

func update_physics(delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	var spot : FishingSpot = rod.castSpot
	player.aimTarget = rod.get_bobber_point()
	rating.anchor = rod.get_bobber_point()
	if biteLeft > 0.0:
		biteLeft -= delta
		if biteLeft <= 0.0:
			biteMark.dismiss()
			biteTimer = rod.bite_delay(rod.castScore)
	elif spot and not spot.leaving:
		biteTimer -= delta
		if biteTimer <= 0.0:
			biteLeft = rod.biteWindow
			rod.bobber.splash(biteTug)
			rating.dismiss()
			biteMark.pop(spot.global_position - Vector2(0.0, spot.size * spot.squash), "!", biteColor)
	if rod.should_return():
		stateMachine.change_state(reel)

func update_input(event : InputEvent) -> void:
	var slot : int = player.slot_pressed(event)
	if slot >= 0:
		reel.switchAfter = true
		reel.switchSlot = -1 if slot == player.heldSlot else slot
		stateMachine.change_state(reel)
	elif event.is_action_pressed("use") and biteLeft > 0.0:
		stateMachine.change_state(catchState)
	elif event.is_action_pressed("use") or event.is_action_pressed("cancel"):
		stateMachine.change_state(reel)
