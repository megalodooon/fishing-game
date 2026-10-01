extends Minigame
class_name ReelBarMinigame

# Hold to lift the catch zone and keep the fish inside it. Harder fish dart
# further, more often and faster, against a smaller zone. Heavier fish drag the
# zone down harder and take longer to land. The fish never swims into the zone
# resting at the bottom, so letting go never catches it.

#------------------------#
@export_group("Zone")
@export var zoneSize : Vector2 = Vector2(18.0, 8.0)
@export var minZoneSize : float = 6.0
@export var lift : float = 320.0
@export var sink : Vector2 = Vector2(200.0, 270.0)
@export var maxSpeed : float = 95.0
@export_range(0.0, 1.0) var bounce : float = 0.35

@export_group("Fish")
@export var fishSpeed : Vector2 = Vector2(16.0, 58.0)
@export var moveInterval : Vector2 = Vector2(1.5, 0.45)
@export var jump : Vector2 = Vector2(0.2, 0.85)
@export var dartChance : Vector2 = Vector2(0.0, 0.45)
@export var dartBoost : float = 1.8
# The fish never moves faster than this share of the zone's top speed.
@export_range(0.1, 1.0) var speedCap : float = 0.7
@export var fishSteer : float = 8.0

@export_group("Progress")
@export var catchTime : Vector2 = Vector2(3.0, 6.5)
@export var escapeRate : Vector2 = Vector2(0.1, 0.28)
@export_range(0.0, 1.0) var startProgress : float = 0.3

var length : float = 0.0
var zone : float = 0.0
var zoneVelocity : float = 0.0
var zoneHalf : float = 0.0
var fish : float = 0.0
var fishVelocity : float = 0.0
var fishGoal : float = 0.0
var fishTop : float = 0.0
var fishFloor : float = 0.0
var moveTimer : float = 0.0
var progress : float = 0.0
var inside : bool = false
#------------------------#


func track_rect() -> Rect2:
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	return Rect2(inner.position, Vector2(inner.size.x - 4.0, inner.size.y))

func setup() -> void:
	length = track_rect().size.y
	zoneHalf = clampf(tune(zoneSize), minZoneSize, length) * 0.5
	zone = zoneHalf
	fishFloor = minf(zoneHalf * 2.0 + 2.0, length - 2.0)
	fish = lerpf(fishFloor, length - 1.0, random.randf_range(0.2, 0.6))
	fishGoal = fish
	progress = startProgress
	moveTimer = tune(moveInterval) * 0.5

func tick(delta : float) -> void:
	zoneVelocity = clampf(zoneVelocity + (lift if holding else -weigh(sink)) * delta, -maxSpeed, maxSpeed)
	zone += zoneVelocity * delta
	if zone < zoneHalf:
		zone = zoneHalf
		zoneVelocity = -zoneVelocity * bounce
	elif zone > length - zoneHalf:
		zone = length - zoneHalf
		zoneVelocity = 0.0
	move_fish(delta)
	inside = absf(fish - zone) <= zoneHalf
	progress += (1.0 / weigh(catchTime) if inside else -tune(escapeRate)) * delta
	if progress >= 1.0:
		finish(true)
	elif progress <= 0.0:
		finish(false)

func move_fish(delta : float) -> void:
	moveTimer -= delta
	if moveTimer <= 0.0:
		moveTimer = tune(moveInterval) * random.randf_range(0.6, 1.4)
		var reach : float = tune(jump) * length * random.randf_range(0.5, 1.0)
		# Toward whichever side has room, so it never pins itself to an edge.
		var up : bool = random.randf() < 0.5
		if fish + reach > length - 1.0:
			up = false
		elif fish - reach < fishFloor:
			up = true
		fishGoal = clampf(fish + reach * (1.0 if up else -1.0), fishFloor, length - 1.0)
		var darting : bool = random.randf() < tune(dartChance)
		fishTop = minf(tune(fishSpeed) * (dartBoost if darting else 1.0), maxSpeed * speedCap)
		if darting:
			tugged.emit(0.3)
	var want : float = clampf((fishGoal - fish) * 4.0, -fishTop, fishTop)
	fishVelocity = lerpf(fishVelocity, want, 1.0 - exp(-fishSteer * delta))
	fish = clampf(fish + fishVelocity * delta, fishFloor, length - 1.0)

func _draw() -> void:
	var track : Rect2 = track_rect()
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	draw_rect(track, trackColor)
	var bottom : float = track.end.y
	var zoneColor : Color = goodColor if inside else lightColor
	draw_rect(Rect2(track.position.x, bottom - zone - zoneHalf, track.size.x, zoneHalf * 2.0), Color(zoneColor, 0.45))
	draw_rect(Rect2(track.position.x, bottom - zone - zoneHalf, track.size.x, 1.0), zoneColor)
	draw_rect(Rect2(track.position.x, bottom - zone + zoneHalf - 1.0, track.size.x, 1.0), zoneColor)
	draw_fish(Vector2(track.get_center().x, bottom - fish), 1.0, sin(time * 14.0) * 0.12 + clampf(fishVelocity * 0.004, -0.3, 0.3))
	var meter : Rect2 = Rect2(track.end.x + 1.0, track.position.y, 3.0, track.size.y)
	draw_meter(meter, progress, true, badColor.lerp(goodColor, progress))
