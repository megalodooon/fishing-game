@tool
extends Node2D
class_name Interactable

# Something the player can use with F when standing close to it: a door, a
# bed, a machine. The prompt floats above it while it's the closest thing in
# reach. Inside a Building it follows the building's lock and opening days.

const GROUP : StringName = &"interactables"

#------------------------#
@export var prompt : String = "Use":
	set(value):
		prompt = value
		queue_redraw()
@export var reach : float = 14.0:
	set(value):
		reach = value
		queue_redraw()
# Where the prompt floats, from this node.
@export var promptOffset : Vector2 = Vector2(0.0, -14.0)
@export var promptColor : Color = Color(0.94, 0.97, 1.0)
@export var blockedColor : Color = Color(0.82, 0.86, 0.92)
# Off for counters only reached through someone, like an NPC's shop.
@export var listed : bool = true
#------------------------#


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)

func building() -> Building:
	var node : Node = get_parent()
	while node:
		if node is Building:
			return node
		node = node.get_parent()
	return null

# Whether it shows up as something to use at all.
func available(_player : Player) -> bool:
	return true

func distance_to(point : Vector2) -> float:
	return global_position.distance_to(point)

func prompt_point(_player : Player) -> Vector2:
	return global_position + promptOffset

# Why it can't be used right now, or nothing when it can.
func blocked_reason(player : Player) -> String:
	var home : Building = building()
	return home.blocked_reason(player) if home else ""

func prompt_text(player : Player) -> String:
	var home : Building = building()
	return prompt if blocked_reason(player).is_empty() else home.blocked_label(player)

func prompt_color(player : Player) -> Color:
	return promptColor if blocked_reason(player).is_empty() else blockedColor

func try_interact(player : Player) -> void:
	var why : String = blocked_reason(player)
	if why.is_empty():
		interact(player)
	else:
		var home : Building = building()
		notice(home.displayName if home else prompt, why, blockedColor)

func interact(_player : Player) -> void:
	pass

func notice(title : String, text : String, color : Color = promptColor, icon : Texture2D = null) -> void:
	var board : NoticeBoard = NoticeBoard.find(get_tree())
	if board:
		board.post(title, text, color, icon)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 32, Color(0.5, 1.0, 0.6, 0.6), 0.5)
		draw_circle(promptOffset, 1.0, Color(0.5, 1.0, 0.6, 0.8))
