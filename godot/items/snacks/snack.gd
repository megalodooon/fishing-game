extends Item
class_name Snack

# Eaten by clicking with it held. Gives energy back for the day; it doesn't
# change bedtime. Some meals also buff a stat for a few hours: biteSpeed,
# castEnergy, walkSpeed or luck (rare fish).

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
	player.energy.add(energy * power)
	player.progress.count("meals")
	if buffs:
		player.progress.add_buff(StringName(buffStat), buffAmount, Progress.clock(player.get_tree()) + buffHours * power, icon)
		player.say("%s x%.2f!" % [BUFF_NAMES.get(StringName(buffStat), Stats.name_of(StringName(buffStat))), buffAmount], eatColor)
	else:
		player.say("+%d energy" % roundi(energy * power), eatColor)
	return true

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray(["Energy", "+%d" % roundi(energy)])
	if not buffStat.is_empty():
		var shown : String = "x%.2f" % buffAmount if Stats.multiplies(StringName(buffStat)) else Stats.bonus_text(StringName(buffStat), (buffAmount - 1.0) * 100.0)
		lines.append_array([BUFF_NAMES.get(StringName(buffStat), Stats.name_of(StringName(buffStat))), "%s for %dh" % [shown, roundi(buffHours)]])
	lines.append_array(super())
	return lines

func default_type() -> String:
	return "Food" if category.is_empty() else category
