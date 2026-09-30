@tool
extends Counter
class_name PetShop

# Sells pets. Picking a pet you own sends it out with you (only one at a
# time), picking the one that's out sends it back home.

#------------------------#
@export var pets : Array[PetData] = []
@export var outColor : Color = Color(0.56, 0.93, 0.44)
#------------------------#


func interact(player : Player) -> void:
	var screen : PetsUI = PetsUI.find(get_tree())
	if screen:
		screen.open_shop(self, player)
	else:
		super(player)

func subtitle(player : Player) -> String:
	var active : PetData = player.progress.activePet
	return "%s is with you" % active.displayName if active else "Pets follow you and help out"

func rows(player : Player) -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for pet in pets:
		if not pet:
			continue
		var owned : bool = player.progress.pets.has(pet)
		var out : bool = player.progress.activePet == pet
		var detail : String = "Here" if out else ("Lv %d" % player.progress.pet_level(pet) if owned else "$%d" % pet.price)
		var color : Color = outColor if out else (Color(0.58, 0.67, 0.78) if owned else (Color(1.0, 0.9, 0.4) if player.wallet.can_afford(pet.price) else Color(0.95, 0.38, 0.34)))
		list.append({"value": pet, "icon": pet.sprite, "text": pet.displayName, "detail": detail, "detailColor": color, "marked": out})
	return list

func info(player : Player, value : Variant) -> Dictionary:
	var pet : PetData = value as PetData
	if not pet:
		return {}
	var owned : bool = player.progress.pets.has(pet)
	var level : int = player.progress.pet_level(pet) if owned else 1
	var lines : Array = [["Moves", "Flies" if pet.flies else "Walks"]]
	if owned:
		var catches : int = player.progress.pet_catches(pet)
		lines.append(["Level", "%d/%d" % [level, pet.max_level()]])
		if level < pet.max_level():
			lines.append(["Next level", "%d/%d fish" % [catches, pet.levelCatches[level - 1]]])
	lines.append_array(pet.buff_lines(level))
	if not owned:
		lines.append(["Price", "$%d" % pet.price])
	var action : String = "Click to buy"
	var enabled : bool = true
	if player.progress.activePet == pet:
		action = "Click to send home"
	elif owned:
		action = "Click to take along"
	elif not player.wallet.can_afford(pet.price):
		action = "Not enough coins"
		enabled = false
	return {"title": pet.displayName, "icon": pet.sprite, "text": pet.description, "lines": lines, "action": action, "enabled": enabled}

func choose(player : Player, value : Variant) -> String:
	var pet : PetData = value as PetData
	if not pet:
		return ""
	if player.progress.activePet == pet:
		player.progress.set_active_pet(null)
		return ok("%s went home" % pet.displayName)
	if player.progress.pets.has(pet):
		player.progress.set_active_pet(pet)
		return ok("%s is with you!" % pet.displayName)
	if not player.wallet.spend(pet.price):
		return fail("Not enough coins")
	player.progress.pets.append(pet)
	player.progress.set_active_pet(pet)
	return ok("%s is yours!" % pet.displayName)

func theme_name() -> String:
	return "wood"
