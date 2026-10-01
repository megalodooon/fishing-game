@tool
extends Interactable
class_name Exit

# The door out of a building's inside, back to where the player came in.
# Walking onto the doormat works too.

const STEP_REACH : float = 5.0


func _ready() -> void:
	if prompt == "Use":
		prompt = "Leave"

func interact(_player : Player) -> void:
	var world : World = World.find(get_tree())
	if world:
		world.leave_interior()

func _physics_process(_delta : float) -> void:
	if Engine.is_editor_hint():
		return
	var player : Player = Player.find(get_tree())
	var world : World = World.find(get_tree()) if player else null
	# Stepping onto the mat from inside (moving down) leaves.
	if world and world.interior and not player.frozen and player.global_position.distance_to(global_position) < STEP_REACH and player.velocity.y > 0.0:
		world.leave_interior()
