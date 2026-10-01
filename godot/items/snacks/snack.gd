extends Item
class_name Snack

# Eaten by clicking with it held. Gives energy back for the day; it doesn't
# change bedtime. Some meals also buff a stat for a few hours: biteSpeed,
# castEnergy, walkSpeed or luck (rare fish).

# Food fills less than its number says, and every meal after the first in a
# day fills less again (down to FULL_FLOOR), so eating can't replace sleep.
const FOOD_SCALE : float = 0.6
const FULL_STEP : float = 0.2
const FULL_FLOOR : float = 0.4
const BUFF_NAMES : Dictionary = {&"biteSpeed": "Bite speed", &"castEnergy": "Cast energy", &"walkSpeed": "Walk speed", &"luck": "Rare fish"}

#------------------------#
@export var energy : float = 20.0
@export var eatColor : Color = Color(0.56, 0.93, 0.44)
@export var fullColor : Color = Color(0.82, 0.86, 0.92)

@export_group("Buff")
# biteSpeed, castEnergy, walkSpeed or luck. Empty for no buff.
@export var buffStat : String = ""
@export var buffAmount : float = 1.0
@export var buffHours : float = 4.0
#------------------------#


func use(player : Player) -> bool:
	if not player.energy or player.heldSlot < 0:
		return false
	var buffs : bool = not buffStat.is_empty()
	if player.energy.value >= player.energy.maximum and not buffs:
		player.say("not hungry", fullColor)
		return true
	player.inventory.take_one(player.heldSlot)
	var power : float = 1.0 + player.stat(&"potionPower" if category == "Potion" else &"foodPower") * 0.01
	var gain : float = energy * FOOD_SCALE * power * fullness(player, category != "Potion")
	# Brewer, fully grown: potions give some energy back too.
	if category == "Potion" and TideTree.has(player, "brewer"):
		gain += 10.0
	player.energy.add(gain)
	player.progress.count("meals")
	if buffs:
		player.progress.add_buff(StringName(buffStat), buffAmount, Progress.clock(player.get_tree()) + buffHours * power, icon)
		player.say("%s x%.2f!" % [BUFF_NAMES.get(StringName(buffStat), Stats.name_of(StringName(buffStat))), buffAmount], eatColor)
	else:
		player.say("+%d energy" % roundi(gain), eatColor)
	return true

# How much of a meal still fills today; eating counts it.
func fullness(player : Player, eat : bool) -> float:
	var cycle : DayNightCycle = DayNightCycle.find(player.get_tree())
	var day : int = cycle.day if cycle else 0
	var fed : Array = player.progress.get_flag("fed", [day, 0])
	var meals : int = fed[1] if fed[0] == day else 0
	if eat:
		player.progress.flags["fed"] = [day, meals + 1]
	return maxf(1.0 - FULL_STEP * meals, FULL_FLOOR)

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Energy", "+%d" % roundi(energy * FOOD_SCALE)])
	if not buffStat.is_empty():
		var shown : String = "x%.2f" % buffAmount if Stats.multiplies(StringName(buffStat)) else Stats.bonus_text(StringName(buffStat), (buffAmount - 1.0) * 100.0)
		lines.append_array([BUFF_NAMES.get(StringName(buffStat), Stats.name_of(StringName(buffStat))), "%s for %dh" % [shown, roundi(buffHours)]])
	lines.append_array(super())
	return lines

func default_type() -> String:
	return "Food" if category.is_empty() else category
