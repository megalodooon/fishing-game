extends State
class_name PlayerCatchState

# Brings in whatever took the bait, one line after the other. A bite can be a
# sea creature (Sea creature chance stat), junk (the sea's junk chance) or a
# fish. Fish play a catch minigame: everyday games, the rarer ones for rarer
# fish, and boss fights for trophies. Sea creatures always fight. Landing a
# catch pays Fishing XP, fills the journal and collections, can bring up a
# second fish (Double catch) and a treasure chest (Treasure chance).

# Junk comes up this much less often than a sea lists, so the bag stays clear.
const JUNK_SCALE : float = 0.5
const RARITY_XP : Dictionary = {"Common": 6.0, "Uncommon": 14.0, "Rare": 35.0, "Legendary": 90.0, "Trophy": 300.0}

#------------------------#
@onready var player : Player = owner
@onready var reel : PlayerReelState = %Reel
@onready var catchText : Callout = %CatchText
@onready var catchSprite : Sprite2D = %CatchSprite

@export var minigames : Array[PackedScene] = []
# Games saved for bigger fights, picked for a fish by its rarity's chance below.
@export var rareMinigames : Array[PackedScene] = []
@export var rareGameChance : Dictionary[Rarity, float] = {}
# Boss fights: always for sea creatures, and for fish by their rarity's chance.
@export var bossMinigames : Array[PackedScene] = []
@export var bossChance : Dictionary[Rarity, float] = {}
@export_range(0.0, 1.0) var hookSplash : float = 0.8
@export_range(0.0, 0.5) var difficultyJitter : float = 0.05
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var fightAngle : float = deg_to_rad(-5.0)
@export var fightOffset : Vector2 = Vector2(0.0, -0.5)

@export_group("Result")
@export var textOffset : Vector2 = Vector2(0.0, -12.0)
@export var textTime : float = 1.6
@export var escapeText : String = "escaped"
@export var escapeColor : Color = Color(0.82, 0.86, 0.92)
@export var fullText : String = "bag full"
@export var fullColor : Color = Color(0.95, 0.38, 0.34)
@export var treasureColor : Color = Color(1.0, 0.86, 0.36)
@export var creatureColor : Color = Color(1.0, 0.45, 0.4)
# Put in front of a fish's name the first time one is caught.
@export var newText : String = "New! "
@export var jumpTime : float = 0.5
@export var jumpHeight : float = 16.0
@export var resultGap : float = 0.3

var fish : Fish
var creature : SeaCreature
var minigame : Minigame
# The line that got the bite, set by the fishing state. Every other line in
# the water brings in a catch too, one minigame after the other.
var line : FishingRod
var queue : Array[FishingRod] = []
var hookedSpot : FishingSpot
# Where the catch on the line now came from, and its biome, kept separately
# since the spot can expire and be freed while the minigame runs.
var fishSpot : FishingSpot
var fishBiome : Biome
var total : int = 0
var results : Array[Dictionary] = []
var side : float = 1.0
var elapsed : float = 0.0
#------------------------#


func _ready() -> void:
	catchText.warm_up("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.!")

func enter() -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	if not is_instance_valid(line):
		line = rod
	line.bobber.splash(hookSplash)
	player.stop_pose()
	elapsed = 0.0
	hookedSpot = line.castSpot
	queue = [line]
	for each in rod.line_rods():
		if each != line and each.mode == FishingRod.Mode.WATER:
			queue.append(each)
	total = queue.size()
	results = []
	next_fish()

func exit() -> void:
	if minigame and not minigame.done:
		minigame.queue_free()
	minigame = null
	creature = null
	line = null
	queue.clear()
	player.minigameScreen.close_menu()

func biome_of(spot : FishingSpot) -> Biome:
	return spot.biome if is_instance_valid(spot) and spot.biome else Ocean.current_biome(get_tree())

