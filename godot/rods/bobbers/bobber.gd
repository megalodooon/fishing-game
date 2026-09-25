extends Node2D
class_name Bobber


#------------------------#
@export var floatHeight : float = 4.0
@export var waterline : float = 5.0
@export var bobAmount : float = 0.35
@export var bobSpeed : float = 2.4
@export var chargeTimeOffset : float = 0.0
@export var rangeOffset : float = 0.0

@export_group("Rings")
@export var ringColor : Color = Color(0.9, 0.98, 1.0, 0.4)
@export var ringSize : float = 5.0
@export var ringWidth : float = 0.35
@export var ringLifetime : float = 1.1
@export var ringInterval : Vector2 = Vector2(0.9, 0.3)
@export var dragSpeed : float = 14.0
@export_range(0.1, 1.0) var squash : float = 0.5

@export_group("Splash")
@export var droplets : int = 5
@export var foamColor : Color = Color(0.92, 0.98, 1.0, 0.55)
@export var foamSize : float = 3.0
@export var dropletColor : Color = Color(0.92, 0.98, 1.0, 0.9)
@export var dropletSpeed : Vector2 = Vector2(4.0, 10.0)
@export var dropletLift : Vector2 = Vector2(18.0, 30.0)
@export var dropletGravity : float = 180.0
@export var dipStrength : float = 26.0
@export var dipStiffness : float = 140.0
@export_range(0.0, 1.0) var dipDamping : float = 0.3

@export_group("Shadow")
@export var shadowColor : Color = Color(0.0, 0.08, 0.18, 0.35)
@export var shadowSize : float = 2.5
@export var shadowFade : float = 60.0

@onready var sprite : Sprite2D = $Sprite
@onready var effects : Node2D = $Effects

var ground : Vector2
var lastGround : Vector2
var height : float = 0.0
var size : float = 1.0
var inWater : bool = false
var drift : float = 0.0
var submerge : float = 0.0
var dip : float = 0.0
var dipVelocity : float = 0.0
var ringTimer : float = 0.0
var foam : float = 0.0
var drawnState : Vector3 = Vector3(-1.0, -1.0, -1.0)
var time : float = 0.0
var rings : Array[Vector4] = []
var drops : PackedVector3Array = PackedVector3Array()
var dropVelocities : PackedVector3Array = PackedVector3Array()
#------------------------#


func _ready() -> void:
	effects.draw.connect(draw_effects)

func _physics_process(delta : float) -> void:
	time += delta
	submerge = move_toward(submerge, 1.0 if inWater else 0.0, delta * 8.0)
	dipVelocity += (-dipStiffness * dip - 2.0 * dipDamping * sqrt(dipStiffness) * dipVelocity) * delta
	dip += dipVelocity * delta
	sprite.position.y = (sin(time * bobSpeed) * bobAmount + dip) * submerge
	var rid : RID = sprite.material.get_rid()
	RenderingServer.material_set_param(rid, "waterline", waterline - sprite.position.y)
	RenderingServer.material_set_param(rid, "submerge", submerge)
	foam = move_toward(foam, 0.0, delta * 3.5)
	update_rings(delta)
	update_drops(delta)
	effects.global_position = ground
	var state : Vector3 = Vector3(snappedf(shadow_amount(), 0.02), snappedf(submerge, 0.02), snappedf(size, 0.02))
	if not rings.is_empty() or not drops.is_empty() or foam > 0.0 or state != drawnState:
		drawnState = state
		effects.queue_redraw()

func place(point : Vector2, lift : float, water : bool, flow : float, appear : float) -> void:
	if ground == Vector2.ZERO:
		lastGround = point
	ground = point
	height = lift
	inWater = water
	drift = flow
	size = appear
	visible = true
	global_transform = Transform2D(0.0, Vector2.ONE * maxf(size, 0.001), 0.0, Vector2(point.x, point.y - lift))

func get_attach() -> Vector2:
	return to_global(sprite.position)

func splash(strength : float = 1.0) -> void:
	rings.append(Vector4(ground.x, ground.y, 0.0, strength))
	foam = strength
	for i in roundi(droplets * strength):
		var direction : Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(dropletSpeed.x, dropletSpeed.y) * strength
		drops.append(Vector3(ground.x, ground.y, 0.5))
		dropVelocities.append(Vector3(direction.x, direction.y * squash, randf_range(dropletLift.x, dropletLift.y) * strength))
	dipVelocity += dipStrength * strength

func update_rings(delta : float) -> void:
	var moved : Vector2 = ground - lastGround + Vector2(drift * delta, 0.0)
	lastGround = ground
	if inWater:
		var rate : float = clampf(moved.length() / delta / dragSpeed, 0.0, 1.0)
		var interval : float = lerpf(ringInterval.x, ringInterval.y, rate)
		ringTimer = minf(ringTimer - delta, interval)
		if ringTimer <= 0.0 and rate > 0.15:
			ringTimer = interval
			rings.append(Vector4(ground.x, ground.y, 0.0, lerpf(0.55, 0.4, rate)))
	for i in range(rings.size() - 1, -1, -1):
		rings[i].x -= drift * delta
		rings[i].z += delta
		if rings[i].z >= ringLifetime:
			rings.remove_at(i)

func update_drops(delta : float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var velocity : Vector3 = dropVelocities[i] - Vector3(0.0, 0.0, dropletGravity * delta)
		var drop : Vector3 = drops[i] + velocity * delta - Vector3(drift * delta, 0.0, 0.0)
		if drop.z <= 0.0 and velocity.z < 0.0:
			drops.remove_at(i)
			dropVelocities.remove_at(i)
		else:
			drops[i] = drop
			dropVelocities[i] = velocity

func draw_effects() -> void:
	for ring in rings:
		if ring.z < 0.0:
			continue
		var t : float = ring.z / ringLifetime
		var radius : float = lerpf(1.5, ringSize * sqrt(ring.w), 1.0 - pow(1.0 - t, 2.5))
		var alpha : float = ringColor.a * minf(ring.w, 1.0) * pow(1.0 - t, 1.5)
		effects.draw_set_transform(Vector2(ring.x, ring.y) - ground, 0.0, Vector2(1.0, squash))
		effects.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(ringColor, alpha), ringWidth, true)
	if submerge > 0.0:
		effects.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
		effects.draw_circle(Vector2.ZERO, 2.6, Color(ringColor, ringColor.a * 0.35 * submerge), true, -1.0, true)
	if foam > 0.0:
		effects.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
		effects.draw_circle(Vector2.ZERO, foamSize * (1.6 - 0.6 * foam), Color(foamColor, foamColor.a * foam * foam), true, -1.0, true)
	var air : float = shadow_amount()
	if air > 0.0:
		effects.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
		effects.draw_circle(Vector2.ZERO, shadowSize * (0.9 + 0.5 * (1.0 - air)), Color(shadowColor, shadowColor.a * 0.5 * air), true, -1.0, true)
		effects.draw_circle(Vector2.ZERO, shadowSize * (0.4 + 0.3 * air), Color(shadowColor, shadowColor.a * air), true, -1.0, true)
	effects.draw_set_transform(Vector2.ZERO)
	for drop in drops:
		effects.draw_circle(Vector2(drop.x, drop.y - drop.z) - ground, 0.35, dropletColor, true, -1.0, true)

func shadow_amount() -> float:
	return clampf(1.0 - (height - floatHeight) / shadowFade, 0.0, 1.0) * (1.0 - submerge) * size
