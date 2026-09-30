extends BossMinigame
class_name BulletHellMinigame

# Dodge what the fish spits out while grabbing the slack knots that float up:
# every knot reels it closer (drift can make surviving reel it too). Its style
# picks its patterns: aimed bursts, rings with a gap, spirals, rain, walls
# with a gap, slow homing orbs and telegraphed lightning bolts. Harder foes
# shoot faster and more often. Rings and walls always leave a gap wider than
# the lure, bullets are capped in speed, knots never float up right next to the
# lure, and standing still gets hit. Fish without a style get their own fixed
# handful of patterns, so each species fights differently.

const ALL : PackedStringArray = ["aimed", "ring", "spiral", "rain", "wall", "homing", "bolt", "cross", "twin", "shotgun", "sidewall", "stream", "fan", "cage", "petals"]
const STYLES : Dictionary = {
	&"ember": ["spiral", "rain", "aimed", "twin"],
	&"frost": ["ring", "wall", "aimed", "petals"],
	&"abyss": ["homing", "aimed", "ring", "cage"],
	&"storm": ["rain", "bolt", "wall", "sidewall"],
	&"reef": ["ring", "spiral", "aimed", "fan"],
	&"sludge": ["rain", "homing", "ring", "shotgun"],
	&"ghost": ["homing", "wall", "spiral", "cage"],
}

#------------------------#
@export_group("Bullets")
@export var bulletSpeed : Vector2 = Vector2(20.0, 31.0)
@export var fireEvery : Vector2 = Vector2(1.5, 1.05)
@export var bulletRadius : float = 1.3
@export var maxBullets : int = 110
@export var ringCount : Vector2 = Vector2(9.0, 14.0)
@export_range(0.3, 2.0) var ringGap : float = 0.9
@export var wallGap : float = 14.0

@export_group("Reeling")
@export var knots : Vector2 = Vector2(10.0, 15.0)
@export var knotEvery : Vector2 = Vector2(1.7, 2.2)
@export var knotLife : float = 5.0
@export var knotReach : float = 3.2
@export var drift : float = 0.0

var patterns : PackedStringArray
var bullets : Array[Vector4] = []
var homing : Array[float] = []
var boss : Vector2
var fireTimer : float = 0.8
var shots : int = 0
var pattern : int = 0
var spin : float = 0.0
var knotList : Array[Vector3] = []
var knotTimer : float = 1.0
var needed : float = 1.0
var progress : float = 0.0
var bolt : Vector2 = Vector2(-1.0, 0.0)
#------------------------#


func setup() -> void:
	setup_arena()
	patterns = PackedStringArray(STYLES[style]) if STYLES.has(style) else signature(ALL, 4)
	pattern = random.randi_range(0, patterns.size() - 1)
	needed = maxf(roundf(weigh(knots) * lerpf(0.9, 1.15, difficulty) * toughness), 3.0)
	boss = Vector2(area.get_center().x, area.position.y + 7.0)

func speed() -> float:
	return tune(bulletSpeed)

func tick(delta : float) -> void:
	step_lure(delta)
	boss.x = area.get_center().x + sin(time * 0.7) * area.size.x * 0.32
	boss.y = area.position.y + 7.0 + sin(time * 1.3) * 2.0
	fireTimer -= delta
	if fireTimer <= 0.0:
		fireTimer = tune(fireEvery) * random.randf_range(0.85, 1.15)
		fire()
	move_bullets(delta)
	update_bolt(delta)
	update_knots(delta)
	progress = minf(progress + drift * delta, 1.0)
	if progress >= 1.0:
		finish(true)