# Starts the minigame for the next line. Lines outside a fishing spot fish from
# the spot the bite came from.
func next_fish() -> void:
	while not queue.is_empty():
		line = queue.pop_front()
		# Either spot can have expired during an earlier line's minigame.
		var spot : FishingSpot = null
		if is_instance_valid(line.castSpot):
			spot = line.castSpot
		elif is_instance_valid(hookedSpot):
			spot = hookedSpot
		fishSpot = spot
		if not spot:
			continue
		if not player.inventory.has_space():
			player.inventory.needs_room.emit()
			results.append({"text": fullText, "color": fullColor})
			break
		var context : FishingContext = FishingContext.make(player, line, spot)
		var biome : Biome = biome_of(spot)
		fishBiome = biome
		var caption : String = "Fish %d of %d" % [total - queue.size(), total] if total > 1 else ""
		var events : Array[GameEvent] = EventDirector.active(get_tree())
		var creatures : Array[SeaCreature] = biome.creatures.duplicate() if biome else []
		for event in events:
			creatures.append_array(event.creatures)
		var hunted : SeaCreature = Hunts.boss_bite(player)
		if hunted:
			creature = hunted
			var boss_scene : PackedScene = hunted.fight if hunted.fight else bossMinigames.pick_random()
			start(boss_scene, hunted.difficulty, 0.5, Hunts.COLOR, hunted.icon, hunted.style, hunted.toughness, hunted.announce)
			return
		if not creatures.is_empty() and randf() * 100.0 < player.stat(&"seaCreature"):
			creature = SeaCreature.roll(creatures, context, Skills.level(player, Skills.FISHING))
			if creature:
				var scene : PackedScene = creature.fight if creature.fight else bossMinigames.pick_random()
				start(scene, creature.difficulty, 0.5, creature.rarity.color if creature.rarity else creatureColor, creature.icon, creature.style, creature.toughness, creature.announce if not creature.announce.is_empty() else "A %s appears!" % creature.displayName)
				return
		if biome and not biome.junk.is_empty() and randf() < biome.junkChance * JUNK_SCALE:
			var junk : Item = biome.junk.pick_random()
			if junk and player.inventory.give(junk, 1) == 0:
				player.progress.count("junk")
				if junk.resource_path.ends_with("old_boot.tres"):
					player.progress.count("boots")
				Quest.notify(player, &"junk", junk)
				results.append({"icon": junk.icon, "text": junk.displayName, "color": Color(0.7, 0.72, 0.62), "from": line.get_bobber_point()})
			continue
		var data : FishData = null
		for event in events:
			if event.page and randf() < event.fishChance:
				data = FishData.roll(event.page.fish, context)
				if data:
					fishBiome = event.page
					break
		if not data:
			data = crown_fish(spot, context)
		if not data:
			data = spot.take_fish(context)
		if not data:
			continue
		fish = Fish.caught(data, player.stat(&"weight") * 0.01, 1.0 + player.stat(&"variantLuck") * 0.01)
		var games : Array[PackedScene] = data.minigames if not data.minigames.is_empty() else pick_games(data)
		if games.is_empty():
			continue
		var rod : FishingRod = player.heldItem as FishingRod
		start(games.pick_random(), data.difficulty() - rod.control(), fish.heft(), fish.title_color(), fish.icon, data.style, 1.0, caption)
		return
	celebrate(results.duplicate())
	stateMachine.change_state(reel)

func start(scene : PackedScene, difficulty : float, heft : float, color : Color, icon : Texture2D, style : StringName, toughness : float, caption : String) -> void:
	minigame = scene.instantiate()
	minigame.finished.connect(on_finished)
	minigame.tugged.connect(line.bobber.splash)
	# Monster Lure, fully grown: a heart more against sea creatures.
	minigame.hearts = roundi(player.stat(&"hearts")) + (1 if creature and TideTree.has(player, "monster_lure") else 0)
	minigame.power = 1.0 + player.stat(&"damage") * 0.01
	minigame.style = style
	minigame.toughness = toughness
	player.minigameScreen.caption = caption
	player.minigameScreen.play(minigame)
	var control : float = player.stat(&"control") * 0.01
	minigame.begin(difficulty - control + randf_range(-difficultyJitter, difficultyJitter), heft, color, icon)
	# A friend nearby can jump in and help with a creature.
	var session : NetSession = NetSession.find(get_tree())
	if session and creature and minigame is BossMinigame:
		session.fight_started(creature, minigame)

func pick_games(data : FishData) -> Array[PackedScene]:
	if data and data.rarity and not bossMinigames.is_empty() and randf() < bossChance.get(data.rarity, 0.0):
		return bossMinigames
	if data and data.rarity and not rareMinigames.is_empty() and randf() < rareGameChance.get(data.rarity, 0.0):
		return rareMinigames
	return minigames

func update_physics(delta : float) -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	for each in rod.line_rods():
		each.floatTime = 0.0
	player.aimTarget = line.get_bobber_point()
	elapsed += delta
	var weight : float = 1.0 - exp(-reel.followSpeed * delta)
	var pulling : bool = minigame != null and minigame.holding
	var crank : Vector2 = Vector2.from_angle(elapsed * reel.crankSpeed) * reel.crankRadius
	player.poseAngle = lerpf(player.poseAngle, reel.reelAngle if pulling else fightAngle, weight)
	player.poseOffset = player.poseOffset.lerp(reel.reelOffset + crank if pulling else fightOffset, weight)

func on_finished(caught : bool) -> void:
	var gaveUp : bool = minigame.gaveUp
	minigame = null
	if creature:
		finish_fight(caught)
	elif caught and fish:
		land(fish)
	else:
		results.append({"text": escapeText, "color": escapeColor})
	fish = null
	creature = null
	if gaveUp:
		queue.clear()
	next_fish()

