extends Node2D
class_name PetFollower

# The active pet, trotting (or flying) along beside the player. It trails a
# little behind on the side the player isn't facing, catches up with some lag
# and jumps back to the player after a room change or a trip.

#------------------------#
@export var player : Player
@export var followOffset : Vector2 = Vector2(-11.0, 3.0)
@export var followSpeed : float = 4.0
@export var teleportDistance : float = 70.0
@export var hopHeight : float = 1.0
@export var hoverHeight : float = 11.0
@export var hoverBob : float = 1.5
@export var shadowColor : Color = Color(0.0, 0.0, 0.0, 0.25)
# The node sits this far above where the pet stands. The pet is a child of the
# player drawn behind it, so it shares the player's layer and never pops over it.
@export var sortLift : float = 0.0

var pet : PetData
var sprite : Sprite2D
var light : NightLight
var time : float = 0.0
var side : float = -1.0
var ground : Vector2 = Vector2.ZERO
#------------------------#


func _ready() -> void:
	sprite = Sprite2D.new()
	add_child(sprite)
	light = NightLight.new()
	light.radius = 18.0
	light.height = hoverHeight
	light.position = Vector2(0.0, sortLift - hoverHeight)
	light.glowRadius = 8.0
	add_child(light)
	visible = false

func _process(delta : float) -> void:
	var active : PetData = player.progress.activePet if player and player.progress else null
	if active != pet:
		pet = active
		if pet:
			sprite.texture = pet.sprite
			light.color = pet.glowColor
			ground = goal()
	visible = pet != null and not player.charting
	light.visible = pet != null and pet.glows
	if not pet:
		return
	time += delta
	if absf(player.facing) > 0.0:
		side = -signf(player.facing)
	var target : Vector2 = goal()
	if ground.distance_to(target) > teleportDistance:
		ground = target
	var before : Vector2 = ground
	ground = ground.lerp(target, 1.0 - exp(-followSpeed * delta))
	global_position = ground - Vector2(0.0, sortLift)
	var moving : float = clampf(before.distance_to(ground) / maxf(delta, 0.001) / 20.0, 0.0, 1.0)
	if absf(ground.x - before.x) > 0.02:
		sprite.flip_h = ground.x < before.x
	var height : float = sprite.texture.get_height() * 0.5 if sprite.texture else 0.0
	if pet.flies:
		sprite.position = Vector2(0.0, sortLift - height - hoverHeight + sin(time * 3.0) * hoverBob)
		sprite.rotation = sin(time * 2.0) * 0.08
	else:
		sprite.position = Vector2(0.0, sortLift - height - absf(sin(time * 12.0)) * hopHeight * moving)
		sprite.rotation = sin(time * 12.0) * 0.12 * moving
	queue_redraw()

func goal() -> Vector2:
	return player.global_position + Vector2(followOffset.x * -side, followOffset.y)

func _draw() -> void:
	if not pet or not sprite.texture:
		return
	var width : float = sprite.texture.get_width() * (0.5 if pet.flies else 0.7)
	draw_set_transform(Vector2(0.0, sortLift + 0.5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, width * 0.5, shadowColor)
