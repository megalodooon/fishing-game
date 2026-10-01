extends Node
class_name FishingTutorial

# Pip talks the player through their first fish, one hint at a time, on the
# coach line (see NoticeBoard.coach). Hints follow what the hand is doing, so
# nothing pauses mid-bite. Done once the first fish is landed.

const FLAG : String = "tutorial/fish"
const HINTS : Dictionary = {
	"rod": "Take your rod out of the hotbar. Grandpa Finn's, slot one.",
	"Idle": "Hold the left mouse button to charge a cast. Aim at the rings on the water.",
	"Charge": "Let go when the bar is nearly full. Further out is where the better fish wait.",
	"Fishing": "Now we wait. When the float jumps and a ! pops up, click. Not before.",
	"Catch": "It's on! Do what the screen asks. If it gets away, that's fishing. Cast again.",
	"Reel": "Reeling in. Take a breath, then go again.",
	"done": "There it is. Your first fish here. Four more, then come find me on the pier.",
}

var player : Player
var dialogue : DialogueUI
var shown : String = ""
var finish : float = -1.0


func _ready() -> void:
	player.fish_caught.connect(on_caught)

func _process(delta : float) -> void:
	var board : NoticeBoard = NoticeBoard.find(get_tree())
	if not board:
		return
	if finish >= 0.0:
		finish -= delta
		if finish < 0.0:
			board.coach("")
			queue_free()
		return
	var key : String = "rod" if not player.heldItem is FishingRod else String(player.handStates.currentState.name) if player.handStates.currentState else ""
	if not HINTS.has(key) or (dialogue and dialogue.busy()) or (player.frozen and key != "Catch"):
		key = ""
	if key != shown:
		shown = key
		board.coach(HINTS.get(key, ""), Cast.portrait("pip"))

func on_caught(_fish : Fish, _biome : Biome) -> void:
	player.progress.set_flag(FLAG)
	shown = "done"
	finish = 7.0
	var board : NoticeBoard = NoticeBoard.find(get_tree())
	if board:
		board.coach(HINTS.done, Cast.portrait("pip"))
