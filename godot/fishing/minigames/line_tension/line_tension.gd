extends Minigame
class_name LineTensionMinigame

# Hold to reel the line in. Reeling builds tension and the line snaps when it
# is full. Letting go eases it off. The fish surges now and then after a
# flashing warning: reeling into a surge spikes the tension, letting go gives
# up line. Harder fish surge sooner, longer, less predictably and with less
# warning. Heavier fish take longer to reel in and build tension faster.

#------------------------#
@export_group("Tension")
@export var rise : Vector2 = Vector2(0.28, 0.42)
@export var heavyRise : float = 0.35
@export var relax : float = 0.75
@export_range(0.0, 1.0) var danger : float = 0.75

@export_group("Surges")
@export var surgeGap : Vector2 = Vector2(2.6, 1.2)
@export var gapJitter : Vector2 = Vector2(0.15, 0.55)
@export var warning : Vector2 = Vector2(0.65, 0.3)
@export var minWarning : float = 0.25
@export var surgeTime : Vector2 = Vector2(0.6, 1.2)
@export var surgeRise : Vector2 = Vector2(1.4, 2.4)
# Line given up per second of surge, as a share of the reeling speed. Kept
# under half of what can be reeled in between surges.
@export var slip : Vector2 = Vector2(0.3, 0.8)

@export_group("Reel")
@export var reelTime : Vector2 = Vector2(3.0, 5.5)

var tension : float = 0.0
var progress : float = 0.0
var reelRate : float = 0.0
var slipRate : float = 0.0
var warnTime : float = 0.0
var timer : float = 0.0
var surging : float = 0.0
var warned : bool = false
#------------------------#


func setup() -> void:
	reelRate = 1.0 / weigh(reelTime)
	warnTime = maxf(tune(warning), minWarning)
	var shortestGap : float = tune(surgeGap) * (1.0 - tune(gapJitter))
	slipRate = reelRate * minf(tune(slip), 0.5 * maxf(shortestGap - warnTime, 0.1) / tune(surgeTime))
	next_surge()

func next_surge() -> void:
	timer = tune(surgeGap) * (1.0 + random.randf_range(-1.0, 1.0) * tune(gapJitter)) + warnTime
	warned = false

func tick(delta : float) -> void:
	if surging > 0.0:
		surging -= delta
		if surging <= 0.0:
			next_surge()
	else:
		timer -= delta
		if timer <= warnTime and not warned:
			warned = true
		if timer <= 0.0:
			surging = tune(surgeTime)
			tugged.emit(0.6)
	if holding:
		tension += (tune(surgeRise) if surging > 0.0 else tune(rise) * (1.0 + heavyRise * heft)) * delta
		if surging <= 0.0:
			progress += reelRate * delta
	else:
		tension -= relax * delta
		if surging > 0.0:
			progress -= slipRate * delta
	tension = maxf(tension, 0.0)
	progress = maxf(progress, 0.0)
	if tension >= 1.0:
		tugged.emit(1.0)
		finish(false)
	elif progress >= 1.0:
		finish(true)

func _draw() -> void:
	var alert : bool = surging > 0.0 or (warned and fmod(time * 8.0, 1.0) < 0.5)
	var inner : Rect2 = draw_panel(Rect2(-size * 0.5, size), (badColor if surging > 0.0 else accent) if alert else frameColor)
	var gauge : Rect2 = Rect2(inner.position, Vector2(inner.size.x, inner.size.y - fishSize - 1.0))
	draw_meter(gauge, tension, false, goodColor.lerp(badColor, smoothstep(0.3, danger, tension)))
	draw_rect(Rect2(gauge.position.x + gauge.size.x * danger, gauge.position.y, gauge.size.x * (1.0 - danger), gauge.size.y), Color(badColor, 0.3))
	draw_rect(Rect2(gauge.position.x + gauge.size.x * danger, gauge.position.y, 1.0, gauge.size.y), Color(badColor, 0.8))
	# The fish on the end of the line, pulled toward the rod on the left as it's reeled in.
	var lane : float = gauge.end.y + 1.0 + fishSize * 0.5
	var half : float = fishSize * 0.5
	var thrash : float = 1.0 if surging > 0.0 else 0.0
	var fishAt : Vector2 = Vector2(lerpf(inner.end.x - half, inner.position.x + half + 2.0, progress) + sin(time * 45.0) * thrash, lane)
	draw_line(Vector2(inner.position.x, lane), fishAt, Color(lightColor, 0.7), 0.5)
	draw_fish(fishAt, -1.0, sin(time * (30.0 if thrash > 0.0 else 8.0)) * (0.35 if thrash > 0.0 else 0.08))
