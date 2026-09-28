extends Minigame
class_name TimingNeedleMinigame

# Click while the needle is inside the sweet spot. Harder fish shrink the spot,
# speed the needle up after every hit, make it rush through the middle and set
# the spot drifting, with fewer misses allowed. Heavier fish need more hits.
# The needle always stays in the spot for at least minReaction seconds.

#------------------------#
@export_group("Needle")
@export var needleSpeed : Vector2 = Vector2(38.0, 85.0)
@export var speedUp : Vector2 = Vector2(0.0, 7.0)
# 0 sweeps evenly, 1 slows at the ends and rushes through the middle.
@export var rush : Vector2 = Vector2(0.0, 1.0)

@export_group("Sweet Spot")
@export var spotSize : Vector2 = Vector2(12.0, 5.0)
@export var drift : Vector2 = Vector2(0.0, 14.0)
@export var minReaction : float = 0.09
@export var clearance : float = 6.0

@export_group("Rounds")
@export var hits : Vector2 = Vector2(3.0, 7.0)
@export var misses : Vector2 = Vector2(4.0, 2.0)
@export var flashTime : float = 0.25

var length : float = 0.0
var phase : float = 0.0
var speed : float = 0.0
var rushAmount : float = 0.0
var needle : float = 0.0
var spot : float = 0.0
var spotHalf : float = 0.0
var spotVelocity : float = 0.0
var hitsLeft : int = 0
var hitsNeeded : int = 0
var missesLeft : int = 0
var flash : float = 0.0
var flashColor : Color = Color.WHITE
#------------------------#


# The fish swims along the top, the track sits under it and the pips under that.
func track_rect() -> Rect2:
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	return Rect2(inner.position.x, inner.position.y + fishSize + 1.0, inner.size.x, inner.size.y - fishSize - 4.0)

func setup() -> void:
	length = track_rect().size.x
	spotHalf = minf(tune(spotSize), length * 0.5) * 0.5
	rushAmount = tune(rush)
	spotVelocity = minf(tune(drift), spotHalf * 2.0 / minReaction * 0.5) * (1.0 if random.randf() < 0.5 else -1.0)
	speed = clamp_speed(tune(needleSpeed))
	hitsNeeded = maxi(roundi(weigh(hits)), 1)
	hitsLeft = hitsNeeded
	missesLeft = maxi(roundi(tune(misses)), 1)
	phase = random.randf() * 2.0
	needle = needle_at(phase)
	move_spot()

# The needle at its fastest, plus the spot drifting toward it, still has to
# leave minReaction seconds inside the spot.
func clamp_speed(want : float) -> float:
	var fastest : float = lerpf(1.0, PI * 0.5, rushAmount)
	return minf(want, maxf((spotHalf * 2.0 / minReaction - absf(spotVelocity)) / fastest, 10.0))

func needle_at(at : float) -> float:
	var sweep : float = at if at < 1.0 else 2.0 - at
	return lerpf(sweep, 0.5 - 0.5 * cos(sweep * PI), rushAmount) * length

func move_spot() -> void:
	for attempt in 12:
		spot = random.randf_range(spotHalf, length - spotHalf)
		if absf(spot - needle) > spotHalf + clearance:
			return

func tick(delta : float) -> void:
	phase = fmod(phase + speed / length * delta, 2.0)
	needle = needle_at(phase)
	spot += spotVelocity * delta
	if spot < spotHalf or spot > length - spotHalf:
		spot = clampf(spot, spotHalf, length - spotHalf)
		spotVelocity = -spotVelocity
	flash = maxf(flash - delta, 0.0)

func press() -> void:
	flash = flashTime
	if absf(needle - spot) <= spotHalf:
		hitsLeft -= 1
		flashColor = goodColor
		tugged.emit(0.25)
		if hitsLeft <= 0:
			finish(true)
			return
		speed = clamp_speed(speed + tune(speedUp))
		move_spot()
	else:
		missesLeft -= 1
		flashColor = badColor
		tugged.emit(0.5)
		if missesLeft <= 0:
			finish(false)

func _draw() -> void:
	var track : Rect2 = track_rect()
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	draw_rect(track, trackColor.lerp(flashColor, flash / flashTime * 0.5) if flash > 0.0 else trackColor)
	draw_rect(Rect2(track.position.x + spot - spotHalf, track.position.y, spotHalf * 2.0, track.size.y), goodColor if absf(needle - spot) <= spotHalf else Color(goodColor, 0.6))
	draw_rect(Rect2(track.position.x + needle - 0.5, track.position.y - 1.0, 1.0, track.size.y + 2.0), lightColor)
	draw_fish(Vector2(track.position.x + needle, track.position.y - fishSize * 0.5 - 1.0), 1.0 if phase < 1.0 else -1.0)
	var pips : float = track.end.y + 1.0
	for i in hitsNeeded:
		draw_rect(Rect2(track.position.x + i * 3.0, pips, 2.0, 2.0), accent if i < hitsNeeded - hitsLeft else trackColor)
	for i in missesLeft:
		draw_rect(Rect2(track.end.x - 2.0 - i * 3.0, pips, 2.0, 2.0), badColor)
