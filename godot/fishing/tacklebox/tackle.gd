extends Item
class_name Tackle

enum Kind { BOBBER, LINE, HOOK, TECH, BAIT }
const KIND_NAMES : PackedStringArray = ["Bobber", "Line", "Hook", "Tech", "Bait"]
# Every rod needs one of each of these on at all times.
const REQUIRED : Array[Kind] = [Kind.BOBBER, Kind.LINE, Kind.HOOK]

#------------------------#
@export var kind : Kind = Kind.BOBBER
@export var tint : Color = Color.WHITE
# Swaps the rod's bobber when set.
@export var bobberScene : PackedScene
# Recolors the rod's line when its alpha is above 0.
@export var lineColor : Color = Color(0.0, 0.0, 0.0, 0.0)

@export_group("Stats")
@export var rangeBonus : float = 0.0
@export var castTimeBonus : float = 0.0
@export_range(0.1, 4.0, 0.05, "or_greater", "suffix:x") var biteSpeed : float = 1.0
@export var hookWindowBonus : float = 0.0
# Taken off the rarity difficulty of every catch minigame.
@export_range(0.0, 1.0) var control : float = 0.0
@export_range(0.1, 4.0, 0.05, "or_greater", "suffix:x") var reelSpeed : float = 1.0
@export_range(0.1, 4.0, 0.05, "or_greater", "suffix:x") var spotSize : float = 1.0
@export_range(0.1, 4.0, 0.05, "or_greater", "suffix:x") var spotTime : float = 1.0
#------------------------#


# Lines show their line color on the icon, everything else its tint.
func icon_tint() -> Color:
	return Color(lineColor, 1.0) if kind == Kind.LINE and lineColor.a > 0.0 else tint

func details() -> PackedStringArray:
	var lines : PackedStringArray = PackedStringArray()
	mod(lines, "Range", rangeBonus, 0.0, "%+d" % roundi(rangeBonus))
	mod(lines, "Cast time", castTimeBonus, 0.0, "%+.1fs" % castTimeBonus)
	mod(lines, "Bite speed", biteSpeed, 1.0, "x%.2f" % biteSpeed)
	mod(lines, "Hook window", hookWindowBonus, 0.0, "%+.1fs" % hookWindowBonus)
	mod(lines, "Control", control, 0.0, "+%d%%" % roundi(control * 100.0))
	mod(lines, "Reel speed", reelSpeed, 1.0, "x%.2f" % reelSpeed)
	mod(lines, "Spot size", spotSize, 1.0, "x%.2f" % spotSize)
	mod(lines, "Spot time", spotTime, 1.0, "x%.2f" % spotTime)
	return lines

func mod(lines : PackedStringArray, label : String, value : float, neutral : float, text : String) -> void:
	if not is_equal_approx(value, neutral):
		lines.append_array([label, text])

func default_type() -> String:
	return KIND_NAMES[kind]

# "Common Bobber" or "Rare Hook", whatever the category says.
func type_name() -> String:
	return KIND_NAMES[kind]
