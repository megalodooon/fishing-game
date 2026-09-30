extends BossMinigame
class_name BossDuelMinigame

# A mini boss fight. The foe circles the arena and attacks where the lure is:
# it charges along a line, slams a circle, sprays a fan of bubbles or sweeps
# a band across the arena, each shown as a warning first. After each attack
# it's worn out for a moment: click on it then to wear it down. Harder foes
# warn for less time, rest shorter and mix in more attacks. Every warning
# lasts at least minWarning seconds, so every attack can be dodged.

enum Phase { ROAM, WARN, ATTACK, REST }

#------------------------#
@export_group("Foe")
@export var health : Vector2 = Vector2(14.0, 24.0)
@export var bossRadius : float = 7.0
@export var roamTime : Vector2 = Vector2(1.1, 0.6)
@export var warning : Vector2 = Vector2(1.05, 0.68)
@export var minWarning : float = 0.62
@export var restTime : Vector2 = Vector2(1.5, 1.1)
# Seconds between strikes that count, so spam clicking doesn't help.
@export var swingCooldown : float = 0.4
# Clicking when it can't be hit (or missing it) locks out strikes this long.
@export var fumbleLock : float = 0.8
# The most strikes that count in one rest.
@export var hitsPerRest : int = 3

@export_group("Attacks")
@export var chargeSpeed : float = 120.0
@export var chargeWidth : float = 4.0
@export var slamRadius : Vector2 = Vector2(7.0, 10.0)
@export var bubbleSpeed : Vector2 = Vector2(28.0, 44.0)
@export var sweepHeight : float = 9.0

var boss : Vector2
var home : Vector2
var phase : int = Phase.ROAM
var timer : float = 1.0
var attack : String = ""
var target : Vector2
var from : Vector2
var hp : float = 1.0
var maxHp : float = 1.0
var flash : float = 0.0
var clang : float = 0.0
var bubbles : Array[Vector4] = []
var attacks : PackedStringArray
var swingWait : float = 0.0
var restHits : int = 0
#------------------------#


func setup() -> void:
	setup_arena()
	maxHp = roundf(tune(health) * lerpf(1.0, 1.6, heft) * toughness)
	hp = maxHp
	boss = Vector2(area.get_center().x, area.position.y + 12.0)
	home = boss
	# Each species has its own three attacks, plus one more on harder fish.
	attacks = signature(PackedStringArray(["charge", "slam", "volley", "sweep", "column", "burst"]), 3 if difficulty < 0.5 else 4)
	timer = 0.9

func warn_time() -> float:
	return maxf(tune(warning), minWarning)

func tick(delta : float) -> void:
	step_lure(delta)
	flash = maxf(flash - delta, 0.0)
	clang = maxf(clang - delta, 0.0)
	swingWait = maxf(swingWait - delta, 0.0)
	timer -= delta
	match phase:
		Phase.ROAM:
			home = Vector2(area.get_center().x + sin(time * 0.9) * area.size.x * 0.3, area.position.y + 12.0 + sin(time * 0.6) * 5.0)
			boss = boss.lerp(home, 1.0 - exp(-3.0 * delta))
			if timer <= 0.0:
				begin_attack()
		Phase.WARN:
			if attack == "slam" or attack == "sweep" or attack == "column":
				target = target.lerp(lure, 1.0 - exp(-1.2 * delta))
			if timer <= 0.0:
				strike()
		Phase.ATTACK:
			if attack == "charge":
				var step : Vector2 = (target - boss).limit_length(chargeSpeed * delta)
				var before : Vector2 = boss
				boss += step
				if Geometry2D.get_closest_point_to_segment(lure, before, boss).distance_to(lure) < chargeWidth * 0.5 + lureRadius:
					take_hit()
				if boss.distance_to(target) < 0.5:
					rest()
			elif timer <= 0.0:
				rest()
		Phase.REST:
			if timer <= 0.0:
				phase = Phase.ROAM
				timer = tune(roamTime) * random.randf_range(0.8, 1.3)
	move_bubbles(delta)

func begin_attack() -> void:
	attack = attacks[random.randi_range(0, attacks.size() - 1)]
	phase = Phase.WARN
	timer = warn_time()
	from = boss
	target = lure
	if attack == "charge":
		target = boss + (lure - boss).normalized() * clampf(boss.distance_to(lure) + 10.0, 20.0, 90.0)
		target = target.clamp(area.position + Vector2.ONE * 4.0, area.end - Vector2.ONE * 4.0)
	tugged.emit(0.25)

func strike() -> void:
	phase = Phase.ATTACK
	match attack:
		"charge":
			timer = 2.0
		"slam":
			if lure.distance_to(target) < tune(slamRadius) + lureRadius:
				take_hit()
			timer = 0.25
		"volley":
			var count : int = 5 + roundi(difficulty * 4.0)
			var toward : float = (lure - boss).angle()
			for i in count:
				var angle : float = toward + (i - (count - 1) * 0.5) * 0.28
				var velocity : Vector2 = Vector2.from_angle(angle) * tune(bubbleSpeed)
				bubbles.append(Vector4(boss.x, boss.y, velocity.x, velocity.y))
			timer = 0.3
		"sweep":
			if absf(lure.y - target.y) < sweepHeight * 0.5 + lureRadius:
				take_hit()
			timer = 0.3
		"column":
			if absf(lure.x - target.x) < sweepHeight * 0.5 + lureRadius:
				take_hit()
			timer = 0.3
		"burst":
			# A full ring of bubbles with one gap near the lure's side.
			var count : int = 12 + roundi(difficulty * 4.0)
			var gap : float = (lure - boss).angle() + random.randf_range(-0.8, 0.8)
			for i in count:
				var angle : float = TAU * i / count
				if absf(angle_difference(angle, gap)) > 0.55:
					bubbles.append(Vector4(boss.x, boss.y, cos(angle) * tune(bubbleSpeed) * 0.8, sin(angle) * tune(bubbleSpeed) * 0.8))
			timer = 0.3
	tugged.emit(0.5)

