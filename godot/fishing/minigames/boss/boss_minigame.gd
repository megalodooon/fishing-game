extends Minigame
class_name BossMinigame

# The base of the fight minigames for trophy fish and sea creatures. The
# player steers the lure (a little bobber on the line) with the mouse around
# an arena, has a few hearts and flashes for a moment after every hit. The
# foe's style picks its colors and attacks.

# Per style: bullet, bullet glow, water top, water bottom, telegraph.
const PALETTES : Dictionary = {
	&"": [Color(0.95, 0.95, 1.0), Color(0.55, 0.8, 1.0, 0.35), Color(0.1, 0.2, 0.33), Color(0.05, 0.1, 0.19), Color(1.0, 0.35, 0.3, 0.35)],
	&"ember": [Color(1.0, 0.82, 0.4), Color(1.0, 0.4, 0.15, 0.4), Color(0.25, 0.1, 0.08), Color(0.12, 0.04, 0.04), Color(1.0, 0.5, 0.2, 0.35)],
	&"frost": [Color(0.9, 0.98, 1.0), Color(0.55, 0.85, 1.0, 0.4), Color(0.14, 0.24, 0.36), Color(0.07, 0.13, 0.22), Color(0.6, 0.9, 1.0, 0.35)],
	&"abyss": [Color(0.75, 1.0, 0.95), Color(0.45, 0.25, 0.9, 0.4), Color(0.05, 0.06, 0.14), Color(0.01, 0.02, 0.05), Color(0.7, 0.3, 1.0, 0.35)],
	&"storm": [Color(1.0, 0.98, 0.6), Color(0.7, 0.55, 1.0, 0.4), Color(0.14, 0.15, 0.24), Color(0.06, 0.06, 0.12), Color(1.0, 0.95, 0.4, 0.4)],
	&"reef": [Color(1.0, 0.85, 0.95), Color(1.0, 0.45, 0.65, 0.35), Color(0.08, 0.3, 0.38), Color(0.04, 0.16, 0.24), Color(1.0, 0.4, 0.6, 0.35)],
	&"sludge": [Color(0.8, 1.0, 0.5), Color(0.45, 0.75, 0.2, 0.4), Color(0.13, 0.17, 0.1), Color(0.06, 0.08, 0.05), Color(0.7, 1.0, 0.3, 0.35)],
	&"ghost": [Color(0.95, 0.97, 1.0), Color(0.8, 0.85, 1.0, 0.3), Color(0.16, 0.18, 0.25), Color(0.08, 0.09, 0.13), Color(0.9, 0.9, 1.0, 0.35)],
}

#------------------------#
@export_group("Lure")
@export var lureSpeed : float = 170.0
@export var lureRadius : float = 1.5
@export var invulnerable : float = 1.3

var area : Rect2
var lure : Vector2
var heartsLeft : int = 3
var hurt : float = 0.0
var shake : float = 0.0
var colors : Array = []
var orbLayer : Node2D
#------------------------#


func setup_arena() -> void:
	orbLayer = Node2D.new()
	orbLayer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	orbLayer.draw.connect(draw_orbs)
	add_child(orbLayer)
	var inner : Rect2 = Rect2(-size * 0.5, size).grow(-2.0)
	area = Rect2(inner.position + Vector2(0.0, 4.0), inner.size - Vector2(0.0, 4.0))
	lure = Vector2(area.get_center().x, area.end.y - 6.0)
	heartsLeft = maxi(hearts, 1)
	colors = PALETTES.get(style, PALETTES[&""])

# Picks count entries from options, always the same ones for the same fish,
# so every species fights its own way.
func signature(options : PackedStringArray, count : int) -> PackedStringArray:
	var picker : RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = hash(fishIcon.resource_path if fishIcon else String(style)) if fishIcon or style != &"" else random.randi()
	var pool : Array = Array(options)
	var picked : PackedStringArray = PackedStringArray()
	while picked.size() < mini(count, options.size()):
		picked.append(pool.pop_at(picker.randi_range(0, pool.size() - 1)))
	return picked

