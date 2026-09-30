extends Minigame
class_name ReelRhythmMinigame

# Tugs on the line slide toward the reel: click as each one crosses the ring.
# Hits reel the fish in, misses (late tugs or clicks with nothing there) cost
# a chance. Harder fish send tugs faster and closer together with a smaller
# ring, heavier ones need more hits. The ring is always wide enough to leave
# minWindow seconds to click, and tugs never come closer than that apart.

#------------------------#
@export var noteSpeed : Vector2 = Vector2(26.0, 38.0)
@export var gapTime : Vector2 = Vector2(1.0, 0.7)
@export var window : Vector2 = Vector2(6.0, 5.0)
@export var minWindow : float = 0.16
@export var hits : Vector2 = Vector2(7.0, 11.0)
@export var misses : Vector2 = Vector2(6.0, 4.0)
@export var flashTime : float = 0.25

var lane : Rect2
var hitX : float = 0.0
var notes : Array[float] = []
var spawnTimer : float = 0.6
var hitsNeeded : int = 0
var hitsDone : int = 0
var missesLeft : int = 0
var combo : int = 0
var flash : float = 0.0
var flashColor : Color = Color.WHITE
#------------------------#


func setup() -> void:
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	lane = Rect2(inner.position.x, inner.position.y + 3.0, inner.size.x - 10.0, inner.size.y - 7.0)
	hitX = lane.position.x + 8.0
	hitsNeeded = maxi(roundi(weigh(hits)), 3)
	missesLeft = maxi(roundi(tune(misses)), 1)

func half_window() -> float:
	return maxf(tune(window), tune(noteSpeed) * minWindow) * 0.5

func tick(delta : float) -> void:
	flash = maxf(flash - delta, 0.0)
	spawnTimer -= delta
	if spawnTimer <= 0.0:
		spawnTimer = maxf(tune(gapTime) * random.randf_range(0.8, 1.5), minWindow * 2.0 + 0.1)
		notes.append(lane.end.x)
	var speed : float = tune(noteSpeed)
	for i in range(notes.size() - 1, -1, -1):
		notes[i] -= speed * delta
		if notes[i] < hitX - half_window():
			notes.remove_at(i)
			miss()
			if done:
				return

func press() -> void:
	for i in notes.size():
		if absf(notes[i] - hitX) <= half_window():
			notes.remove_at(i)
			hitsDone += 1
			combo += 1
			flash = flashTime
			flashColor = goodColor
			tugged.emit(0.25)
			if hitsDone >= hitsNeeded:
				finish(true)
			return
	miss()

func miss() -> void:
	combo = 0
	missesLeft -= 1
	flash = flashTime
	flashColor = badColor
	tugged.emit(0.5)
	if missesLeft <= 0:
		finish(false)

func _draw() -> void:
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	draw_rect(lane, trackColor.lerp(flashColor, flash / flashTime * 0.35) if flash > 0.0 else trackColor)
	var middle : float = lane.get_center().y
	draw_line(Vector2(lane.position.x, middle), Vector2(lane.end.x, middle), Color(lightColor, 0.25), 0.3, true)
	var ring : float = half_window()
	draw_rect(Rect2(hitX - ring, lane.position.y, ring * 2.0, lane.size.y), Color(goodColor, 0.18))
	draw_arc(Vector2(hitX, middle), lane.size.y * 0.35, 0.0, TAU, 20, goodColor, 0.6, true)
	for x in notes:
		var close : bool = absf(x - hitX) <= ring
		draw_circle(Vector2(x, middle), 1.8, Color(accent, 0.35))
		draw_circle(Vector2(x, middle), 1.1, lightColor if close else accent)
	draw_fish(Vector2(lane.end.x + 5.0, middle), -1.0, sin(time * 12.0) * 0.15)
	var pips : float = lane.end.y + 1.5
	for i in hitsNeeded:
		draw_rect(Rect2(lane.position.x + i * 2.5, pips, 1.5, 1.5), accent if i < hitsDone else Color(lightColor, 0.2))
	for i in missesLeft:
		draw_rect(Rect2(lane.end.x - 1.5 - i * 2.5, pips, 1.5, 1.5), badColor)
