@tool
extends Interactable
class_name Npc

# Someone to talk to. F plays their story scene for the current chapter the
# first time ("<id>_ch<chapter>" in the dialogue file), otherwise a line of
# small talk ("<id>_chat") with choices: their jobs (a quest board made from
# quests), their shop or service (any Counter, usually a child with listed
# off) and goodbye. A marker floats over them: ! for new jobs, ? for jobs to
# hand in, ... for a story scene waiting. The standing sprite is the Art child.

const NEW_COLOR : Color = Color(1.0, 0.9, 0.4)
const READY_COLOR : Color = Color(0.56, 0.93, 0.44)
const TALK_COLOR : Color = Color(0.75, 0.85, 1.0)

#------------------------#
# Their Cast id.
@export var id : String = ""
@export var quests : Array[Quest] = []
@export var shop : Counter
@export var shopLabel : String = "Shop"
@export var service : Counter
@export var serviceLabel : String = "Help"
@export var greeting : String = "Hello there."
# Gently bobs the Art child, so they look alive. A Sprite2D is stood on its
# feet at this node, and the marker and prompt moved over its head, from the
# size of its texture.
@export var art : Node2D
@export var markerHeight : float = 22.0
# Only around once this flag is set, and gone again once the other one is.
@export var appearFlag : String = ""
@export var leaveFlag : String = ""

var player : Player
var board : QuestBoard
var time : float = 0.0
var artHome : Vector2
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	time = randf() * 10.0
	var sprite : Sprite2D = art as Sprite2D
	if sprite and sprite.texture:
		# Stands on its feet whatever size the art is drawn at, with the marker
		# and the prompt just over its head.
		var extent : Vector2 = sprite.texture.get_size()
		sprite.centered = false
		sprite.offset = Vector2(-floorf(extent.x * 0.5), -extent.y)
		markerHeight = extent.y + 2.0
		promptOffset.y = -extent.y - 4.0
	if art:
		artHome = art.position
	if not quests.is_empty():
		board = QuestBoard.new()
		board.quests = quests
		board.title = Cast.name_of(id)
		board.portrait = Cast.portrait(id)
		board.listed = false
		board.greeting = greeting
		add_child(board)
	if prompt == "Use":
		prompt = "Talk"

func available(who : Player) -> bool:
	return (appearFlag.is_empty() or who.progress.has_flag(appearFlag)) and (leaveFlag.is_empty() or not who.progress.has_flag(leaveFlag))

func story_scene() -> String:
	var scene : String = "%s_ch%d" % [id, player.progress.chapter]
	return scene if Dialogue.has_scene(scene) and not player.progress.has_flag("talked/" + scene) else ""

func interact(who : Player) -> void:
	var talk : DialogueUI = DialogueUI.find(get_tree())
	if not talk:
		return
	var scene : String = story_scene()
	if not scene.is_empty():
		who.progress.set_flag("talked/" + scene)
		talk.play(scene, func(_choice : int) -> void: menu(who))
	else:
		menu(who)

func menu(who : Player) -> void:
	var talk : DialogueUI = DialogueUI.find(get_tree())
	var chat : Array = Dialogue.random_line(id + "_chat")
	var line : String = chat[1] if chat.size() > 1 else greeting
	var labels : PackedStringArray = PackedStringArray()
	var actions : Array[Counter] = []
	if board and has_jobs(who):
		labels.append("Jobs")
		actions.append(board)
	if shop:
		labels.append(shopLabel)
		actions.append(shop)
	if service:
		labels.append(serviceLabel)
		actions.append(service)
	labels.append("Bye")
	talk.say(id, line, labels, func(choice : int) -> void:
		if choice >= 0 and choice < actions.size():
			actions[choice].interact(who))

func has_jobs(who : Player) -> bool:
	for quest in quests:
		if quest and (quest.available(who) or who.progress.quest_started(quest)):
			return true
	return false

func marker() -> String:
	if not player or not player.progress:
		return ""
	for quest in quests:
		if quest and quest.ready(player):
			return "?"
	if not story_scene().is_empty():
		return "..."
	for quest in quests:
		if quest and quest.available(player):
			return "!"
	return ""

func prompt_text(who : Player) -> String:
	return "Talk to %s" % Cast.name_of(id).get_slice(" ", 0) if blocked_reason(who).is_empty() else super(who)

func _process(delta : float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	visible = player != null and available(player)
	if art:
		art.position = artHome + Vector2(0.0, -roundf(absf(sin(time * 1.6)) * 2.0) * 0.5)
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		super()
		return
	var mark : String = marker()
	if mark.is_empty():
		return
	var color : Color = READY_COLOR if mark == "?" else (TALK_COLOR if mark == "..." else NEW_COLOR)
	var at : Vector2 = Vector2(0.0, -markerHeight + sin(time * 4.0) * 1.0)
	if mark == "...":
		for i in 3:
			draw_rect(Rect2(at + Vector2(-2.5 + i * 2.0, 0.0), Vector2.ONE), color)
		return
	draw_rect(Rect2(at + Vector2(-1.5, -4.0), Vector2(3.0, 6.0)), Color(0.04, 0.07, 0.13, 0.9))
	if mark == "!":
		draw_rect(Rect2(at + Vector2(-0.5, -3.5), Vector2(1.0, 3.0)), color)
		draw_rect(Rect2(at + Vector2(-0.5, 0.5), Vector2(1.0, 1.0)), color)
	else:
		draw_rect(Rect2(at + Vector2(-0.5, -3.5), Vector2(1.5, 1.0)), color)
		draw_rect(Rect2(at + Vector2(0.5, -2.5), Vector2(1.0, 1.0)), color)
		draw_rect(Rect2(at + Vector2(-0.5, -1.5), Vector2(1.0, 1.0)), color)
		draw_rect(Rect2(at + Vector2(-0.5, 0.5), Vector2(1.0, 1.0)), color)