# Heart of the Sea, fully grown: once a day a perfect cast hooks a rare fish
# or better, when the spot has one that bites now.
func crown_fish(spot : FishingSpot, context : FishingContext) -> FishData:
	var cycle : DayNightCycle = DayNightCycle.find(get_tree())
	if not cycle or not is_instance_valid(line) or line.castScore < FishingSpot.MAX_SCORE or not TideTree.has(player, "crown") or player.progress.get_flag("crown", -1) == cycle.day:
		return null
	var rare : Array[FishData] = []
	for data in spot.fish:
		if data.rarity and not data.rarity.displayName in ["Common", "Uncommon"] and data.can_bite(context):
			rare.append(data)
	if rare.is_empty():
		return null
	player.progress.set_flag("crown", cycle.day)
	return rare.pick_random()

func fish_xp(caught : Fish, biome : Biome) -> float:
	var base : float = RARITY_XP.get(caught.rarity.displayName if caught.rarity else "Common", 6.0)
	return base * (1.0 + (biome.tier if biome else 0) * 0.5) * (1.5 if caught.variant != Fish.NORMAL else 1.0)

func land(caught : Fish) -> void:
	if player.inventory.add(caught) < 0:
		results.append({"text": fullText, "color": fullColor})
		return
	var where : Biome = fishBiome
	# Where results fly up from: the bobber, or the player when there's no line.
	var from : Vector2 = line.get_bobber_point() if is_instance_valid(line) else player.global_position
	var first : bool = player.journal.record(caught, where) if player.journal else false
	use_bait()
	grow_pet()
	# Scholar, fully grown: a species never caught before gives triple XP.
	Skills.add(player, Skills.FISHING, fish_xp(caught, where) * (3.0 if first and TideTree.has(player, "scholar") else 1.0))
	Collections.check(player, caught.species)
	player.progress.count("fish_caught")
	if caught.variant != Fish.NORMAL:
		player.progress.count("variant_" + Fish.VARIANT_NAMES[caught.variant].to_lower())
		player.progress.set_flag("variant/%s/%d" % [caught.species.resource_path.get_file().get_basename(), caught.variant])
	Quest.notify(player, &"catch", caught, where)
	player.fish_caught.emit(caught, where)
	results.append({"icon": caught.icon, "text": "%s%s %s" % [newText if first else "", caught.displayName, caught.weight_text()], "color": Fish.VARIANT_COLORS[caught.variant] if caught.variant != Fish.NORMAL else caught.title_color(), "from": from})
	if randf() * 100.0 < player.stat(&"doubleCatch") and player.inventory.has_space():
		# Double Hook, fully grown: half the time the second fish is another one from the spot.
		var other : FishData = null
		if TideTree.has(player, "double_hook") and is_instance_valid(fishSpot) and randf() < 0.5:
			other = FishData.roll(fishSpot.fish, FishingContext.make(player, line, fishSpot))
		var twin : Fish = Fish.caught(other if other else caught.species, player.stat(&"weight") * 0.01)
		if player.inventory.add(twin) >= 0:
			player.journal.record(twin, where)
			Skills.add(player, Skills.FISHING, fish_xp(twin, where))
			player.progress.count("fish_caught")
			player.fish_caught.emit(twin, where)
			results.append({"icon": twin.icon, "text": "Double catch! %s" % twin.weight_text(), "color": Color(0.56, 0.93, 0.44), "from": from})
	for event in EventDirector.active(get_tree()):
		for found in event.roll_drops(player.stat(&"luck")):
			if player.inventory.give(found, 1) == 0:
				results.append({"icon": found.icon, "text": found.displayName, "color": event.color, "from": from})
	for rare in RareDrops.roll(player, where):
		if Counter.fits(player, rare, 1):
			Counter.deliver(player, rare, 1)
			player.progress.count("rare_drops")
			results.append({"icon": rare.icon, "text": "RARE DROP! %s" % rare.displayName, "color": RareDrops.COLOR, "from": from})
			var board : NoticeBoard = NoticeBoard.find(get_tree())
			if board:
				board.post("RARE DROP!", "%s came up with the catch." % rare.displayName, RareDrops.COLOR, rare.icon)
	var context : FishingContext = FishingContext.make(player, line, fishSpot if is_instance_valid(fishSpot) else null)
	var trophy : Item = TrophyFishing.roll(player, context, where)
	if trophy:
		results.append({"icon": trophy.icon, "text": "TROPHY! %s" % trophy.displayName, "color": Color(1.0, 0.82, 0.3), "from": from})
	if randf() * 100.0 < player.stat(&"treasure"):
		var chest : TreasureChest = TreasureChest.pick(where.tier if where else 0, player.stat(&"luck"))
		if chest and player.inventory.give(chest, 1) == 0:
			player.progress.count("treasure_found")
			results.append({"icon": chest.icon, "text": "Treasure! %s" % chest.displayName, "color": treasureColor, "from": from})

