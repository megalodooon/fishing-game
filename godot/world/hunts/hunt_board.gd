@tool
extends Counter
class_name HuntBoard

# Captain Grim's hunters' board in the harbor (see Hunts). Every family of
# sea creatures with its four tiers: what a tier costs and needs, how full
# the meter must get and what the boss pays. The hunt going on sits pinned
# on top, with its meter.

const GOOD : Color = Color(0.56, 0.93, 0.44)
const BAD : Color = Color(0.95, 0.38, 0.34)
const DIM : Color = Color(0.58, 0.67, 0.78)
const PRICE : Color = Color(1.0, 0.9, 0.4)


func intro_id() -> String:
	return "hunts"

func theme_name() -> String:
	return "cork"

func searchable() -> bool:
	return false

func subtitle(player : Player) -> String:
	return "Hunt levels raise fight damage: +%d%% so far" % roundi(Hunts.damage_bonus(player.progress))

func pinned_rows(player : Player) -> Array[Dictionary]:
	var hunt : Dictionary = Hunts.active(player.progress)
	if hunt.is_empty():
		return []
	var info_line : String = "Boss ready!" if hunt.boss else "%d/%d" % [hunt.meter, Hunts.METER[int(hunt.tier)]]
	return [{"value": &"active", "text": "%s %s" % [Hunts.FAMILIES[hunt.family][0], Hunts.ROMAN[int(hunt.tier)]], "detail": info_line, "detailColor": Hunts.COLOR if hunt.boss else PRICE, "marked": true, "markColor": Hunts.COLOR}]

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for id in Hunts.FAMILIES:
		var family : Array = Hunts.FAMILIES[id]
		var boss : SeaCreature = load(family[2]) as SeaCreature
		list.append({"header": true, "text": "%s (level %d)" % [family[0], Hunts.hunt_level(player.progress, id)]})
		for tier in range(1, 5):
			var why : String = Hunts.blocked(player, id, tier)
			var done : bool = Hunts.highest_done(player.progress, id) >= tier
			list.append({"value": [id, tier], "icon": boss.icon if boss else null, "tint": Color.WHITE if why.is_empty() or done else Color(0.3, 0.3, 0.35), "text": "Tier %s" % Hunts.ROMAN[tier], "detail": "$%s" % UiKit.coins_text(Hunts.COST[tier]), "detailColor": PRICE if why.is_empty() else DIM, "dim": not why.is_empty(), "marked": done, "markColor": GOOD})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	if value is StringName:
		var hunt : Dictionary = Hunts.active(player.progress)
		var going : Array = Hunts.FAMILIES[hunt.family]
		var hunted : SeaCreature = load(going[2]) as SeaCreature
		var text : String = "The %s is waiting for your bait somewhere out there." % hunted.displayName if hunt.boss else "Beat creatures of this family to fill the meter: %s." % ", ".join(creature_names(hunt.family))
		return {"title": "%s %s" % [going[0], Hunts.ROMAN[int(hunt.tier)]], "icon": hunted.icon, "color": going[4], "text": text, "lines": [["Meter", "%d/%d" % [mini(int(hunt.meter), Hunts.METER[int(hunt.tier)]), Hunts.METER[int(hunt.tier)]]]], "action": "Give up the hunt", "enabled": true}
	if not value is Array:
		return {}
	var id : String = value[0]
	var tier : int = value[1]
	var family : Array = Hunts.FAMILIES[id]
	var boss : SeaCreature = load(family[2]) as SeaCreature
	var part : Item = load(family[3]) as Item
	var lines : Array = [["Costs", "$%s" % UiKit.coins_text(Hunts.COST[tier]), GOOD if player.wallet.can_afford(Hunts.COST[tier]) else BAD], ["Hunting", "%d" % Hunts.HUNTING_NEEDED[tier], GOOD if Skills.level(player, Skills.HUNTING) >= Hunts.HUNTING_NEEDED[tier] else BAD], ["Meter to fill", "%d" % Hunts.METER[tier]], ["Boss", "%s %s" % [boss.displayName, Hunts.ROMAN[tier]] if boss else "?", family[4]], ["Pays", "%d Sea Essence" % Hunts.ESSENCE[tier], GOOD]]
	if part:
		lines.append(["And", "%s x%d" % [part.displayName, [0, 1, 2, 4, 8][tier]], GOOD])
	var why : String = Hunts.blocked(player, id, tier)
	return {"title": "%s %s" % [family[0], Hunts.ROMAN[tier]], "icon": boss.icon if boss else null, "color": family[4], "text": "Hunt: %s." % ", ".join(creature_names(id)), "lines": lines, "action": "Start the hunt" if why.is_empty() else why, "enabled": why.is_empty()}

func creature_names(family : String) -> PackedStringArray:
	var names : PackedStringArray = PackedStringArray()
	for creature in Catalog.creatures():
		if Hunts.family_of(creature) == family:
			names.append(creature.displayName)
	return names

func choose(player : Player, value : Variant) -> String:
	if value is StringName:
		Hunts.cancel(player)
		return ok("Hunt given up")
	if value is Array:
		if Hunts.start(player, value[0], value[1]):
			return ok("The hunt is on!")
		return fail(Hunts.blocked(player, value[0], value[1]))
	return ""
