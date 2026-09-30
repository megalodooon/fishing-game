extends EventPickup
class_name ForageNode

# Something to gather on an island's ground: a shell bed, a berry bush, a pile
# of driftwood. Walking over it picks up one to three (more with the Foraging
# perk) and teaches Foraging. New spots every day (see EventDirector.forage).

const XP_EACH : float = 3.0


func collect() -> void:
	if not item or player.inventory.room_for(item) <= 0:
		return
	taken = 0.0
	var amount : int = randi_range(1, 3)
	var bonus : float = player.stat(&"forageBonus")
	while bonus > 0.0:
		if randf() * 100.0 < minf(bonus, 100.0):
			amount += 1
		bonus -= 100.0
	amount = mini(amount, player.inventory.room_for(item))
	player.inventory.give(item, amount)
	player.progress.pickups[key] = true
	player.progress.count("forage", amount)
	Skills.add(player, Skills.FORAGING, XP_EACH * amount * (1.0 + (item.rarity.difficulty if item.rarity else 0.0) * 3.0))
	player.say("+%d %s" % [amount, item.displayName], Color(0.8, 0.92, 0.6))
