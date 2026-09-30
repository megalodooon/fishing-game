@tool
extends Interactable
class_name Bed

# Where the night ends. Sleeping follows the SleepSchedule's bedtime rules.
# A bed with a rent has to be paid for once (like a room at an inn), then it
# can be slept in every night.

const CABIN_GROUP : StringName = &"cabin_bunks"

#------------------------#
@export var rentCost : int = 0
@export var rentTitle : String = "Room rented!"
@export_multiline var rentText : String = "Sleep here any night from now on."
@export var paidColor : Color = Color(0.56, 0.93, 0.44)
# The bunk on the boat: only there once the Boatyard has built a cabin.
@export var needsCabin : bool = false
#------------------------#


func _ready() -> void:
	if needsCabin and not Engine.is_editor_hint():
		add_to_group(CABIN_GROUP)

func available(player : Player) -> bool:
	return not needsCabin or BoatParts.tier(player.progress, BoatParts.CABIN) >= 1

func rent_key() -> String:
	return "bed/" + String(get_path())

func rented(player : Player) -> bool:
	return rentCost <= 0 or player.progress.has_flag(rent_key())

func prompt_text(player : Player) -> String:
	if blocked_reason(player).is_empty() and not rented(player):
		return "Rent room $%d" % rentCost
	return super(player)

func interact(player : Player) -> void:
	if not rented(player):
		if not player.wallet.spend(rentCost):
			notice("Not enough coins", "A room here costs $%d." % rentCost, blockedColor)
			return
		player.progress.set_flag(rent_key())
		notice(rentTitle, rentText, paidColor)
		return
	var schedule : SleepSchedule = SleepSchedule.find(get_tree())
	if schedule:
		schedule.try_sleep()