func rest() -> void:
	phase = Phase.REST
	timer = tune(restTime)
	restHits = 0

func move_bubbles(delta : float) -> void:
	var outer : Rect2 = area.grow(4.0)
	for i in range(bubbles.size() - 1, -1, -1):
		var bubble : Vector4 = bubbles[i]
		var at : Vector2 = Vector2(bubble.x, bubble.y) + Vector2(bubble.z, bubble.w) * delta
		bubbles[i] = Vector4(at.x, at.y, bubble.z, bubble.w)
		if not outer.has_point(at) or (at.distance_to(lure) < 1.6 + lureRadius * 0.7 and take_hit()):
			# Move the last bubble into this slot instead of shifting the rest.
			bubbles[i] = bubbles[bubbles.size() - 1]
			bubbles.resize(bubbles.size() - 1)

func press() -> void:
	if swingWait > 0.0:
		return
	var onBoss : bool = pointer().distance_to(boss) <= bossRadius + 1.5
	if phase == Phase.REST and onBoss and restHits < hitsPerRest:
		hp -= power
		restHits += 1
		swingWait = swingCooldown
		flash = 0.12
		tugged.emit(0.4)
		if hp <= 0.0:
			finish(true)
	else:
		swingWait = fumbleLock
		clang = 0.2

func draw_orbs() -> void:
	var orb : Texture2D = orb_texture(1.4)
	for bubble in bubbles:
		draw_bullet(Vector2(bubble.x, bubble.y), 1.4, orb)

func _draw() -> void:
	draw_arena()
	var warn : Color = colors[4]
	if phase == Phase.WARN:
		var t : float = 1.0 - timer / warn_time()
		var alpha : float = warn.a * (0.5 + 0.5 * t)
		match attack:
			"charge":
				draw_line(boss, target, Color(warn, alpha), chargeWidth, true)
			"slam":
				draw_circle(target, tune(slamRadius), Color(warn, alpha))
				draw_arc(target, tune(slamRadius) * t, 0.0, TAU, 28, Color(warn, 0.9), 0.5, true)
			"volley":
				draw_arc(boss, bossRadius + 2.0 + t * 3.0, 0.0, TAU, 24, Color(warn, 0.8), 0.6, true)
			"burst":
				draw_arc(boss, bossRadius + 2.0 + t * 5.0, 0.0, TAU, 24, Color(warn, 0.9), 1.0, true)
			"sweep":
				draw_rect(Rect2(area.position.x, target.y - sweepHeight * 0.5, area.size.x, sweepHeight).intersection(area), Color(warn, alpha))
			"column":
				draw_rect(Rect2(target.x - sweepHeight * 0.5, area.position.y, sweepHeight, area.size.y).intersection(area), Color(warn, alpha))
	elif phase == Phase.ATTACK and (attack == "slam" or attack == "sweep" or attack == "column"):
		if attack == "slam":
			draw_circle(target, tune(slamRadius), Color(colors[0], 0.6))
		elif attack == "column":
			draw_rect(Rect2(target.x - sweepHeight * 0.5, area.position.y, sweepHeight, area.size.y).intersection(area), Color(colors[0], 0.5))
		else:
			draw_rect(Rect2(area.position.x, target.y - sweepHeight * 0.5, area.size.x, sweepHeight).intersection(area), Color(colors[0], 0.5))
	var tired : bool = phase == Phase.REST
	if tired and restHits < hitsPerRest and swingWait <= 0.0:
		var ring : float = bossRadius + 1.5 + sin(time * 10.0) * 0.6
		draw_arc(boss, ring, 0.0, TAU, 28, Color(goodColor, 0.9), 0.6, true)
	var big : float = fishSize
	fishSize = bossRadius * 2.4
	var facing : float = 1.0 if (lure.x >= boss.x) else -1.0
	draw_fish(boss + shaken() * 0.4, facing, sin(time * (3.0 if tired else 8.0)) * 0.1)
	fishSize = big
	if flash > 0.0:
		draw_circle(boss, bossRadius, Color(1.0, 1.0, 1.0, flash * 4.0))
	if clang > 0.0:
		draw_arc(boss, bossRadius + 2.0, 0.0, TAU, 20, Color(lightColor, clang * 3.0), 0.4, true)
	draw_lure()
	var bar : Rect2 = Rect2(area.position.x + 16.0, -size.y * 0.5 + 2.5, area.size.x - 16.0, 2.0)
	draw_meter(bar, hp / maxHp, false, badColor)
	draw_hearts(Vector2(area.position.x + 2.0, -size.y * 0.5 + 3.5))
