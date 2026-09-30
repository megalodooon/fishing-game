extends Minigame
class_name NetChaseMinigame

# Keep the net (the mouse) over the fish in a little pond until it's landed.
# The fish wanders to spots away from the net and swims off when the net
# comes close, so a net left still never catches it. Harder fish swim faster,
# dart more and flee harder from a smaller net. Heavier fish take longer.
# The fish is always slower than a hand on the mouse can follow: its top speed
# times a slow reaction (~0.13 s) stays inside the smallest net.

#------------------------#
@export_group("Net")
@export var netRadius : Vector2 = Vector2(7.5, 5.5)
@export var minNetRadius : float = 5.0

@export_group("Fish")
@export var fishSpeed : Vector2 = Vector2(14.0, 26.0)
@export var maxFishSpeed : float = 34.0
@export var moveInterval : Vector2 = Vector2(1.6, 0.6)
@export var dartChance : Vector2 = Vector2(0.05, 0.4)
@export var dartBoost : float = 1.7
@export var flee : Vector2 = Vector2(0.6, 0.9)
@export var fleeRange : float = 12.0
@export var steer : float = 5.0
# Wander goals are picked at least this far from the net.
@export var goalClearance : float = 14.0

@export_group("Progress")
@export var catchTime : Vector2 = Vector2(2.4, 5.0)
@export var escapeRate : Vector2 = Vector2(0.12, 0.2)
@export_range(0.0, 1.0) var startProgress : float = 0.3

var pond : Rect2
var net : Vector2
var netSize : float = 0.0
var fish : Vector2
var fishVelocity : Vector2
var goal : Vector2
var topSpeed : float = 0.0
var moveTimer : float = 0.0
var progress : float = 0.0
var inside : bool = false
var facing : float = 1.0
var ripples : Array[Vector3] = []
#------------------------#


func setup() -> void:
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	pond = Rect2(inner.position, Vector2(inner.size.x, inner.size.y - 4.0))
	netSize = maxf(tune(netRadius), minNetRadius)
	net = pond.get_center()
	fish = pond.get_center() + Vector2(random.randf_range(-12.0, 12.0), random.randf_range(-5.0, 5.0))
	goal = fish
	progress = startProgress
	topSpeed = tune(fishSpeed)

func tick(delta : float) -> void:
	net = clamp_point(pointer(), 0.0)
	move_fish(delta)
	inside = net.distance_to(fish) <= netSize
	progress += (1.0 / weigh(catchTime) if inside else -tune(escapeRate)) * delta
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].z += delta
		if ripples[i].z > 0.6:
			ripples.remove_at(i)
	if progress >= 1.0:
		finish(true)
	elif progress <= 0.0:
		finish(false)

func clamp_point(point : Vector2, margin : float) -> Vector2:
	return point.clamp(pond.position + Vector2(margin, margin), pond.end - Vector2(margin, margin))

func pick_goal() -> Vector2:
	var best : Vector2 = fish
	var bestDistance : float = -1.0
	for attempt in 10:
		var candidate : Vector2 = Vector2(random.randf_range(pond.position.x + 4.0, pond.end.x - 4.0), random.randf_range(pond.position.y + 3.0, pond.end.y - 3.0))
		var away : float = candidate.distance_to(net)
		if away >= goalClearance:
			return candidate
		if away > bestDistance:
			bestDistance = away
			best = candidate
	return best

func move_fish(delta : float) -> void:
	moveTimer -= delta
	if moveTimer <= 0.0 or fish.distance_to(goal) < 2.0:
		moveTimer = tune(moveInterval) * random.randf_range(0.6, 1.4)
		goal = pick_goal()
		var darting : bool = random.randf() < tune(dartChance)
		topSpeed = minf(tune(fishSpeed) * (dartBoost if darting else 1.0), maxFishSpeed)
		if darting:
			tugged.emit(0.3)
			ripples.append(Vector3(fish.x, fish.y, 0.0))
	var want : Vector2 = (goal - fish).limit_length(1.0) * topSpeed
	var fromNet : Vector2 = fish - net
	var near : float = fromNet.length()
	if near < fleeRange + netSize and near > 0.01:
		want += fromNet / near * topSpeed * tune(flee) * (1.0 - near / (fleeRange + netSize))
	want = want.limit_length(maxFishSpeed)
	fishVelocity = fishVelocity.lerp(want, 1.0 - exp(-steer * delta))
	fish += fishVelocity * delta
	var held : Vector2 = clamp_point(fish, 2.0)
	if held != fish:
		fishVelocity *= 0.5
		fish = held
	if absf(fishVelocity.x) > 2.0:
		facing = signf(fishVelocity.x)

func _draw() -> void:
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	draw_rect(pond, trackColor)
	for ripple in ripples:
		var t : float = ripple.z / 0.6
		draw_set_transform(Vector2(ripple.x, ripple.y), 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, 2.0 + t * 7.0, 0.0, TAU, 20, Color(lightColor, 0.5 * (1.0 - t)), 0.35, true)
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(fish + Vector2(0.0, 2.5), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, fishSize * 0.4, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_fish(fish, facing, sin(time * 12.0) * 0.1 + clampf(fishVelocity.y * 0.01, -0.3, 0.3) * facing)
	var netColor : Color = goodColor if inside else lightColor
	draw_circle(net, netSize, Color(netColor, 0.16))
	for i in range(-2, 3):
		var offset : float = i * netSize * 0.4
		var half : float = sqrt(maxf(netSize * netSize - offset * offset, 0.0))
		draw_line(net + Vector2(offset, -half), net + Vector2(offset, half), Color(netColor, 0.35), 0.25, true)
		draw_line(net + Vector2(-half, offset), net + Vector2(half, offset), Color(netColor, 0.35), 0.25, true)
	draw_arc(net, netSize, 0.0, TAU, 32, netColor, 0.6, true)
	var meter : Rect2 = Rect2(pond.position.x, pond.end.y + 1.0, pond.size.x, 2.0)
	draw_meter(meter, progress, false, badColor.lerp(goodColor, progress))
