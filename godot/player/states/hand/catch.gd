extends State
class_name PlayerCatchState


#------------------------#
@onready var player : Player = owner
@onready var reel : PlayerReelState = %Reel
@onready var catchText : Callout = %CatchText
@onready var catchSprite : Sprite2D = %CatchSprite

@export var minigames : Array[PackedScene] = []
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
# Put in front of a fish's name the first time one is caught.
@export var newText : String = "New! "
@export var jumpTime : float = 0.5
@export var jumpHeight : float = 16.0
@export var resultGap : float = 0.3

var fish : Fish
var minigame : Minigame
# The line that got the bite, set by the fishing state. Every other line in
# the water brings in a fish too, one minigame after the other.
var line : FishingRod
var queue : Array[FishingRod] = []
var hookedSpot : FishingSpot
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
	line = null
	queue.clear()
	player.minigameScreen.close_menu()

# Starts the minigame for the next line. Lines outside a fishing spot fish from
# the spot the bite came from.
func next_fish() -> void:
	while not queue.is_empty():
		line = queue.pop_front()
		var spot : FishingSpot = line.castSpot if line.castSpot else hookedSpot
		var data : FishData = FishData.roll(spot.fish, DayNightCycle.now(get_tree())) if spot else null
		var games : Array[PackedScene] = minigames if not data or data.minigames.is_empty() else data.minigames
		if not data or games.is_empty():
			continue
		if not player.inventory.has_space():
			player.inventory.needs_room.emit()
			results.append({"text": fullText, "color": fullColor})
			break
		fish = Fish.caught(data)
		minigame = games.pick_random().instantiate()
		minigame.finished.connect(on_finished)
		minigame.tugged.connect(line.bobber.splash)
		player.minigameScreen.caption = "Fish %d of %d" % [total - queue.size(), total] if total > 1 else ""
		player.minigameScreen.play(minigame)
		var rod : FishingRod = player.heldItem as FishingRod
		minigame.begin(data.difficulty() - rod.control() + randf_range(-difficultyJitter, difficultyJitter), fish.heft(), fish.title_color(), fish.icon)
		return
	celebrate(results.duplicate())
	stateMachine.change_state(reel)

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
	if caught and fish:
		if player.inventory.add(fish) < 0:
			results.append({"text": fullText, "color": fullColor})
		else:
			var first : bool = player.journal.record(fish) if player.journal else false
			results.append({"fish": fish, "from": line.get_bobber_point(), "first": first})
	else:
		results.append({"text": escapeText, "color": escapeColor})
	fish = null
	if gaveUp:
		queue.clear()
	next_fish()

# Shows every result once the minigames are over, one after the other.
func celebrate(list : Array[Dictionary]) -> void:
	for result in list:
		if result.has("fish"):
			jump(result.fish, result.from, result.first)
			await get_tree().create_timer(jumpTime + 0.15 + resultGap).timeout
		else:
			say(result.text, result.color)
			await get_tree().create_timer(textTime * 0.5).timeout

func jump(caughtFish : Fish, from : Vector2, first : bool) -> void:
	side = 1.0 if from.x >= player.center.global_position.x else -1.0
	catchSprite.texture = caughtFish.icon
	catchSprite.global_position = from
	catchSprite.scale = Vector2.ONE
	catchSprite.show()
	var tween : Tween = create_tween()
	tween.tween_method(fly.bind(from), 0.0, 1.0, jumpTime)
	tween.tween_property(catchSprite, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(catchSprite.hide)
	tween.tween_callback(say.bind("%s%s %s" % [newText if first else "", caughtFish.displayName, caughtFish.weight_text()], caughtFish.title_color()))

func fly(amount : float, from : Vector2) -> void:
	var to : Vector2 = player.center.global_position + textOffset * 0.5
	catchSprite.global_position = from.lerp(to, amount) - Vector2(0.0, sin(amount * PI) * jumpHeight)
	catchSprite.rotation = (1.0 - amount) * side * -1.2

func say(message : String, color : Color) -> void:
	catchText.pop(player.center.global_position + textOffset, message, color, textTime)
