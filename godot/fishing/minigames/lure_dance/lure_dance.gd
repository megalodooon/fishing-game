extends Minigame
class_name LureDanceMinigame

# The fish follows the lure around five spots. First it shows a pattern, then
# the player clicks the spots in the same order. Each round the pattern grows
# by one. Wrong spots and waiting too long cost a chance. Harder fish show
# the pattern faster, allow less time and fewer mistakes, and start longer.
# Heavier fish need more rounds.

enum Phase { SHOW, INPUT, PAUSE }

const SPOTS : PackedVector2Array = [Vector2(-14.0, -5.0), Vector2(14.0, -5.0), Vector2(0.0, 0.0), Vector2(-14.0, 6.0), Vector2(14.0, 6.0)]

#------------------------#
@export var showStep : Vector2 = Vector2(0.55, 0.32)
@export var inputTime : Vector2 = Vector2(2.4, 1.3)
@export var startLength : Vector2 = Vector2(2.0, 4.0)
@export var rounds : Vector2 = Vector2(2.0, 4.0)
@export var mistakes : Vector2 = Vector2(3.0, 2.0)
@export var spotRadius : float = 3.2

var sequence : PackedInt32Array = PackedInt32Array()
var phase : int = Phase.PAUSE
var timer : float = 0.8
var shown : int = 0
var entered : int = 0
var roundsLeft : int = 0
var roundsNeeded : int = 0
var mistakesLeft : int = 0
var lit : int = -1
var litTime : float = 0.0
var litColor : Color = Color.WHITE
var fishAt : Vector2 = Vector2.ZERO
#------------------------#


func setup() -> void:
	roundsNeeded = maxi(roundi(weigh(rounds)), 1)
	roundsLeft = roundsNeeded
	mistakesLeft = maxi(roundi(tune(mistakes)), 1)
	for i in maxi(roundi(tune(startLength)), 2):
		add_step()

func add_step() -> void:
	var next : int = random.randi_range(0, SPOTS.size() - 1)
	if not sequence.is_empty() and next == sequence[sequence.size() - 1]:
		next = (next + 1 + random.randi_range(0, SPOTS.size() - 2)) % SPOTS.size()
	sequence.append(next)

func light(spot : int, color : Color) -> void:
	lit = spot
	litTime = 0.3
	litColor = color

func tick(delta : float) -> void:
	litTime = maxf(litTime - delta, 0.0)
	timer -= delta
	match phase:
		Phase.PAUSE:
			if timer <= 0.0:
				phase = Phase.SHOW
				shown = 0
				timer = 0.2
		Phase.SHOW:
			if timer <= 0.0:
				if shown >= sequence.size():
					phase = Phase.INPUT
					entered = 0
					timer = tune(inputTime)
				else:
					light(sequence[shown], accent)
					shown += 1
					timer = tune(showStep)
		Phase.INPUT:
			if timer <= 0.0:
				mistake()
	var goal : Vector2 = SPOTS[lit] if litTime > 0.0 and lit >= 0 else Vector2(0.0, -12.0)
	fishAt = fishAt.lerp(goal, 1.0 - exp(-10.0 * delta))

func mistake() -> void:
	mistakesLeft -= 1
	tugged.emit(0.5)
	if mistakesLeft <= 0:
		finish(false)
		return
	phase = Phase.PAUSE
	timer = 0.8

func spot_at(point : Vector2) -> int:
	for i in SPOTS.size():
		if point.distance_to(SPOTS[i]) <= spotRadius + 1.0:
			return i
	return -1

func press() -> void:
	if phase != Phase.INPUT:
		return
	var spot : int = spot_at(pointer())
	if spot < 0:
		return
	if spot != sequence[entered]:
		light(spot, badColor)
		mistake()
		return
	light(spot, goodColor)
	entered += 1
	timer = tune(inputTime)
	tugged.emit(0.2)
	if entered >= sequence.size():
		roundsLeft -= 1
		if roundsLeft <= 0:
			finish(true)
			return
		add_step()
		phase = Phase.PAUSE
		timer = 0.7

func _draw() -> void:
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	var edge : Color = Color(goodColor, 0.5 + 0.3 * sin(time * 8.0)) if phase == Phase.INPUT else Color(accent, 0.4)
	draw_rect(inner, edge, false, 0.5)
	for i in SPOTS.size():
		var hot : bool = i == lit and litTime > 0.0
		draw_circle(SPOTS[i], spotRadius, Color(litColor, 0.45) if hot else Color(trackColor, 0.9))
		draw_arc(SPOTS[i], spotRadius, 0.0, TAU, 20, litColor if hot else Color(lightColor, 0.35), 0.5, true)
	draw_fish(fishAt, 1.0 if fishAt.x >= 0.0 else -1.0, sin(time * 10.0) * 0.1)
	if phase == Phase.INPUT:
		var share : float = clampf(timer / tune(inputTime), 0.0, 1.0)
		draw_rect(Rect2(inner.position.x + 1.0, inner.end.y - 2.0, (inner.size.x - 2.0) * share, 1.0), goodColor)
	for i in roundsNeeded:
		draw_rect(Rect2(inner.position.x + 1.0 + i * 2.5, inner.position.y + 1.0, 1.5, 1.5), accent if i < roundsNeeded - roundsLeft else Color(lightColor, 0.2))
	for i in mistakesLeft:
		draw_rect(Rect2(inner.end.x - 2.5 - i * 2.5, inner.position.y + 1.0, 1.5, 1.5), badColor)
