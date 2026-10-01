extends Node2D
class_name RemotePlayer

# The other player, drawn in this game when they're in the same place: the
# body, the hand and what it holds, the fishing line out to the bobber, a
# name tag and short lines over the head (like what they just caught). It
# eases toward the last pose they sent, which comes 15 times a second.
# Out at sea on their own boat (not this one) they show as a boat on the
# horizon instead (see NetSession).

const SMOOTH : float = 18.0
# The guest is drawn whiter (in both games) so two players with the same
# placeholder art can be told apart.
const GUEST_TINT : Color = Color(1.3, 1.3, 1.35)
const NAME_COLOR : Color = Color(0.86, 0.94, 1.0)

#------------------------#
var peer : int = 0
var displayName : String = ""
var pose : Dictionary = {}
var shadow : Sprite2D
var body : Node2D
var sprite : Sprite2D
var center : Node2D
var hand : Sprite2D
var holder : Node2D
var icon : Sprite2D
var heldPath : String = ""
var tip : Vector2 = Vector2.ZERO
var bobber : Variant = null
var shownBobber : Vector2 = Vector2.ZERO
var font : Font
var speech : String = ""
var speechColor : Color = Color.WHITE
var speechTime : float = 0.0
var placed : bool = false
# Out at sea on their own boat: a sail on the horizon instead of the body.
var far : bool = false:
	set(value):
		if value != far:
			far = value
			for part in [shadow, body, center]:
				if part:
					part.visible = not far
var time : float = 0.0
#------------------------#


# Copies the look of the local player's parts, so new art shows up on both.
func setup(local : Player, id : int, who : String) -> void:
	peer = id
	displayName = who
	name = "Remote_%d" % id
	font = load("res://ui/fonts/PressStart2P.ttf")
	shadow = Sprite2D.new()
	shadow.texture = local.shadow.texture
	shadow.position = local.shadow.position
	shadow.modulate = Color(1.0, 1.0, 1.0, 0.6)
	add_child(shadow)
	body = Node2D.new()
	body.position = local.body.position
	add_child(body)
	sprite = Sprite2D.new()
	sprite.texture = local.sprite.texture
	sprite.offset = local.sprite.offset
	sprite.hframes = local.sprite.hframes
	sprite.vframes = local.sprite.vframes
	sprite.self_modulate = GUEST_TINT if id != 1 else Color.WHITE
	body.add_child(sprite)
	center = Node2D.new()
	center.position = local.center_rest_position
	center.z_index = 1
	add_child(center)
	holder = Node2D.new()
	center.add_child(holder)
	icon = Sprite2D.new()
	holder.add_child(icon)
	hand = Sprite2D.new()
	hand.texture = local.hand.texture
	hand.self_modulate = sprite.self_modulate
	center.add_child(hand)
	visible = false

# A pose from the other game (see NetSession.capture_pose).
func receive(data : Dictionary) -> void:
	pose = data
	if not placed:
		placed = true
		apply(1.0)

func say(text : String, color : Color) -> void:
	speech = text
	speechColor = color
	speechTime = 2.5

func _process(delta : float) -> void:
	if pose.is_empty():
		return
	time += delta
	apply(1.0 - exp(-SMOOTH * delta))
	if speechTime > 0.0:
		speechTime -= delta
	queue_redraw()

