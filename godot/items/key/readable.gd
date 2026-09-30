extends Item
class_name Readable

# A note, a logbook page or a letter. Clicking with it held plays its scene
# from the dialogue file. Key items can't be thrown away and stay out of the
# collections.

#------------------------#
@export var scene : String = ""
#------------------------#


func use(player : Player) -> bool:
	var talk : DialogueUI = DialogueUI.find(player.get_tree())
	if talk and not scene.is_empty():
		talk.play(scene)
	return true

func default_type() -> String:
	return "Key Item"