func step_lure(delta : float) -> void:
	var goal : Vector2 = pointer().clamp(area.position + Vector2.ONE * 2.0, area.end - Vector2.ONE * 2.0)
	lure = lure.move_toward(goal, lureSpeed * delta)
	orbLayer.queue_redraw()
	hurt = maxf(hurt - delta, 0.0)
	shake = maxf(shake - delta, 0.0)

# Returns whether it counted (not while still flashing from the last hit).
func take_hit() -> bool:
	if hurt > 0.0 or done:
		return false
	heartsLeft -= 1
	hurt = invulnerable
	shake = 0.25
	tugged.emit(0.6)
	if heartsLeft <= 0:
		finish(false)
	return true

func shaken() -> Vector2:
	return Vector2(sin(time * 90.0), cos(time * 77.0)) * shake * 3.0

func draw_arena() -> void:
	draw_panel(Rect2(-size * 0.5, size), frameColor)
	var bands : int = 8
	for i in bands:
		var t : float = float(i) / bands
		draw_rect(Rect2(area.position.x, area.position.y + area.size.y * t, area.size.x, area.size.y / bands + 0.5), (colors[2] as Color).lerp(colors[3], t))

# The line runs from the top of the arena down to the lure, like it's hooked.
func draw_lure() -> void:
	var at : Vector2 = lure + shaken()
	var blink : bool = hurt > 0.0 and fmod(hurt, 0.16) < 0.08
	draw_line(Vector2(at.x * 0.6, area.position.y), at, Color(1.0, 1.0, 1.0, 0.35), 0.25, true)
	if blink:
		return
	draw_circle(at, lureRadius + 0.6, Color(badColor, 0.35) if hurt > 0.0 else Color(1.0, 1.0, 1.0, 0.18))
	draw_circle(at, lureRadius, lightColor)
	draw_rect(Rect2(at.x - lureRadius, at.y - 0.35, lureRadius * 2.0, 0.7), badColor)

func draw_hearts(at : Vector2) -> void:
	for i in maxi(hearts, 1):
		var full : bool = i < heartsLeft
		var center : Vector2 = at + Vector2(i * 4.0, 0.0)
		var color : Color = badColor if full else Color(trackColor, 0.8)
		draw_circle(center + Vector2(-0.7, -0.4), 0.9, color)
		draw_circle(center + Vector2(0.7, -0.4), 0.9, color)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-1.6, -0.2), center + Vector2(1.6, -0.2), center + Vector2(0.0, 1.6)]), color)

# Bullets are one small texture each (glow and core baked in, made once per
# palette), so hundreds of them batch into a few draw calls.
const ORB_PIXELS : int = 64
const ORB_GLOW : float = 0.8
static var orbs : Dictionary = {}

func orb_texture(radius : float) -> Texture2D:
	var key : String = "%s/%s" % [style, radius]
	if orbs.has(key):
		return orbs[key]
	var image : Image = Image.create_empty(ORB_PIXELS, ORB_PIXELS, false, Image.FORMAT_RGBA8)
	var outer : float = radius + ORB_GLOW
	var glow : Color = colors[1]
	var core : Color = colors[0]
	for y in ORB_PIXELS:
		for x in ORB_PIXELS:
			var d : float = (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * ORB_PIXELS * 0.5).length() / (ORB_PIXELS * 0.5) * outer
			var inCore : float = clampf((radius - d) * ORB_PIXELS / outer * 0.5 + 0.5, 0.0, 1.0)
			var inGlow : float = clampf((outer - d) * ORB_PIXELS / outer * 0.5 + 0.5, 0.0, 1.0)
			var color : Color = Color(glow, glow.a * inGlow).blend(Color(core, core.a * inCore))
			image.set_pixel(x, y, color)
	var texture : ImageTexture = ImageTexture.create_from_image(image)
	orbs[key] = texture
	return texture

# Orbs go on their own smoothly filtered layer above the game's drawing.
func draw_orbs() -> void:
	pass

func draw_bullet(at : Vector2, radius : float, texture : Texture2D = null) -> void:
	var outer : float = radius + ORB_GLOW
	orbLayer.draw_texture_rect(texture if texture else orb_texture(radius), Rect2(at - Vector2.ONE * outer, Vector2.ONE * outer * 2.0), false)