func apply(weight : float) -> void:
	global_position = global_position.lerp(pose.get("p", global_position), weight) if weight < 1.0 else pose.get("p", global_position)
	body.rotation = lerp_angle(body.rotation, pose.get("br", 0.0), weight)
	sprite.position = sprite.position.lerp(pose.get("sp", Vector2.ZERO), weight)
	sprite.scale = sprite.scale.lerp(pose.get("ss", Vector2.ONE), weight)
	sprite.frame = clampi(pose.get("fr", 0), 0, sprite.hframes * sprite.vframes - 1)
	hand.position = hand.position.lerp(pose.get("hp", Vector2.ZERO), weight)
	hand.rotation = lerp_angle(hand.rotation, pose.get("hr", 0.0), weight)
	hand.scale = pose.get("hs", Vector2.ONE)
	holder.position = holder.position.lerp(pose.get("ip", Vector2.ZERO), weight)
	holder.rotation = lerp_angle(holder.rotation, pose.get("ir", 0.0), weight)
	holder.scale = pose.get("is", Vector2.ONE)
	var path : String = pose.get("item", "")
	if path != heldPath:
		heldPath = path
		var item : Item = load(path) as Item if not path.is_empty() and ResourceLoader.exists(path) else null
		icon.texture = item.icon if item else null
		icon.position = Vector2(4.0, -2.0) if item else Vector2.ZERO
	tip = pose.get("tip", Vector2.ZERO)
	bobber = pose.get("bob", null)
	if bobber != null:
		shownBobber = shownBobber.lerp(bobber, weight) if weight < 1.0 and shownBobber != Vector2.ZERO else bobber
	else:
		shownBobber = Vector2.ZERO

func _draw() -> void:
	if far:
		draw_far()
		return
	if bobber != null and tip != Vector2.ZERO:
		var from : Vector2 = to_local(tip)
		var to : Vector2 = to_local(shownBobber)
		var sag : Vector2 = (from + to) * 0.5 + Vector2(0.0, minf(from.distance_to(to) * 0.12, 6.0))
		var points : PackedVector2Array = PackedVector2Array()
		for i in 9:
			var t : float = i / 8.0
			points.append(from.lerp(sag, t).lerp(sag.lerp(to, t), t))
		draw_polyline(points, Color(0.94, 0.97, 1.0, 0.8), 0.45)
		draw_circle(to, 1.5, Color(0.9, 0.25, 0.22))
		draw_circle(to + Vector2(0.0, -0.6), 0.8, Color(0.96, 0.96, 0.96))
	if not font:
		return
	var tag : Vector2 = Vector2(-40.0, -17.0)
	draw_string(font, tag + Vector2(0.4, 0.4), displayName, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 3, Color(0.0, 0.0, 0.0, 0.6))
	draw_string(font, tag, displayName, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 3, NAME_COLOR)
	if speechTime > 0.0:
		var fade : float = clampf(speechTime / 0.4, 0.0, 1.0)
		var line : Vector2 = Vector2(-60.0, -21.0 - (2.5 - speechTime) * 2.0)
		draw_string(font, line + Vector2(0.4, 0.4), speech, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 3, Color(0.0, 0.0, 0.0, 0.6 * fade))
		draw_string(font, line, speech, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 3, Color(speechColor, fade))

# A small boat drifting along the top of the screen, with the name over it.
func draw_far() -> void:
	var at : Vector2 = to_local(Vector2(150.0 + sin(time * 0.3) * 6.0, 14.0 + sin(time * 1.3) * 0.6))
	var hull : PackedVector2Array = PackedVector2Array([at + Vector2(-6.0, 0.0), at + Vector2(6.0, 0.0), at + Vector2(4.0, 2.0), at + Vector2(-4.0, 2.0)])
	draw_colored_polygon(hull, Color(0.35, 0.22, 0.16, 0.85))
	draw_line(at + Vector2(0.0, 0.0), at + Vector2(0.0, -8.0), Color(0.3, 0.2, 0.15, 0.85), 0.5)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.5, -8.0), at + Vector2(5.0, -1.0), at + Vector2(0.5, -1.0)]), Color(GUEST_TINT, 0.85))
	draw_line(at + Vector2(-8.0, 2.5), at + Vector2(8.0, 2.5), Color(0.8, 0.9, 1.0, 0.35), 0.4)
	if font:
		draw_string(font, at + Vector2(-40.0, -10.0), displayName, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 3, NAME_COLOR)
