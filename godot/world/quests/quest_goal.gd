extends Resource
class_name QuestGoal

# One thing a quest asks for. Catch, sell, visit and craft goals count up as
# they happen after the quest is taken. Deliver goals look in the bag and take
# the items at the end, flag, tank, skill and boat goals just have to be true.

enum Kind { CATCH, SELL, DELIVER, VISIT, FLAG, TANK, CRAFT, BEAT, SKILL, BOAT, COUNTER }

#------------------------#
@export var kind : Kind = Kind.CATCH
# Catch and deliver: a FishData, a Rarity, a Biome (catch only) or an Item.
# Visit: a Location. Tank: an AquariumTank. Craft: an Item. Beat: a SeaCreature.
# Empty means any.
@export var target : Resource
# Catch only: the weather it has to be caught in. -1 is any weather.
@export var weather : int = -1
# Flag goals: the progress flag. Skill goals: the skill (like "fishing").
# Boat goals: the part (like "hull"). Counter goals: a Progress counter,
# like "pearls" or "tournaments" (give them a text).
@export var flag : String = ""
# Coins for sell goals.
@export var amount : int = 1
# Shown instead of the made up description.
@export var text : String = ""
#------------------------#


func describe() -> String:
	if not text.is_empty():
		return text
	var what : String = target_name()
	match kind:
		Kind.CATCH:
			var weatherText : String = "" if weather < 0 else " in %s" % Weather.NAMES[weather].to_lower()
			return "Catch %d %s%s" % [amount, what if target else "fish", weatherText]
		Kind.SELL:
			return "Sell $%d of goods" % amount
		Kind.DELIVER:
			return "Bring %d %s" % [amount, what]
		Kind.VISIT:
			return "Sail to %s" % what
		Kind.TANK:
			return "Restore the %s" % what
		Kind.CRAFT:
			return "Make %d %s" % [amount, what if target else "things"]
		Kind.BEAT:
			if not target:
				return "Beat a sea creature" if amount == 1 else "Beat %d sea creatures" % amount
			return "Beat %d %s" % [amount, what]
		Kind.SKILL:
			return "Reach %s level %d" % [Skills.NAMES.get(StringName(flag), flag), amount]
		Kind.BOAT:
			return "Build the %s" % BoatParts.tier_name(StringName(flag), amount)
		Kind.COUNTER:
			return "%s: %d" % [flag.capitalize(), amount]
	return flag

func target_name() -> String:
	if target is FishData:
		return (target as FishData).displayName
	if target is Rarity:
		return (target as Rarity).displayName.to_lower() + " fish"
	if target is Biome:
		return "fish in " + (target as Biome).displayName
	if target is Item:
		return (target as Item).displayName
	if target is Location:
		return (target as Location).displayName
	if target is AquariumTank:
		return (target as AquariumTank).displayName
	if target is SeaCreature:
		return (target as SeaCreature).displayName
	return ""

# How much an event moves this goal along.
func count_event(event : StringName, data : Variant, extra : Variant) -> int:
	match kind:
		Kind.CATCH:
			if event == &"catch" and fits_fish(data as Fish, extra as Biome) and (weather < 0 or Weather.now_state(Engine.get_main_loop() as SceneTree) == weather):
				return 1
		Kind.SELL:
			if event == &"sell":
				return data
		Kind.VISIT:
			if event == &"visit" and data == target:
				return 1
		Kind.CRAFT:
			if event == &"craft" and (target == null or (data as Item).same_kind(target as Item)):
				return extra
		Kind.BEAT:
			if event == &"beat" and (target == null or data == target):
				return 1
	return 0

func fits_fish(fish : Fish, where : Biome) -> bool:
	if not fish:
		return false
	if target == null:
		return true
	if target is FishData:
		return fish.species == target
	if target is Rarity:
		return fish.rarity == target
	if target is Biome:
		return where != null and where.journal_page() == (target as Biome).journal_page()
	return false

func fits_item(item : Item) -> bool:
	if target is Item:
		return item.same_kind(target as Item)
	return item is Fish and fits_fish(item as Fish, null)

# How far along it is, out of needed().
func progress(player : Player, counted : int) -> int:
	match kind:
		Kind.DELIVER:
			return mini(player.inventory.count_where(fits_item), amount)
		Kind.FLAG:
			return 1 if player.progress.has_flag(flag) else 0
		Kind.TANK:
			return 1 if player.progress.tank_done(target as AquariumTank) else 0
		Kind.SKILL:
			return mini(Skills.level(player, StringName(flag)), amount)
		Kind.BOAT:
			return mini(BoatParts.tier(player.progress, StringName(flag)), amount)
		Kind.COUNTER:
			return mini(player.progress.counter(flag), amount)
	return mini(counted, amount)

func needed() -> int:
	return 1 if kind == Kind.FLAG or kind == Kind.TANK else amount
