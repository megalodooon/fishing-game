extends Minigame
class_name StrikeRingsMinigame

# The fish surfaces here and there with a ring closing in on it. Point at it
# and click as the ring meets the fish. Harder fish give less time, a tighter
# window, drift about and allow fewer misses. Heavier fish need more strikes.
# A ring left alone counts as a miss, so doing nothing loses. The window never
# gets shorter than minWindow seconds.

#------------------------#
@export_group("Rings")
@export var targetRadius : Vector2 = Vector2(6.0, 4.0)
@export var ringStart : float = 13.0
@export var approachTime : Vector2 = Vector2(1.4, 0.8)
# How long the ring counts as touching the fish, in seconds.
@export var window : Vector2 = Vector2(0.5, 0.34)
@export var minWindow : float = 0.3
# The pointer can be this far outside the fish and still count.
@export var aimSlack : float = 4.0
@export var drift : Vector2 = Vector2(0.0, 5.0)
@export var gap : Vector2 = Vector2(0.4, 0.2)

@export_group("Rounds")
@export var hits : Vector2 = Vector2(4.0, 8.0)
@export var misses : Vector2 = Vector2(4.0, 2.0)
@export var flashTime : float = 0.3

var area : Rect2
var target : Vector2
var targetVelocity : Vector2
var radius : float = 0.0
# Seconds since the ring started closing. Below 0 while waiting for the next.
var clock : float = 0.0
var duration : float = 0.0
var hitsNeeded : int = 0
var hitsLeft : int = 0
var missesLeft : int = 0
var flash : float = 0.0
var flashColor : Color = Color.WHITE
var flashAt : Vector2
#------------------------#


func setup() -> void:
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	area = Rect2(inner.position, Vector2(inner.size.x, inner.size.y - 4.0))
	radius = tune(targetRadius)
	duration = tune(approachTime)
	hitsNeeded = maxi(roundi(weigh(hits)), 1)
	hitsLeft = hitsNeeded
	missesLeft = maxi(roundi(tune(misses)), 1)
	next_ring(0.35)

# How long the hit window lasts, centered on the moment the ring meets the fish.
func window_time() -> float:
	return maxf(tune(window), minWindow)

func next_ring(wait : float) -> void:
	var margin : float = radius + 2.0
	var last : Vector2 = target
	for attempt in 8:
		target = Vector2(random.randf_range(area.position.x + margin, area.end.x - margin), random.randf_range(area.position.y + margin, area.end.y - margin))
		if target.distance_to(last) > 12.0:
			break
	targetVelocity = Vector2.from_angle(random.randf() * TAU) * tune(drift)
	clock = -wait

# 1 when the ring starts, 0 when it meets the fish.
func ring_amount() -> float:
	return 1.0 - clock / duration

func timing_error() -> float:
	return clock - duration

func tick(delta : float) -> void:
	flash = maxf(flash - delta, 0.0)
	clock += delta
	if clock < 0.0:
		return
	target += targetVelocity * delta
	var margin : float = radius + 2.0
	if target.x < area.position.x + margin or target.x > area.end.x - margin:
		targetVelocity.x = -targetVelocity.x
	if target.y < area.position.y + margin or target.y > area.end.y - margin:
		targetVelocity.y = -targetVelocity.y
	target = target.clamp(area.position + Vector2(margin, margin), area.end - Vector2(margin, margin))
	if timing_error() > window_time() * 0.5:
		miss()

func press() -> void:
	if clock < 0.0:
		return
	var onTime : bool = absf(timing_error()) <= window_time() * 0.5
	var onFish : bool = pointer().distance_to(target) <= radius + aimSlack
	# Clicks well off the fish or long before the ring closes are ignored.
	if not onFish or timing_error() < -window_time() * 1.5:
		return
	if onTime:
		hit()
	else:
		miss()

func hit() -> void:
	hitsLeft -= 1
	show_flash(goodColor)
	tugged.emit(0.3)
	if hitsLeft <= 0:
		finish(true)
	else:
		next_ring(tune(gap))

func miss() -> void:
	missesLeft -= 1
	show_flash(badColor)
	tugged.emit(0.5)
	if missesLeft <= 0:
		finish(false)
	else:
		next_ring(tune(gap) + 0.15)

func show_flash(color : Color) -> void:
	flash = flashTime
	flashColor = color
	flashAt = target

func _draw() -> void:
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	draw_rect(area, trackColor)
	if flash > 0.0:
		var t : float = 1.0 - flash / flashTime
		draw_arc(flashAt, radius + t * 6.0, 0.0, TAU, 32, Color(flashColor, 1.0 - t), 0.6, true)
	if clock >= 0.0 and not done:
		var amount : float = ring_amount()
		var close : bool = absf(timing_error()) <= window_time() * 0.5
		draw_circle(target, radius, Color(goodColor if close else lightColor, 0.14))
		draw_arc(target, radius, 0.0, TAU, 32, Color(lightColor, 0.5), 0.3, true)
		draw_fish(target, 1.0 if targetVelocity.x >= 0.0 else -1.0, sin(time * 10.0) * 0.08)
		var ring : float = radius + maxf(amount, -0.5) * ringStart
		draw_arc(target, maxf(ring, 0.5), 0.0, TAU, 40, goodColor if close else accent, 0.7, true)
	var pips : float = area.end.y + 1.5
	for i in hitsNeeded:
		draw_rect(Rect2(area.position.x + i * 3.0, pips, 2.0, 2.0), accent if i < hitsNeeded - hitsLeft else Color(lightColor, 0.25))
	for i in missesLeft:
		draw_rect(Rect2(area.end.x - 2.0 - i * 3.0, pips, 2.0, 2.0), badColor)