func fire() -> void:
	shots += 1
	if shots % 3 == 0:
		pattern = (pattern + 1 + random.randi_range(0, patterns.size() - 2)) % patterns.size()
	tugged.emit(0.2)
	var toward : float = (lure - boss).angle()
	match patterns[pattern]:
		"aimed":
			var count : int = 3 + roundi(difficulty * 2.0)
			for i in count:
				shoot(boss, toward + (i - (count - 1) * 0.5) * 0.3, speed())
		"ring":
			var count : int = roundi(tune(ringCount))
			var gap : float = toward + random.randf_range(-0.6, 0.6)
			for i in count:
				var angle : float = TAU * i / count
				if absf(angle_difference(angle, gap)) > ringGap * 0.5:
					shoot(boss, angle, speed() * 0.8)
		"spiral":
			for i in 3:
				spin += 0.42
				shoot(boss, spin + TAU * i / 3.0, speed() * 0.85)
		"rain":
			var count : int = 3 + roundi(difficulty * 3.0)
			for i in count:
				shoot(Vector2(random.randf_range(area.position.x + 2.0, area.end.x - 2.0), area.position.y), PI * 0.5 + random.randf_range(-0.12, 0.12), speed() * random.randf_range(0.7, 1.0))
		"wall":
			var gapAt : float = clampf(lure.x + random.randf_range(-18.0, 18.0), area.position.x + wallGap, area.end.x - wallGap)
			var x : float = area.position.x + 2.0
			while x < area.end.x - 1.0:
				if absf(x - gapAt) > wallGap * 0.5:
					shoot(Vector2(x, area.position.y), PI * 0.5, speed() * 0.6)
				x += 3.5
		"homing":
			for i in 2 + roundi(difficulty * 2.0):
				shoot(boss, toward + random.randf_range(-1.0, 1.0), speed() * 0.45, 3.0)
		"bolt":
			if bolt.x < 0.0:
				bolt = Vector2(clampf(lure.x + random.randf_range(-6.0, 6.0), area.position.x + 3.0, area.end.x - 3.0), 0.0)
			shoot(boss, toward, speed())
		"cross":
			spin += 0.3
			for i in 4:
				shoot(boss, spin + TAU * i / 4.0, speed() * 0.8)
				shoot(boss, spin + TAU * i / 4.0, speed() * 0.55)
		"twin":
			spin += 0.38
			for i in 2:
				shoot(boss, spin + PI * i, speed() * 0.8)
				shoot(boss, -spin + PI * i, speed() * 0.8)
		"shotgun":
			for i in 5 + roundi(difficulty * 3.0):
				shoot(boss, toward + random.randf_range(-0.55, 0.55), speed() * random.randf_range(0.55, 1.05))
		"sidewall":
			var gapY : float = clampf(lure.y + random.randf_range(-10.0, 10.0), area.position.y + 16.0, area.end.y - 6.0)
			var fromLeft : bool = random.randf() < 0.5
			var y : float = area.position.y + 14.0
			while y < area.end.y - 1.0:
				if absf(y - gapY) > wallGap * 0.5:
					shoot(Vector2(area.position.x if fromLeft else area.end.x, y), 0.0 if fromLeft else PI, speed() * 0.6)
				y += 3.5
		"stream":
			for i in 5:
				shoot(boss, toward, speed() * (0.55 + i * 0.12))
		"fan":
			var count : int = 9 + roundi(difficulty * 2.0)
			var offset : float = 0.12 if shots % 2 == 0 else -0.12
			for i in count:
				shoot(boss, PI * 0.5 + offset + (i - (count - 1) * 0.5) * 0.28, speed() * 0.7)
		"cage":
			var count : int = 10
			var gap : float = random.randf() * TAU
			var center : Vector2 = lure
			for i in count:
				var angle : float = TAU * i / count
				if absf(angle_difference(angle, gap)) > 0.5:
					var at : Vector2 = (center + Vector2.from_angle(angle) * 34.0).clamp(area.position, area.end)
					shoot(at, (center - at).angle(), speed() * 0.45)
		"petals":
			var count : int = 6
			for i in count:
				shoot(boss, spin + TAU * i / count, speed() * 0.8)
				shoot(boss, spin + TAU * (i + 0.5) / count, speed() * 0.5)
			spin += 0.5

func shoot(from : Vector2, angle : float, velocity : float, homes : float = 0.0) -> void:
	if bullets.size() >= maxBullets:
		return
	var direction : Vector2 = Vector2.from_angle(angle) * minf(velocity, 60.0)
	bullets.append(Vector4(from.x, from.y, direction.x, direction.y))
	homing.append(homes)