func finish_fight(won : bool) -> void:
	if Hunts.is_boss(creature):
		Hunts.boss_fought(player, won)
		# The bestiary and collections count the boss itself, not the tougher
		# copy made for this fight.
		creature = Hunts.bossBase
	if not won:
		results.append({"text": "%s got away" % creature.displayName, "color": escapeColor})
		return
	pay_out(player, creature)
	use_bait()
	results.append({"icon": creature.icon, "text": "Beat the %s!" % creature.displayName, "color": creature.rarity.color if creature.rarity else creatureColor, "from": line.get_bobber_point()})

# A beaten creature's loot, XP and bestiary entry, for whoever fought it (both
# players after a co-op fight).
static func pay_out(who : Player, beaten : SeaCreature) -> void:
	var coins : int = randi_range(beaten.coins.x, beaten.coins.y)
	who.wallet.add(coins)
	var names : PackedStringArray = PackedStringArray(["$%d" % coins])
	for pair in beaten.roll_drops(who.stat(&"luck")):
		if Counter.fits(who, pair[0], pair[1]):
			Counter.deliver(who, pair[0], pair[1])
			names.append(pair[0].displayName if pair[1] <= 1 else "%s x%d" % [pair[0].displayName, pair[1]])
	who.progress.bestiary[beaten] = who.progress.bestiary.get(beaten, 0) + 1
	who.progress.count("creatures")
	# Sea Essence for enchanting, more from tougher creatures.
	var essence : Item = load(Enchanting.ESSENCE) as Item
	var essenceAmount : int = maxi(ceili(beaten.xp / 50.0), 1)
	if essence and Counter.fits(who, essence, essenceAmount):
		Counter.deliver(who, essence, essenceAmount)
		names.append("%d Sea Essence" % essenceAmount)
	Skills.add(who, Skills.HUNTING, beaten.xp)
	Skills.add(who, Skills.FISHING, beaten.xp * 0.5)
	Collections.check(who, beaten)
	Quest.notify(who, &"beat", beaten)
	var board : NoticeBoard = NoticeBoard.find(who.get_tree())
	if board:
		board.post("%s defeated!" % beaten.displayName, "Loot: " + ", ".join(names), beaten.rarity.color if beaten.rarity else Color(1.0, 0.45, 0.4), beaten.icon)

# The pet that's out levels up with the fish caught.
func grow_pet() -> void:
	if player.progress and player.progress.pet_caught():
		var board : NoticeBoard = NoticeBoard.find(get_tree())
		var pet : PetData = player.progress.activePet
		if board:
			board.post("%s grew!" % pet.displayName, "Level %d: its buffs got stronger." % player.progress.pet_level(pet), Color(0.56, 0.93, 0.44))

# Every catch landed uses up one of each bait on the rod.
func use_bait() -> void:
	var rod : FishingRod = player.heldItem as FishingRod
	if rod and player.tacklebox:
		for part in rod.parts():
			if part is Bait:
				player.tacklebox.use_up(part, player.inventory)

# Shows every result once the minigames are over, one after the other.
func celebrate(list : Array[Dictionary]) -> void:
	for result in list:
		if result.has("icon") and result.icon:
			jump(result.icon, result.from, result.text, result.color)
			await get_tree().create_timer(jumpTime + 0.15 + resultGap).timeout
		else:
			say(result.text, result.color)
			await get_tree().create_timer(textTime * 0.5).timeout

func jump(icon : Texture2D, from : Vector2, text : String, color : Color) -> void:
	side = 1.0 if from.x >= player.center.global_position.x else -1.0
	catchSprite.texture = icon
	catchSprite.global_position = from
	catchSprite.scale = Vector2.ONE
	catchSprite.show()
	var tween : Tween = create_tween()
	tween.tween_method(fly.bind(from), 0.0, 1.0, jumpTime)
	tween.tween_property(catchSprite, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(catchSprite.hide)
	tween.tween_callback(say.bind(text, color))

func fly(amount : float, from : Vector2) -> void:
	var to : Vector2 = player.center.global_position + textOffset * 0.5
	catchSprite.global_position = from.lerp(to, amount) - Vector2(0.0, sin(amount * PI) * jumpHeight)
	catchSprite.rotation = (1.0 - amount) * side * -1.2

func say(message : String, color : Color) -> void:
	catchText.pop(player.center.global_position + textOffset, message, color, textTime)
