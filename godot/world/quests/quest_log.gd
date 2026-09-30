@tool
extends Counter
class_name QuestLog

# The player's own list of quests, opened with Q or from the pause menu. It
# isn't in the world, so it never shows up as something to use with F.
# Picking a quest going pins it to the HUD.

const LOG_GROUP : StringName = &"quest_logs"

#------------------------#


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(LOG_GROUP)

static func find(tree : SceneTree) -> QuestLog:
	return tree.get_first_node_in_group(LOG_GROUP) as QuestLog

func available(_player : Player) -> bool:
	return false

func tabs(_player : Player) -> PackedStringArray:
	return PackedStringArray(["Going", "Done"])

func subtitle(player : Player) -> String:
	var going : int = player.progress.active_quests().size()
	return "%d quest%s going. Pick one to show it on screen." % [going, "" if going == 1 else "s"] if tab == 0 else "Finished jobs"

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for quest : Quest in player.progress.quests:
		var done : bool = player.progress.quest_done(quest)
		if done != (tab == 1):
			continue
		if done:
			list.append({"value": quest, "text": quest.title, "detail": "Done", "detailColor": QuestBoard.DIM_COLOR})
		else:
			var handIn : bool = quest.ready(player)
			list.append({"value": quest, "text": quest.title, "detail": "Hand in" if handIn else QuestBoard.progress_text(player, quest), "detailColor": QuestBoard.READY_COLOR if handIn else QuestBoard.DIM_COLOR, "marked": player.progress.tracked == quest})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var quest : Quest = value as Quest
	if not quest:
		return {"title": "No quests", "text": "Find jobs on the notice board in the village square, and from people on the islands." if tab == 0 else "Nothing finished yet.", "lines": []}
	var details : Dictionary = QuestBoard.quest_info(player, quest)
	if player.progress.quest_active(quest):
		details.lines.append(["Hand in to", quest.giver])
		details.action = "Shown on screen" if player.progress.tracked == quest else "Show on screen"
		details.enabled = player.progress.tracked != quest
	return details

func choose(player : Player, value : Variant) -> String:
	var quest : Quest = value as Quest
	if quest and player.progress.quest_active(quest):
		player.progress.tracked = quest
		player.progress.emit_changed()
		return ok("Tracking %s" % quest.title)
	return ""

func hub_open() -> void:
	open_log(Player.find(get_tree()))

func hub_close() -> void:
	var menu : CounterUI = CounterUI.find(get_tree())
	if menu and menu.counter == self:
		menu.close()

func hub_shown() -> bool:
	var menu : CounterUI = CounterUI.find(get_tree())
	return menu != null and menu.shown and menu.counter == self

func hub_news() -> bool:
	var player : Player = Player.find(get_tree())
	if not player:
		return false
	for quest in player.progress.active_quests():
		if quest.ready(player):
			return true
	return false

func open_log(player : Player) -> void:
	var menu : CounterUI = CounterUI.find(get_tree())
	if menu:
		menu.open_counter(self, player)

func theme_name() -> String:
	return "paper"
