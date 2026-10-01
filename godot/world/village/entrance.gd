@tool
extends Interactable
class_name Entrance

# A building's door that leads inside: the inside is its own little Island
# scene, loaded over the outside while the player's in it (see
# World.enter_interior). Follows the building's lock and opening hours. The
# way back out is the inside's Exit, which puts the player in front of this.

#------------------------#
@export_file("*.tscn") var inside : String = ""
#------------------------#


func _ready() -> void:
	if prompt == "Use":
		prompt = "Go in"

func prompt_text(player : Player) -> String:
	var home : Building = building()
	if blocked_reason(player).is_empty() and home and not home.displayName.is_empty():
		return "Enter %s" % home.displayName
	return super(player)

func interact(player : Player) -> void:
	var world : World = World.find(get_tree())
	if world and not inside.is_empty():
		world.enter_interior(inside, global_position + Vector2(0.0, 6.0))
