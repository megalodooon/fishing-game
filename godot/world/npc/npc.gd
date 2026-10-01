@tool
extends Interactable
class_name Npc

# Someone to talk to. F plays a waiting scene first: a heart scene once the
# friendship is high enough ("<id>_heart<N>", see Friendship), or their story
# scene for the current chapter ("<id>_ch<chapter>"). Then the conversation
# opens (see DialogueUI.converse): talk, their jobs, their shop or service, a
# gift, goodbye. A marker floats over them: ! for new jobs, ? for jobs to hand
# in, ... for a scene waiting, a heart on their birthday. They follow their
# daily schedule around the island (see Schedules), walking the island's
# WalkGrid, and go inside at night. The standing sprite is the Art child.

const NEW_COLOR : Color = Color(1.0, 0.9, 0.4)
const READY_COLOR : Color = Color(0.56, 0.93, 0.44)
const TALK_COLOR : Color = Color(0.75, 0.85, 1.0)
const MARK_EVERY : float = 0.4

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
# A festival or happening host put up for the day, not the everyday them.
@export var host : bool = false

var player : Player
var board : QuestBoard
var time : float = 0.0
var artHome : Vector2
var mark : String = ""
var markWait : float = 0.0
# Following the schedule.
var stop : Array = []
var route : PackedVector2Array = PackedVector2Array()
var routeAt : int = 0
var indoors : bool = false
var walking : bool = false
var lastFrame : int = -1
#------------------------#


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	player = Player.find(get_tree())
	time = randf() * 10.0
	markWait = randf() * MARK_EVERY
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
	if indoors:
		return false
	if not host and EventDirector.hosting(get_tree(), id):
		return false
	return (appearFlag.is_empty() or who.progress.has_flag(appearFlag)) and (leaveFlag.is_empty() or not who.progress.has_flag(leaveFlag))

func story_scene() -> String:
	var scene : String = "%s_ch%d" % [id, player.progress.chapter]
	return scene if Dialogue.has_scene(scene) and not player.progress.has_flag("talked/" + scene) else ""

func interact(who : Player) -> void:
	var talk : DialogueUI = DialogueUI.find(get_tree())
	if not talk:
		return
	var heart : String = Friendship.heart_scene(who.progress, id)
	if not heart.is_empty():
		talk.play(heart, func(_choice : int) -> void:
			Friendship.finish_heart_scene(who, heart)
			talk.converse(self, who))
		return
	var scene : String = story_scene()
	if not scene.is_empty():
		who.progress.set_flag("talked/" + scene)
		talk.play(scene, func(_choice : int) -> void: talk.converse(self, who))
		return
	if Friendship.TASTES.has(id) and not Features.seen(who, "friends"):
		Features.introduce(who, "friends", talk.converse.bind(self, who))
		return
	talk.converse(self, who)

# Their jobs that can be taken, are going or are ready.
func jobs(who : Player) -> Array[Quest]:
	var list : Array[Quest] = []
	for quest in quests:
		if quest and (quest.available(who) or who.progress.quest_active(quest)):
			list.append(quest)
	return list

func has_jobs(who : Player) -> bool:
	return not jobs(who).is_empty()

func work_out_marker() -> String:
	if not player or not player.progress:
		return ""
	for quest in quests:
		if quest and quest.ready(player):
			return "?"
	if not story_scene().is_empty() or not Friendship.heart_scene(player.progress, id).is_empty():
		return "..."
	for quest in quests:
		if quest and quest.available(player):
			return "!"
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	if cycle and Friendship.is_birthday(id, cycle.day) and not Friendship.gifted_today(player.progress, id, cycle.day):
		return "birthday"
	return ""

func prompt_text(who : Player) -> String:
	return "Talk to %s" % Friendship.short_name(id) if blocked_reason(who).is_empty() else super(who)

# ---------------------------------------------------------------- schedule

func island() -> Island:
	var node : Node = get_parent()
	while node and not node is Island:
		node = node.get_parent()
	return node as Island

func room() -> IslandRoom:
	return get_parent() as IslandRoom