func move_bullets(delta : float) -> void:
	var outer : Rect2 = area.grow(4.0)
	for i in range(bullets.size() - 1, -1, -1):
		var bullet : Vector4 = bullets[i]
		var velocity : Vector2 = Vector2(bullet.z, bullet.w)
		if homing[i] > 0.0:
			homing[i] -= delta
			velocity = velocity.rotated(clampf(angle_difference(velocity.angle(), (lure - Vector2(bullet.x, bullet.y)).angle()), -1.2 * delta, 1.2 * delta))
		var at : Vector2 = Vector2(bullet.x, bullet.y) + velocity * delta
		if not outer.has_point(at) or (homing[i] < 0.0 and homing[i] > -0.5):
			drop(i)
			continue
		bullets[i] = Vector4(at.x, at.y, velocity.x, velocity.y)
		if at.distance_to(lure) < bulletRadius + lureRadius * 0.7 and take_hit():
			drop(i)

# Removes a bullet by moving the last one into its place (no shifting).
func drop(i : int) -> void:
	var last : int = bullets.size() - 1
	bullets[i] = bullets[last]
	homing[i] = homing[last]
	bullets.resize(last)
	homing.resize(last)

func update_bolt(delta : float) -> void:
	if bolt.x < 0.0:
		return
	bolt.y += delta
	var warn : float = lerpf(0.9, 0.6, difficulty)
	if bolt.y >= warn and bolt.y - delta < warn and absf(lure.x - bolt.x) < 3.0:
		take_hit()
	if bolt.y > warn + 0.2:
		bolt = Vector2(-1.0, 0.0)

func update_knots(delta : float) -> void:
	knotTimer -= delta
	if knotTimer <= 0.0:
		knotTimer = tune(knotEvery) * random.randf_range(0.8, 1.2)
		var spot : Vector2 = lure
		for attempt in 12:
			spot = Vector2(random.randf_range(area.position.x + 5.0, area.end.x - 5.0), random.randf_range(area.position.y + 14.0, area.end.y - 4.0))
			if spot.distance_to(lure) > 14.0:
				break
		knotList.append(Vector3(spot.x, spot.y, knotLife))
	for i in range(knotList.size() - 1, -1, -1):
		var knot : Vector3 = knotList[i]
		knot.z -= delta
		if Vector2(knot.x, knot.y).distance_to(lure) < knotReach:
			progress = minf(progress + 1.0 / needed, 1.0)
			tugged.emit(0.3)
			knotList.remove_at(i)
		elif knot.z <= 0.0:
			knotList.remove_at(i)
		else:
			knotList[i] = knot

func draw_orbs() -> void:
	var orb : Texture2D = orb_texture(bulletRadius)
	for bullet in bullets:
		draw_bullet(Vector2(bullet.x, bullet.y), bulletRadius, orb)

func _draw() -> void:
	draw_arena()
	if bolt.x >= 0.0:
		var warn : float = lerpf(0.9, 0.6, difficulty)
		if bolt.y < warn:
			draw_rect(Rect2(bolt.x - 3.0, area.position.y, 6.0, area.size.y), Color(colors[4], (colors[4] as Color).a * (0.4 + 0.6 * bolt.y / warn)))
		else:
			draw_rect(Rect2(bolt.x - 1.5, area.position.y, 3.0, area.size.y), colors[0])
	for knot in knotList:
		var pulse : float = 1.0 + sin(time * 8.0 + knot.x) * 0.25
		var fade : float = clampf(knot.z / 0.8, 0.0, 1.0)
		draw_circle(Vector2(knot.x, knot.y), 2.2 * pulse, Color(goodColor, 0.25 * fade))
		draw_arc(Vector2(knot.x, knot.y), 1.4, 0.0, TAU, 12, Color(goodColor, fade), 0.5, true)
	var big : float = fishSize
	fishSize = 13.0
	draw_fish(boss + shaken() * 0.3, 1.0 if cos(time * 0.7) >= 0.0 else -1.0, sin(time * 6.0) * 0.08)
	fishSize = big
	draw_lure()
	var meter : Rect2 = Rect2(area.position.x + 16.0, -size.y * 0.5 + 2.5, area.size.x - 16.0, 2.0)
	draw_meter(meter, progress, false, badColor.lerp(goodColor, progress))
	draw_hearts(Vector2(area.position.x + 2.0, -size.y * 0.5 + 3.5))
