extends Resource
class_name Quest

# A job from someone around the world: taken at their quest board, done by
# meeting its goals and handed in back there for the rewards. Story quests
# lead the way through the game, the rest are side jobs.

#------------------------#
@export var title : String = ""
@export var giver : String = ""
@export_multiline var description : String = ""
@export var story : bool = false
@export var goals : Array[QuestGoal] = []
# Handing it in moves the story to this chapter (see Story). -1 leaves it.
@export var chapter : int = -1
# Dialogue scenes (see Dialogue) played when it's taken and handed in.
@export var startScene : String = ""
@export var endScene : String = ""
# Offered once these are handed in.
@export var requires : Array[Quest] = []
# And once this progress flag is set, when not empty.
@export var requiredFlag : String = ""
# And once a skill is high enough, so side jobs trickle in as the player grows.
@export var requiredSkill : StringName = &""
@export var requiredLevel : int = 0
# And once the player is this friendly with someone (a Cast id), for the
# favors friends ask.
@export var heartsWith : String = ""
@export var requiredHearts : int = 0

@export_group("Rewards")
@export var rewardCoins : int = 0
@export var rewardItems : Array[Item] = []
@export var rewardAmounts : Array[int] = []
# Opened on the sea chart for free.
@export var unlocks : Array[Location] = []
# An extra line for rewards that aren't items, like a shop opening up.
@export var rewardText : String = ""
#------------------------#


func key() -> String:
	return "quest/" + resource_path.get_file().get_basename()

func available(player : Player) -> bool:
	if player.progress.quest_started(self):
		return false
	for quest in requires:
		if quest and not player.progress.quest_done(quest):
			return false
	if not Unlocks.skill_met(player.progress, requiredSkill, requiredLevel):
		return false
	if requiredHearts > 0 and Friendship.hearts(player.progress, heartsWith) < requiredHearts:
		return false
	return requiredFlag.is_empty() or player.progress.has_flag(requiredFlag)

func goal_progress(player : Player, index : int) -> int:
	return goals[index].progress(player, player.progress.quest_count(self, index))

func ready(player : Player) -> bool:
	if not player.progress.quest_active(self):
		return false
	for i in goals.size():
		if goal_progress(player, i) < goals[i].needed():
			return false
	return true

# The first goal still open, for the HUD.
func next_goal(player : Player) -> int:
	for i in goals.size():
		if goal_progress(player, i) < goals[i].needed():
			return i
	return -1

func reward_lines() -> Array:
	var lines : Array = []
	if rewardCoins > 0:
		lines.append(["Reward", "$%d" % rewardCoins])
	for i in rewardItems.size():
		if rewardItems[i]:
			var count : int = rewardAmounts[i] if i < rewardAmounts.size() else 1
			lines.append(["Reward", rewardItems[i].displayName if count <= 1 else "%s x%d" % [rewardItems[i].displayName, count]])
	for location in unlocks:
		if location:
			lines.append(["Opens", location.displayName])
	if not rewardText.is_empty():
		lines.append([rewardText, ""])
	return lines

# Takes the delivered items and pays out. Returns whether it went through.
func turn_in(player : Player) -> bool:
	if not ready(player):
		return false
	for i in rewardItems.size():
		if rewardItems[i] and not Counter.fits(player, rewardItems[i], rewardAmounts[i] if i < rewardAmounts.size() else 1):
			return false
	for goal in goals:
		if goal.kind == QuestGoal.Kind.DELIVER:
			player.inventory.take_where(goal.fits_item, goal.amount)
	for i in rewardItems.size():
		if rewardItems[i]:
			Counter.deliver(player, rewardItems[i], rewardAmounts[i] if i < rewardAmounts.size() else 1)
	if rewardCoins > 0:
		player.wallet.add(shared_coins(rewardCoins))
	for location in unlocks:
		if location and not player.atlas.is_unlocked(location):
			player.atlas.unlocked.append(location)
			player.atlas.emit_changed()
	player.progress.finish_quest(self)
	if chapter > player.progress.chapter:
		player.progress.chapter = chapter
		player.progress.emit_changed()
	return true

# With a friend in the world, quests are shared and so are their coins: each
# player gets this many (see NetSession.on_quest).
static func shared_coins(coins : int) -> int:
	return ceili(coins * NetSession.QUEST_COIN_SHARE) if Net.has_company() else coins

# Something happened that quests might count: a catch, a sale, a trip, a
# craft, a harvest, a gathering. Contests and achievements hear it too.
static func notify(player : Player, event : StringName, data : Variant = null, extra : Variant = null) -> void:
	if not player or not player.progress:
		return
	Contests.notify(player, event, data, extra)
	Hunts.notify(player, event, data)
	Achievements.notify(player, event, data, extra)
	for quest in player.progress.active_quests():
		var wasReady : bool = quest.ready(player)
		for i in quest.goals.size():
			var goal : QuestGoal = quest.goals[i]
			var added : int = goal.count_event(event, data, extra) if goal else 0
			if added > 0 and player.progress.quest_count(quest, i) < goal.amount:
				player.progress.add_quest_count(quest, i, added)
		if not wasReady and quest.ready(player):
			var board : NoticeBoard = NoticeBoard.find(player.get_tree())
			if board:
				board.post("Quest ready!", "%s: go back to %s." % [quest.title, quest.giver], Color(0.56, 0.93, 0.44))