# Checks the schedule. Snaps straight there when nobody can see.
func follow_schedule(snap : bool) -> void:
	if host or not Schedules.has(id) or not player:
		return
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	var home : Island = island()
	if not cycle or not home:
		return
	var next : Array = Schedules.stop_at(id, cycle.day, cycle.time)
	if next.is_empty() or next == stop:
		return
	# A stop names a room and a point in it, or no room and a point on the
	# whole island. A room that isn't here (like inside a building, or out
	# here when this is the inside) means they're somewhere else.
	var goalRoom : IslandRoom = home.room_named(next[1]) if not String(next[1]).is_empty() else (null if home.interior else home.room_at(home.global_position + next[2]))
	stop = next
	if not goalRoom:
		walking = false
		indoors = true
		visible = false
		return
	var goal : Vector2 = goalRoom.global_position + next[2] if not String(next[1]).is_empty() else home.global_position + next[2]
	var seen : bool = home.room_seen(room()) or home.room_seen(goalRoom)
	if snap or not seen or not visible:
		arrive_at(goalRoom, goal)
		return
	var grid : WalkGrid = home.walk_grid()
	route = grid.path(global_position, goal) if grid else PackedVector2Array()
	routeAt = 0
	if route.is_empty():
		arrive_at(goalRoom, goal)
		return
	# Walking in from a room out of sight: start where the way comes into view.
	if not home.room_seen(room()):
		for i in route.size():
			var through : IslandRoom = home.room_at(route[i])
			if through and home.room_seen(through):
				move_into(through, route[i])
				routeAt = i
				break
	indoors = false
	walking = true
	set_process(true)

func arrive_at(goalRoom : IslandRoom, goal : Vector2) -> void:
	move_into(goalRoom, goal)
	route = PackedVector2Array()
	walking = false
	indoors = Schedules.inside(stop)
	visible = not indoors and player != null and available(player)

func move_into(target : IslandRoom, point : Vector2) -> void:
	if get_parent() != target:
		reparent(target)
	global_position = point

func walk(delta : float) -> void:
	var home : Island = island()
	var step : float = Schedules.WALK_SPEED * delta
	while step > 0.0 and routeAt < route.size():
		var goal : Vector2 = route[routeAt]
		var gap : Vector2 = goal - global_position
		if gap.length() <= step:
			global_position = goal
			step -= gap.length()
			routeAt += 1
		else:
			global_position += gap.normalized() * step
			if art is Sprite2D and absf(gap.x) > 0.5:
				(art as Sprite2D).flip_h = gap.x < 0.0
			step = 0.0
	# Walked out of this room: into the next one, out of sight.
	if home and not room().rect().has_point(global_position):
		var next : IslandRoom = home.room_at(global_position)
		if next and next != room():
			if home.room_seen(next):
				reparent(next)
			else:
				finish_walk()
				return
	if routeAt >= route.size():
		arrive_at(room(), global_position)

# Skips to the end of the walk, in whichever room it ends.
func finish_walk() -> void:
	var end : Vector2 = route[route.size() - 1] if not route.is_empty() else global_position
	var home : Island = island()
	var endRoom : IslandRoom = home.room_at(end) if home else null
	arrive_at(endRoom if endRoom else room(), end)

func _process(delta : float) -> void:
	if Engine.is_editor_hint():
		return
	var frame : int = Engine.get_process_frames()
	# Coming back into view after being out of sight: catch up.
	if lastFrame >= 0 and frame - lastFrame > 2 and walking:
		finish_walk()
	lastFrame = frame
	time += delta
	if walking:
		walk(delta)
	elif not indoors:
		visible = player != null and available(player)
	if art:
		var bob : float = absf(sin(time * (9.0 if walking else 1.6))) * (1.0 if walking else 0.5)
		art.position = artHome + Vector2(0.0, -roundf(bob * 2.0) * 0.5)
	markWait -= delta
	if markWait <= 0.0:
		markWait = MARK_EVERY
		var fresh : String = work_out_marker()
		if fresh != mark:
			mark = fresh
			queue_redraw()
	if not mark.is_empty():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		super()
		return
	if mark.is_empty():
		return
	var color : Color = READY_COLOR if mark == "?" else (TALK_COLOR if mark == "..." else NEW_COLOR)
	var at : Vector2 = Vector2(0.0, -markerHeight + sin(time * 4.0) * 1.0)
	if mark == "birthday":
		var heart : Color = Friendship.HEART_COLOR
		for p in [Vector2(-1.5, -2.5), Vector2(0.5, -2.5), Vector2(-2.5, -1.5), Vector2(-1.5, -1.5), Vector2(-0.5, -1.5), Vector2(0.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, -0.5), Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5)]:
			draw_rect(Rect2(at + p, Vector2.ONE), heart)
		return
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
