extends RefCounted
class_name Unlocks

# The ways things open up besides the story: a skill level, the boat's hull,
# a tournament league or a progress flag. Places, recipes, shop stock and
# village projects all use the same checks and the same wording, so the game
# always says exactly what's still missing, like "Fishing 12" with "8/12".

const ROMAN : PackedStringArray = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII", "XXIII", "XXIV", "XXV", "XXVI", "XXVII", "XXVIII", "XXIX", "XXX", "XXXI", "XXXII", "XXXIII", "XXXIV", "XXXV", "XXXVI", "XXXVII", "XXXVIII", "XXXIX", "XL", "XLI", "XLII", "XLIII", "XLIV", "XLV", "XLVI", "XLVII", "XLVIII", "XLIX", "L"]
const LEAGUES : PackedStringArray = ["Village Cup", "Silver League", "Gold League", "Platinum League", "World Championship"]


static func roman(number : int) -> String:
	return ROMAN[number - 1] if number >= 1 and number <= ROMAN.size() else str(number)

# A skill's level from the progress alone, so resources can check without the player.
static func level(progress : Progress, skill : StringName) -> int:
	return Skills.level_of(skill, progress.skills.get(skill, 0.0)) if progress else 1

static func skill_met(progress : Progress, skill : StringName, needed : int) -> bool:
	return skill.is_empty() or needed <= 1 or level(progress, skill) >= needed

# What's missing for a skill level, as the label and how far along it is.
static func skill_need(progress : Progress, skill : StringName, needed : int) -> PackedStringArray:
	return PackedStringArray(["%s %d" % [Skills.NAMES.get(skill, String(skill).capitalize()), needed], "Lv %d/%d" % [level(progress, skill), needed]])

static func league_met(progress : Progress, needed : int) -> bool:
	return needed <= 0 or (progress != null and progress.league >= needed)

static func league_need(needed : int) -> PackedStringArray:
	return PackedStringArray(["Win the %s" % LEAGUES[clampi(needed - 1, 0, LEAGUES.size() - 1)], "Tournaments"])

# A short line for tooltips and locked cards, like "Needs Fishing 12".
static func needs_text(needs : Array[PackedStringArray]) -> String:
	var parts : PackedStringArray = PackedStringArray()
	for need in needs:
		parts.append(need[0])
	return "Needs " + ", ".join(parts) if not parts.is_empty() else ""
