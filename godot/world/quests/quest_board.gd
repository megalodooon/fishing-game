@tool
extends Counter
class_name QuestBoard

# Someone with jobs to hand out: a notice board, a hermit, a smith. Lists
# their quests that are open to take, going or ready to hand in, then the
# ones already done. Picking one takes it, or hands it in once it's ready.

const NEW_COLOR : Color = Color(1.0, 0.9, 0.4)
const READY_COLOR : Color = Color(0.56, 0.93, 0.44)
const DIM_COLOR : Color = Color(0.58, 0.67, 0.78)
const STORY_COLOR : Color = Color(1.0, 0.78, 0.35)

#------------------------#
@export var quests : Array[Quest] = []
@export var greeting : String = ""
#------------------------#


func subtitle(player : Player) -> String:
	var finished : int = 0
	for quest in quests:
		if quest and quest.ready(player):
			finished += 1
	if finished > 0:
		return "%d ready to hand in!" % finished
	return greeting

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	var done : Array[Dictionary] = []
	for quest in quests:
		if not quest:
			continue
		if quest.ready(player):
			list.push_front({"value": quest, "text": quest.title, "detail": "Done!", "detailColor": READY_COLOR, "marked": true})
		elif player.progress.quest_active(quest):
			list.append({"value": quest, "text": quest.title, "detail": progress_text(player, quest), "detailColor": DIM_COLOR})
		elif quest.available(player):
			list.append({"value": quest, "text": quest.title, "detail": "New", "detailColor": NEW_COLOR})
		elif player.progress.quest_done(quest):
			done.append({"value": quest, "text": quest.title, "detail": "Finished", "detailColor": DIM_COLOR, "dim": true})
	list.append_array(done)
	return list

static func progress_text(player : Player, quest : Quest) -> String:
	var have : int = 0
	var need : int = 0
	for i in quest.goals.size():
		have += mini(quest.goal_progress(player, i), quest.goals[i].needed())
		need += quest.goals[i].needed()
	return "%d%%" % roundi(100.0 * have / maxf(need, 1.0))

static func quest_info(player : Player, quest : Quest) -> Dictionary:
	var lines : Array = []
	for i in quest.goals.size():
		var goal : QuestGoal = quest.goals[i]
		var have : int = quest.goal_progress(player, i) if player.progress.quest_started(quest) else 0
		var finished : bool = player.progress.quest_done(quest) or have >= goal.needed()
		var count : String = "Done" if finished else ("%d/%d" % [have, goal.needed()] if goal.needed() > 1 else "-")
		lines.append([goal.describe(), count, READY_COLOR if finished else Color(0.94, 0.97, 1.0)])
	lines.append_array(quest.reward_lines())
	var tag : String = ("Story - " if quest.story else "") + quest.giver
	return {"title": quest.title, "color": STORY_COLOR if quest.story else Color(0.94, 0.97, 1.0), "tag": tag, "text": quest.description, "lines": lines}

func info(player : Player, value : Variant) -> Dictionary:
	var quest : Quest = value as Quest
	if not quest:
		return {}
	var details : Dictionary = QuestBoard.quest_info(player, quest)
	if quest.ready(player):
		details.action = "Hand in"
	elif player.progress.quest_active(quest):
		details.action = "In progress"
		details.enabled = false
	elif quest.available(player):
		details.action = "Take the job"
	else:
		details.action = "Finished"
		details.enabled = false
	return details

func choose(player : Player, value : Variant) -> String:
	var quest : Quest = value as Quest
	if not quest:
		return ""
	if quest.ready(player):
		if not quest.turn_in(player):
			return fail("No room for the reward")
		notice("Quest complete!", quest.title + (": " + ", ".join(reward_names(quest)) if not reward_names(quest).is_empty() else ""), READY_COLOR)
		return ok("Handed in!")
	if quest.available(player):
		player.progress.start_quest(quest)
		return ok("Job taken!")
	if player.progress.quest_active(quest):
		return fail("Not done yet")
	return ""

static func reward_names(quest : Quest) -> PackedStringArray:
	var names : PackedStringArray = PackedStringArray()
	for line in quest.reward_lines():
		if not String(line[1]).is_empty():
			names.append(line[1])
	return names

func theme_name() -> String:
	return "cork"
